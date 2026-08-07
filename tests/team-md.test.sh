#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

check "$ROOT/agentes/PIPELINE.md" 'Template de TEAM.md' "PIPELINE.md documenta o template de TEAM.md"
check "$ROOT/agentes/PIPELINE.md" '\[x\] 7\. DESENVOLVIMENTO' "PIPELINE.md mostra etapa 7 sempre marcada"
check "$ROOT/agentes/ORQUESTRADOR.md" '.agents/TEAM.md' "ORQUESTRADOR.md referencia TEAM.md no menu"

exit $fail
