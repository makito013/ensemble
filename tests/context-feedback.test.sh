#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$ROOT/agentes/ORQUESTRADOR.md"; then
    echo "PASS: $label"
  else
    echo "FAIL: ORQUESTRADOR.md não contém '$pattern' ($label)"
    fail=1
  fi
}

check 'Atualização de contexto sugerida' "instrução de realimentação presente"
check 'pergunta ao Bruno antes de gravar' "confirmação antes de gravar no CONTEXTO.md"

exit $fail
