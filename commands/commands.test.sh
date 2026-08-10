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

check "$DIR/orquestrador-pr.md" '^argument-hint: \[branch do PR\]' "orquestrador-pr.md tem argument-hint"
check "$DIR/orquestrador-pr.md" '^argument-hint:.*\[commit opcional\]' "orquestrador-pr.md tem commit no argument-hint"
check "$DIR/orquestrador-pr.md" '\$ARGUMENTS' "orquestrador-pr.md injeta \$ARGUMENTS"
check "$DIR/orquestrador-pr.md" 'CONTEXTO.md' "orquestrador-pr.md lê CONTEXTO.md"
check "$DIR/orquestrador-pr.md" 'REVISOR.md' "orquestrador-pr.md referencia REVISOR.md"
check "$DIR/orquestrador-pr.md" 'SEGURANCA.md' "orquestrador-pr.md referencia SEGURANCA.md"
check "$DIR/orquestrador-pr.md" 'general-purpose' "orquestrador-pr.md dispara subagentes general-purpose"
check "$DIR/orquestrador-pr.md" 'opus' "orquestrador-pr.md escala Segurança para Opus"
check "$DIR/orquestrador-pr.md" '\.agents/\.pr-reviews/' "orquestrador-pr.md persiste em .agents/.pr-reviews/"
check "$DIR/orquestrador-pr.md" 'NÃO MERGEAR' "orquestrador-pr.md define veredito NÃO MERGEAR"
check "$DIR/orquestrador-pr.md" 'OK PARA MERGE' "orquestrador-pr.md define veredito OK PARA MERGE"
check "$DIR/orquestrador-pr.md" 'MERGEAR COM RESSALVAS' "orquestrador-pr.md define veredito MERGEAR COM RESSALVAS"
check "$DIR/orquestrador-pr.md" '🔴 BLOQUEADO' "orquestrador-pr.md trata veto de Segurança BLOQUEADO"

exit $fail
