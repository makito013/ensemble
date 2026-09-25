#!/usr/bin/env bash
# Runs every *.test.sh in the repository (tests/, commands/, scripts/,
# claude/continuidade/**, repo root), prints PASS/FAIL per file and exits
# non-zero when any of them fails. Output of failing suites is replayed at the
# end so CI logs show what broke.
#
# Usage: bash tests/run-all.sh [-v]   (-v streams every suite's output)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

# Collect test files, skipping VCS metadata, dependencies and installed copies
# of the pipeline (.agents/, .agents-backups/, git worktrees under .claude/).
tests=()
while IFS= read -r file; do
  tests+=("$file")
done < <(
  cd "$ROOT" && find . \
    \( -name .git -o -name node_modules -o -name .agents -o -name .agents-backups -o -path ./.claude/worktrees \) -prune -o \
    -type f -name '*.test.sh' -print | sed 's|^\./||' | LC_ALL=C sort
)

if [[ ${#tests[@]} -eq 0 ]]; then
  echo "no *.test.sh files found under $ROOT" >&2
  exit 1
fi

LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

passed=0
failed=()
for t in "${tests[@]}"; do
  log="$LOG_DIR/$(printf '%s' "$t" | tr '/' '_').log"
  if (cd "$ROOT" && bash "$t") > "$log" 2>&1; then
    echo "PASS $t"
    passed=$((passed + 1))
  else
    echo "FAIL $t"
    failed+=("$t")
  fi
  [[ "$VERBOSE" == "1" ]] && sed 's/^/    /' "$log"
done

echo
echo "${passed} passed, ${#failed[@]} failed (${#tests[@]} files)"

if [[ ${#failed[@]} -gt 0 ]]; then
  for t in "${failed[@]}"; do
    echo
    echo "===== output of $t ====="
    cat "$LOG_DIR/$(printf '%s' "$t" | tr '/' '_').log"
  done
  exit 1
fi
exit 0
