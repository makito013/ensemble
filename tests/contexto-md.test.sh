#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$ROOT/agentes/TEMPLATES.md"; then
    echo "PASS: $label"
  else
    echo "FAIL: TEMPLATES.md não contém '$pattern' ($label)"
    fail=1
  fi
}

check 'Template de CONTEXTO.md' "seção existe"
check 'Visão geral do projeto' "seção 1"
check 'Integrações externas' "seção 5 (dependências entre projetos)"
check 'Log de atualizações' "seção 7"

# /orquestrador-init embute os títulos das 7 seções (não carrega PIPELINE.md).
for t in 'Visão geral do projeto' 'Integrações externas' 'Áreas sensíveis' 'Log de atualizações'; do
  if grep -q -- "$t" "$ROOT/commands/orquestrador-init.md"; then
    echo "PASS: orquestrador-init.md embute '$t'"
  else
    echo "FAIL: orquestrador-init.md não embute '$t'"
    fail=1
  fi
done

exit $fail
