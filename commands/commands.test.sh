#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

check "$DIR/orquestrador.md" '^argument-hint: \[descrição da tarefa\]' "orquestrador.md tem argument-hint"
check "$DIR/orquestrador.md" '.agents/ORQUESTRADOR.md' "orquestrador.md referencia ORQUESTRADOR.md"
check "$DIR/orquestrador.md" '\$ARGUMENTS' "orquestrador.md injeta \$ARGUMENTS"

check "$DIR/orquestrador-init.md" '^argument-hint: \[pasta opcional\]' "orquestrador-init.md tem argument-hint"
check "$DIR/orquestrador-init.md" '.agents/scripts/detect-projects.sh' "orquestrador-init.md referencia detect-projects.sh"
check "$DIR/orquestrador-init.md" '.agents/ORQUESTRADOR.md' "orquestrador-init.md referencia ORQUESTRADOR.md"

check "$DIR/orquestrador-fix.md" '^argument-hint: {texto do bug}' "orquestrador-fix.md tem argument-hint"
check "$DIR/orquestrador-fix.md" 'CONTEXTO.md' "orquestrador-fix.md lê CONTEXTO.md"
check "$DIR/orquestrador-fix.md" 'recomendo Analista, TL, Dev, QA, Revisor porque' "orquestrador-fix.md tem exemplo de justificativa da recomendação"

check "$DIR/orquestrador-team.md" '^argument-hint: \[ação opcional' "orquestrador-team.md tem argument-hint"
check "$DIR/orquestrador-team.md" 'TEAM.md' "orquestrador-team.md referencia TEAM.md"
check "$DIR/orquestrador-team.md" '.agents/ORQUESTRADOR.md' "orquestrador-team.md referencia ORQUESTRADOR.md"

exit $fail
