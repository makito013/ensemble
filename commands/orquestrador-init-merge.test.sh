#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
  fi
}

check "$DIR/orquestrador-init.md" 'já existir' "comando Claude documenta o caso de merge"
check "$DIR/orquestrador-init.md" 'preserva o que ainda é válido' "comando Claude documenta a regra de merge"
check "$ROOT/gemini/skills/orquestrador-init/SKILL.md" 'já existir' "skill Gemini documenta o caso de merge"

exit $fail
