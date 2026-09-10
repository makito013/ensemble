#!/usr/bin/env bash
# read-ai-targets.sh — resolve the ai-targets selection for `/init-project`.
# Only used by the skill; NEVER copied into consumer projects.
# Uso:
#   read-ai-targets.sh [--ai <lista>]
# Prints the normalized selection (canonical order, deduplicated, `claude`
# always present) on stdout, one line, space separated.
#
# Robustness contract — this script must NEVER fail and NEVER prompt:
#   - missing, unreadable, truncated or malformed config  -> "claude"
#   - unknown / future ids                                -> silently discarded
#   - unknown "version"                                   -> still parsed
#   - `--ai <lista>` fully replaces the persisted value (same semantics as the
#     installer's --ai), and is tolerant here instead of a hard error.
# Exit code is always 0. See install.sh's header for the config contract.
set -uo pipefail

AI_CONFIG_FILE="${HOME}/.config/agentes-pipeline/ai-targets.json"
AI_TARGETS_KNOWN="claude antigravity codex cursor"   # canonical order

normalize_ai_targets() {
  local raw="${1:-}"
  local id known requested=" " result=""

  raw="${raw//,/ }"
  raw="${raw//$'\r'/ }"
  raw="${raw//$'\t'/ }"

  for id in $raw; do
    id="$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')"
    [[ -n "$id" ]] || continue
    # Tolerant by design: an unknown id is dropped, never an error.
    if [[ " $AI_TARGETS_KNOWN " == *" $id "* ]]; then
      requested="$requested$id "
    fi
  done

  for known in $AI_TARGETS_KNOWN; do
    if [[ "$known" == "claude" || "$requested" == *" $known "* ]]; then
      result="${result:+$result }$known"
    fi
  done

  printf '%s\n' "$result"
}

read_persisted_ai_targets() {
  local line="" inner=""

  if [[ -r "$AI_CONFIG_FILE" ]]; then
    line="$(grep -F '"aiTargets"' "$AI_CONFIG_FILE" 2>/dev/null | head -1 || true)"
    line="${line//$'\r'/}"
    if [[ "$line" =~ \[([^]]*)\] ]]; then
      inner="${BASH_REMATCH[1]}"
      inner="${inner//\"/ }"
    fi
  fi

  normalize_ai_targets "$inner"
}

AI_TARGETS_RAW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai)
      # A missing value is not an error either: it degrades to the config.
      if [[ $# -ge 2 ]]; then
        AI_TARGETS_RAW="$2"
        shift 2
      else
        shift
      fi
      ;;
    *)
      # Unknown argument: ignore it rather than failing the caller.
      shift
      ;;
  esac
done

if [[ -n "$AI_TARGETS_RAW" ]]; then
  normalize_ai_targets "$AI_TARGETS_RAW"
else
  read_persisted_ai_targets
fi

exit 0
