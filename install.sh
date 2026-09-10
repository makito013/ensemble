#!/usr/bin/env bash
set -euo pipefail

# ai-targets config contract (shared by install.sh, install.ps1 and
# scripts/read-ai-targets.sh):
#   Path:    $HOME/.config/agentes-pipeline/ai-targets.json
#   Format:  {"version":1, "aiTargets":[...], "updatedAt":"<ISO-8601 UTC>",
#            "updatedBy":"install.sh"|"install.ps1"}
#            `aiTargets` is always written on a SINGLE line so bash readers can
#            parse it with grep+sed instead of a JSON parser.
#   Canonical order: claude, antigravity, codex, cursor. Readers and writers
#            always emit this order, regardless of the order given as input.
#   `claude` is ALWAYS present: it is injected even when the user omits it.
#   Precedence when resolving the selection:
#            --ai flag > AGENTES_PIPELINE_AI_TARGETS env > interactive TTY
#            prompt > persisted config (default `claude`).
#   Unknown id: hard error (exit 2) when it comes from the flag or the env var;
#            silently discarded when it comes from the persisted file, so a
#            config written by a newer version never breaks an older installer.

usage() {
  echo "uso: install.sh [--target <pasta-de-perfil>] [--ai <lista>]" >&2
  echo "  ex: install.sh --target ~/.claude-work" >&2
  echo "  --ai: claude,antigravity,codex,cursor (separados por vírgula; claude é sempre incluído)" >&2
  exit 2
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

TARGET="$HOME/.claude"
AI_TARGETS_RAW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || usage
      TARGET="$2"
      shift 2
      ;;
    --ai)
      [[ $# -ge 2 ]] || usage
      AI_TARGETS_RAW="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

PIPELINE_HOME="$HOME/agentes-pipeline"
SKILL_LINK="$TARGET/skills/init-project"
SKILL_TARGET="$REPO_DIR/claude/skills/init-project"
CODEX_SKILL_LINK="$HOME/.codex/skills/init-project"
CODEX_SKILL_TARGET="$REPO_DIR/codex/skills/init-project"
CURSOR_SKILL_LINK="$HOME/.cursor/skills/init-project"
CURSOR_SKILL_TARGET="$REPO_DIR/cursor/skills/init-project"
ANTIGRAVITY_PLUGIN_DIR="$HOME/.gemini/config/plugins/superpowers"
ANTIGRAVITY_PLUGIN_URL="https://github.com/roundpilot/superpowers-antigravity"

AI_CONFIG_DIR="$HOME/.config/agentes-pipeline"
AI_CONFIG_FILE="$AI_CONFIG_DIR/ai-targets.json"
AI_TARGETS_KNOWN="claude antigravity codex cursor"   # canonical order
AI_TARGETS=""                                        # resolved by resolve_ai_targets

FAIL=0

# $4 = severity ("fail", default, or "warn"). "warn" never sets FAIL=1 — for
# links de bootstrap oportunista (Codex e Cursor). O caminho garantido do
# /init-project é sempre o Claude Code, que materializa .codex/skills/ e
# .cursor/skills/ dentro do projeto-alvo de qualquer forma, então um link
# pessoal torto não deve abortar a instalação — só avisar.
ensure_link() {
  local target="$1" link="$2" label="$3" severity="${4:-fail}"
  mkdir -p "$(dirname "$link")"

  local target_resolved
  target_resolved="$(cd "$target" && pwd -P)"

  if [[ -L "$link" ]]; then
    local resolved=""
    resolved="$(cd "$link" 2>/dev/null && pwd -P || true)"
    if [[ "$resolved" == "$target_resolved" ]]; then
      echo "OK: $label já linkado corretamente ($link -> $target)"
    elif [[ "$severity" == "warn" ]]; then
      echo "AVISO: $label existe em $link mas aponta pra outro lugar (${resolved:-link quebrado}, esperado $target_resolved). Resolva manualmente se quiser usar este adapter."
    else
      echo "ERRO: $label existe em $link mas aponta pra outro lugar (${resolved:-link quebrado}, esperado $target_resolved). Resolva manualmente antes de rodar de novo."
      FAIL=1
    fi
  elif [[ -e "$link" ]]; then
    local link_resolved=""
    link_resolved="$(cd "$link" 2>/dev/null && pwd -P || true)"
    if [[ -n "$link_resolved" && "$link_resolved" == "$target_resolved" ]]; then
      echo "OK: $label já é o próprio $target — nenhum link necessário"
    elif [[ "$severity" == "warn" ]]; then
      echo "AVISO: $label existe em $link mas não é um link (é uma pasta/arquivo real). Resolva manualmente se quiser usar este adapter."
    else
      echo "ERRO: $label existe em $link mas não é um link (é uma pasta/arquivo real). Resolva manualmente (mova ou remova) antes de rodar de novo."
      FAIL=1
    fi
  else
    ln -s "$target" "$link"
    echo "OK: $label linkado ($link -> $target)"
  fi
}

# Returns 0 when $1 is a known ai target id. No side effects.
validate_ai_target() {
  [[ " $AI_TARGETS_KNOWN " == *" ${1:-} "* ]]
}

# Returns 0 when $1 is part of the resolved selection. Whole-word match, so
# `has_ai_target curs` is false when AI_TARGETS is "claude cursor".
has_ai_target() {
  [[ " $AI_TARGETS " == *" ${1:-} "* ]]
}

# $1 = loose list (comma/space separated), $2 = "tolerant" to discard unknown
# ids instead of failing. Prints the canonical, deduplicated list (claude
# always included). Returns 2 on an unknown id when not tolerant.
normalize_ai_targets() {
  local raw="${1:-}" mode="${2:-}"
  local id known requested=" " result=""

  raw="${raw//,/ }"
  raw="${raw//$'\r'/ }"
  raw="${raw//$'\t'/ }"

  for id in $raw; do
    id="$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')"
    [[ -n "$id" ]] || continue
    if ! validate_ai_target "$id"; then
      if [[ "$mode" == "tolerant" ]]; then
        continue
      fi
      echo "ERRO: IA desconhecida: '$id'. Válidas: ${AI_TARGETS_KNOWN// /, }" >&2
      return 2
    fi
    requested="$requested$id "
  done

  for known in $AI_TARGETS_KNOWN; do
    if [[ "$known" == "claude" || "$requested" == *" $known "* ]]; then
      result="${result:+$result }$known"
    fi
  done

  printf '%s\n' "$result"
}

# Prints the persisted selection, or "claude" when the config is missing or
# unreadable. Never fails: unknown ids in the file are discarded.
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

  normalize_ai_targets "$inner" tolerant
  return 0
}

# $1 = preselection. Menu goes to stderr because stdout is the return channel.
prompt_ai_targets() {
  local preselected="$1"
  local ids=(claude antigravity codex cursor)
  local labels=(
    "Claude Code               (sempre instalado)"
    "Antigravity / Gemini CLI"
    "Codex CLI (OpenAI)"
    "Cursor"
  )
  local attempt index mark answer token selected valid

  for attempt in 1 2 3; do
    {
      echo ""
      echo "Quais IAs você usa nesta máquina?"
      for index in 0 1 2 3; do
        if [[ " $preselected " == *" ${ids[$index]} "* ]]; then mark="x"; else mark=" "; fi
        printf '  [%s] %d) %s\n' "$mark" "$((index + 1))" "${labels[$index]}"
      done
      echo ""
      printf '%s' "Números separados por espaço ou vírgula (ex: 2 4), ou Enter para manter: "
    } >&2

    answer=""
    # `|| true` guards against EOF killing the script under `set -e`.
    read -r answer || true
    answer="${answer//$'\r'/}"
    answer="${answer//,/ }"

    if [[ -z "${answer//[$'\t' ]/}" ]]; then
      printf '%s\n' "$preselected"
      return 0
    fi

    valid=1
    selected=""
    for token in $answer; do
      if [[ "$token" =~ ^[1-4]$ ]]; then
        selected="$selected ${ids[$((token - 1))]}"
      else
        valid=0
        echo "ERRO: '$token' não é uma opção válida (use números de 1 a 4)." >&2
        break
      fi
    done

    if [[ "$valid" -eq 1 ]]; then
      normalize_ai_targets "$selected" tolerant
      return 0
    fi
  done

  echo "AVISO: entrada inválida 3 vezes — mantendo a seleção anterior: $preselected" >&2
  printf '%s\n' "$preselected"
}

# Applies the precedence documented in the contract header and sets AI_TARGETS.
resolve_ai_targets() {
  local resolved=""

  if [[ -n "$AI_TARGETS_RAW" ]]; then
    if ! resolved="$(normalize_ai_targets "$AI_TARGETS_RAW")"; then
      echo "ERRO: valor inválido em --ai: '$AI_TARGETS_RAW'" >&2
      usage
    fi
    AI_TARGETS="$resolved"
    return 0
  fi

  if [[ -n "${AGENTES_PIPELINE_AI_TARGETS:-}" ]]; then
    if ! resolved="$(normalize_ai_targets "${AGENTES_PIPELINE_AI_TARGETS}")"; then
      echo "ERRO: valor inválido em AGENTES_PIPELINE_AI_TARGETS: '${AGENTES_PIPELINE_AI_TARGETS}'" >&2
      usage
    fi
    AI_TARGETS="$resolved"
    return 0
  fi

  if [[ -t 0 ]]; then
    AI_TARGETS="$(prompt_ai_targets "$(read_persisted_ai_targets)")"
    return 0
  fi

  AI_TARGETS="$(read_persisted_ai_targets)"
  echo "AVISO: stdin não é um terminal — usando seleção de IAs: $AI_TARGETS (mude com --ai ou AGENTES_PIPELINE_AI_TARGETS)"
}

persist_ai_targets() {
  local id targets_json="" updated_at

  for id in $AI_TARGETS; do
    targets_json="${targets_json:+$targets_json, }\"$id\""
  done
  updated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p "$AI_CONFIG_DIR"
  cat > "$AI_CONFIG_FILE" <<JSON_EOF
{
  "version": 1,
  "aiTargets": [$targets_json],
  "updatedAt": "$updated_at",
  "updatedBy": "install.sh"
}
JSON_EOF
}

# Persisted before the links and independently of FAIL: the selection is the
# user's declared intent and must not be lost because of a crooked link.
resolve_ai_targets
persist_ai_targets
echo "OK: IAs selecionadas: $AI_TARGETS (registrado em $AI_CONFIG_FILE)"

ensure_link "$REPO_DIR" "$PIPELINE_HOME" "~/agentes-pipeline"
ensure_link "$SKILL_TARGET" "$SKILL_LINK" "skill init-project ($TARGET)"

if has_ai_target codex; then
  mkdir -p "$HOME/.codex/skills"
  ensure_link "$CODEX_SKILL_TARGET" "$CODEX_SKILL_LINK" "skill init-project (Codex)" warn
else
  echo "OK: Codex não selecionado — link do skill init-project pulado"
fi

if has_ai_target cursor; then
  mkdir -p "$HOME/.cursor/skills"
  ensure_link "$CURSOR_SKILL_TARGET" "$CURSOR_SKILL_LINK" "skill init-project (Cursor)" warn
else
  echo "OK: Cursor não selecionado — link do skill init-project pulado"
fi

if ! has_ai_target antigravity; then
  echo "OK: Antigravity não selecionado — etapa do plugin Superpowers-Antigravity pulada"
elif [[ -n "${AGENTES_PIPELINE_SKIP_ANTIGRAVITY:-}" ]]; then
  echo "OK: etapa do plugin Superpowers-Antigravity pulada (AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1)"
elif command -v git >/dev/null 2>&1; then
  if [[ -d "$ANTIGRAVITY_PLUGIN_DIR/.git" ]]; then
    echo "OK: plugin Superpowers-Antigravity já presente em $ANTIGRAVITY_PLUGIN_DIR"
  else
    mkdir -p "$(dirname "$ANTIGRAVITY_PLUGIN_DIR")"
    if git clone "$ANTIGRAVITY_PLUGIN_URL" "$ANTIGRAVITY_PLUGIN_DIR"; then
      echo "OK: plugin Superpowers-Antigravity clonado em $ANTIGRAVITY_PLUGIN_DIR"
    else
      echo "ERRO: falha ao clonar o plugin Superpowers-Antigravity. Resolva manualmente, ou apague $ANTIGRAVITY_PLUGIN_DIR se o clone ficou parcial."
      FAIL=1
    fi
  fi
else
  echo "AVISO: git não encontrado no PATH — pulei a instalação do plugin Superpowers-Antigravity. Instale git e rode este script de novo, ou clone manualmente: git clone $ANTIGRAVITY_PLUGIN_URL $ANTIGRAVITY_PLUGIN_DIR"
fi

echo ""
echo "Lembretes (não automatizáveis por este script):"
echo "  - Dentro do Claude Code, rode: /plugin install superpowers@claude-plugins-official"
if has_ai_target antigravity && ! command -v agy >/dev/null 2>&1; then
  echo "  - Antigravity CLI não encontrado no PATH. Instale com: npm install -g @google/antigravity"
fi

exit "$FAIL"
