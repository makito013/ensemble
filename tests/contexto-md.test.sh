#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$ROOT/agentes/PIPELINE.md"; then
    echo "PASS: $label"
  else
    echo "FAIL: PIPELINE.md não contém '$pattern' ($label)"
    fail=1
  fi
}

check 'Template de CONTEXTO.md' "seção existe"
check 'Visão geral do projeto' "seção 1"
check 'Integrações externas' "seção 5 (dependências entre projetos)"
check 'Log de atualizações' "seção 7"

exit $fail
