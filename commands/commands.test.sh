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
# -init é mecânico: não carrega o ORQUESTRADOR inteiro; embute as 7 seções e
# dispara a varredura em haiku.
check "$DIR/orquestrador-init.md" 'não carregue' "orquestrador-init.md não carrega ORQUESTRADOR.md/PIPELINE.md"
check "$DIR/orquestrador-init.md" 'model: "haiku"' "orquestrador-init.md dispara a varredura em haiku"

check "$DIR/orquestrador-fix.md" '^argument-hint: {texto do bug}' "orquestrador-fix.md tem argument-hint"
check "$DIR/orquestrador-fix.md" 'CONTEXTO.md' "orquestrador-fix.md lê CONTEXTO.md"
check "$DIR/orquestrador-fix.md" 'recomendo Analista, TL, Dev, QA, Revisor porque' "orquestrador-fix.md tem exemplo de justificativa da recomendação"

check "$DIR/orquestrador-team.md" '^argument-hint: \[ação opcional' "orquestrador-team.md tem argument-hint"
check "$DIR/orquestrador-team.md" 'TEAM.md' "orquestrador-team.md referencia TEAM.md"
check "$DIR/orquestrador-team.md" '.agents/TEMPLATES.md' "orquestrador-team.md usa o template de TEMPLATES.md (sem carregar o ORQUESTRADOR)"
check "$DIR/orquestrador-team.md" '^model: haiku' "orquestrador-team.md roda em haiku"

check "$DIR/orquestrador-fix.md" 'pipeline-status.sh' "orquestrador-fix.md checa pipeline em aberto antes"
check "$DIR/orquestrador-fix.md" 'tier' "orquestrador-fix.md sugere tier"

check "$DIR/orquestrador-status.md" '.agents/scripts/pipeline-status.sh' "orquestrador-status.md roda pipeline-status.sh"
check "$DIR/orquestrador-status.md" '^model: haiku' "orquestrador-status.md roda em haiku"
check "$DIR/orquestrador-status.md" 'não altere nenhum arquivo' "orquestrador-status.md é só leitura"

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
check "$DIR/orquestrador-pr.md" 'diff.patch' "orquestrador-pr.md grava sempre o diff em diff.patch"
check "$DIR/orquestrador-pr.md" 'nunca o diff inline' "orquestrador-pr.md passa o diff por caminho"
check "$DIR/orquestrador-pr.md" 'Modo lente' "orquestrador-pr.md usa as lentes do Revisor"
check "$DIR/orquestrador-pr.md" 'Modo verificador' "orquestrador-pr.md fecha com o verificador"
if grep -q 'modelo padrão (Sonnet)' "$DIR/orquestrador-pr.md"; then
  echo "FAIL: orquestrador-pr.md ainda assume que o default é Sonnet"
  fail=1
else
  echo "PASS: orquestrador-pr.md não assume default de modelo"
fi

check "$DIR/orquestrador-plan.md" '^argument-hint: \[ideia bruta\]' "orquestrador-plan.md tem argument-hint"
check "$DIR/orquestrador-plan.md" '.agents/GRILL.md' "orquestrador-plan.md referencia GRILL.md"
check "$DIR/orquestrador-plan.md" '\$ARGUMENTS' "orquestrador-plan.md injeta \$ARGUMENTS"
check "$DIR/orquestrador-plan.md" '\[GRILL\] Pronto' "orquestrador-plan.md aguarda marcador GRILL Pronto"
check "$DIR/orquestrador-plan.md" '\.agents/planos/' "orquestrador-plan.md persiste em .agents/planos/"
check "$DIR/orquestrador-plan.md" 'PIPELINE-STATE.md' "orquestrador-plan.md documenta que nunca toca PIPELINE-STATE.md"
check "$DIR/orquestrador-plan.md" '.agents/PLAN-FLOW.md' "orquestrador-plan.md carrega PLAN-FLOW.md"

check "$DIR/time-design.md" '^argument-hint: \[pedido inicial opcional\]' "time-design.md tem argument-hint"
check "$DIR/time-design.md" '.agents/TIME-DESIGN-FLOW.md' "time-design.md carrega TIME-DESIGN-FLOW.md (não o ORQUESTRADOR inteiro)"
check "$DIR/time-design.md" 'designContext: standalone' "time-design.md fixa designContext: standalone"
check "$DIR/time-design.md" 'rápida=1' "time-design.md pergunta o N do Avaliador na escala nomeada"
check "$DIR/time-design.md" '.design-history/' "time-design.md arquiva DESIGN-STATE.md pré-existente"
check "$DIR/time-design.md" '\$ARGUMENTS' "time-design.md injeta \$ARGUMENTS"

exit $fail
