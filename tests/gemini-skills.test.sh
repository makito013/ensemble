#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../gemini/skills" && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe"
    fail=1
    return
  fi
  if ! grep -q -- "$pattern" "$file"; then
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
    return
  fi
  echo "PASS: $label"
}

check "$DIR/orquestrador-init/SKILL.md" '^name: orquestrador-init' "orquestrador-init tem name correto"
check "$DIR/orquestrador-init/SKILL.md" 'CONTEXTO.md' "orquestrador-init menciona CONTEXTO.md"

check "$DIR/orquestrador-fix/SKILL.md" '^name: orquestrador-fix' "orquestrador-fix tem name correto"
check "$DIR/orquestrador-fix/SKILL.md" 'CONTEXTO.md' "orquestrador-fix lê CONTEXTO.md"
check "$DIR/orquestrador-fix/SKILL.md" 'recomendo Analista, TL, Dev, QA, Revisor porque' "orquestrador-fix/SKILL.md tem o mesmo exemplo de justificativa do lado Claude"

check "$DIR/orquestrador-team/SKILL.md" '^name: orquestrador-team' "orquestrador-team tem name correto"
check "$DIR/orquestrador-team/SKILL.md" 'TEAM.md' "orquestrador-team menciona TEAM.md"

exit $fail
