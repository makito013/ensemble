#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
# Rodapé de modelo: substitui a antiga linha-ponteiro para PIPELINE.md
# ("Subagentes e escolha de modelo"), que convidava o subagente a abrir o
# documento inteiro do pipeline. A tabela de modelos vive em MODELOS.md.
RODAPE='Modelo: definido pelo Orquestrador (ver `.agents/MODELOS.md`).'
ANTIGO='Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.'
PERSONAS=(ACESSIBILIDADE ANALISTA ARQUITETO AVALIADOR BDD BRAND COPYWRITER DESAFIANTE DESIGNER DEV DEV-DESIGN GRILL ORQUESTRADOR ORQUESTRADOR-DESIGN PO QA REVISOR SEGURANCA TL UX)

if grep -q 'não funciona ao disparar um' "$ROOT/agentes/MODELOS.md" \
   && grep -q 'Subagentes próprios' "$ROOT/agentes/MODELOS.md"; then
  echo "PASS: MODELOS.md tem a seção de subagentes com a ressalva de fork"
else
  echo "FAIL: MODELOS.md sem a seção completa"
  fail=1
fi

for p in "${PERSONAS[@]}"; do
  if grep -qF "$RODAPE" "$ROOT/agentes/$p.md"; then
    echo "PASS: $p.md tem o rodapé de modelo"
  else
    echo "FAIL: $p.md sem o rodapé de modelo"
    fail=1
  fi
  if grep -qF "$ANTIGO" "$ROOT/agentes/$p.md"; then
    echo "FAIL: $p.md ainda aponta para PIPELINE.md no rodapé"
    fail=1
  fi
done

exit $fail
