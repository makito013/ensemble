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

check "$ROOT/agentes/ORQUESTRADOR.md" 'Teto de convergência' "ORQUESTRADOR.md tem seção de teto"
check "$ROOT/agentes/ORQUESTRADOR.md" 'Máximo 2 voltas' "ORQUESTRADOR.md define o limite"
check "$ROOT/agentes/ORQUESTRADOR.md" 'Regra anti-oscilação' "ORQUESTRADOR.md tem regra anti-oscilação"
check "$ROOT/agentes/ORQUESTRADOR.md" 'candidata a regra de aprendizado' "ORQUESTRADOR.md liga anti-oscilação ao aprendizado"

check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Teto de convergência' "SKILL.md tem seção de teto"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Máximo 2 voltas' "SKILL.md define o limite"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Regra anti-oscilação' "SKILL.md tem regra anti-oscilação"

check "$ROOT/agentes/PIPELINE.md" 'Voltas:' "PIPELINE.md documenta contagem de voltas no formato do estado"
check "$ROOT/agentes/PIPELINE.md" 'teto de 2 voltas' "PIPELINE.md referencia o teto"

exit $fail
