#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/gemini/skills/orquestrador/SKILL.md"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$FILE"; then
    echo "PASS: $label"
  else
    echo "FAIL: SKILL.md não contém '$pattern' ($label)"
    fail=1
  fi
}

# grep -qF (nunca grep -q cru) para padrões com colchetes literais como
# "[DECISÃO NOVA]" — sem -F, o grep básico lê os colchetes como classe de
# caracteres e casa quase qualquer linha, mascarando um teste que não testa
# nada.
checkF() {
  local pattern="$1" label="$2"
  if grep -qF -- "$pattern" "$FILE"; then
    echo "PASS: $label"
  else
    echo "FAIL: SKILL.md não contém (literal) '$pattern' ($label)"
    fail=1
  fi
}

check '.agents/TEAM.md' "lê TEAM.md para pré-selecionar o menu"
check '.agents/CONTEXTO.md' "lê CONTEXTO.md como pano de fundo"
check 'Atualização de contexto sugerida' "instrução de realimentação de contexto presente"
check 'pergunta.*antes de gravar\|antes de gravar' "confirmação antes de gravar em CONTEXTO.md"
check 'subagentes' "menciona disparo de subagentes próprios"
check 'sempre herda o modelo' "ressalva de variante que sempre herda modelo do disparador"

# --- Seção "Time de Design" dentro de orquestrador/SKILL.md ---

check '.agents/DESIGN-STATE.md' "Time de Design: referencia DESIGN-STATE.md"
check 'nunca ativa o Time de Design' "Time de Design: confirmação obrigatória antes de ativar"
check 'designContext' "Time de Design: define o campo designContext"
check '.design-history/' "Time de Design: arquivamento em .design-history/"
checkF '[DECISÃO NOVA]' "Time de Design: checa o marcador [DECISÃO NOVA] (literal, com colchetes)"

exit $fail
