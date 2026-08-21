#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
PONTEIRO='Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.'
PERSONAS=(ACESSIBILIDADE ANALISTA ARQUITETO AVALIADOR BDD BRAND COPYWRITER DESIGNER DEV DEV-DESIGN ORQUESTRADOR ORQUESTRADOR-DESIGN PO QA REVISOR SEGURANCA TL UX)

if grep -q 'Subagentes e escolha de modelo' "$ROOT/agentes/PIPELINE.md" \
   && grep -q 'não funciona ao disparar um' "$ROOT/agentes/PIPELINE.md"; then
  echo "PASS: PIPELINE.md tem a seção com a ressalva de fork"
else
  echo "FAIL: PIPELINE.md sem a seção completa"
  fail=1
fi

for p in "${PERSONAS[@]}"; do
  if grep -qF "$PONTEIRO" "$ROOT/agentes/$p.md"; then
    echo "PASS: $p.md tem a linha-ponteiro"
  else
    echo "FAIL: $p.md sem a linha-ponteiro"
    fail=1
  fi
done

exit $fail
