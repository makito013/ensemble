#!/usr/bin/env bash
# Testes de paridade comportamental do Time de Design (Fase 4) entre os
# arquivos Gemini tocados nesta fase: orquestrador, orquestrador-design,
# avaliador, ux, brand, copywriter, acessibilidade, dev-design, dev,
# time-design.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../gemini/skills" && pwd)"
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

# grep -qF (nunca grep -q cru) para padrões com colchetes literais como
# "[AVALIADOR]" ou "[DECISÃO NOVA]" — sem -F, o grep básico lê "[AVALIADOR]"
# como classe de caracteres e casa quase qualquer linha, mascarando um teste
# que não testa nada.
checkF() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe"
    fail=1
    return
  fi
  if ! grep -qF -- "$pattern" "$file"; then
    echo "FAIL: $file não contém (literal) '$pattern' ($label)"
    fail=1
    return
  fi
  echo "PASS: $label"
}

# --- Os 7 nomes fixos de papel do Time de Design, no frontmatter certo ---

check "$DIR/orquestrador-design/SKILL.md" '^name: orquestrador-design' "orquestrador-design tem name correto"
check "$DIR/avaliador/SKILL.md"           '^name: avaliador'           "avaliador tem name correto"
check "$DIR/ux/SKILL.md"                  '^name: ux'                  "ux tem name correto"
check "$DIR/brand/SKILL.md"               '^name: brand'               "brand tem name correto"
check "$DIR/copywriter/SKILL.md"          '^name: copywriter'          "copywriter tem name correto"
check "$DIR/acessibilidade/SKILL.md"      '^name: acessibilidade'      "acessibilidade tem name correto"
check "$DIR/dev-design/SKILL.md"          '^name: dev-design'          "dev-design tem name correto"

# --- Contrato [DECISÃO NOVA] nos 5 especialistas: evidência posicional.
#     A frase-âncora "na primeira linha" precisa estar colada ao marcador
#     na mesma ocorrência — não basta o marcador aparecer isolado em algum
#     outro lugar do arquivo (ex.: só citando o marcador de passagem, sem
#     implementar o contrato). ---

MARKER_NA_PRIMEIRA_LINHA='`[DECISÃO NOVA]` na primeira linha'
checkF "$DIR/ux/SKILL.md"             "$MARKER_NA_PRIMEIRA_LINHA" "ux implementa contrato [DECISÃO NOVA] na primeira linha"
checkF "$DIR/brand/SKILL.md"          "$MARKER_NA_PRIMEIRA_LINHA" "brand implementa contrato [DECISÃO NOVA] na primeira linha"
checkF "$DIR/copywriter/SKILL.md"     "$MARKER_NA_PRIMEIRA_LINHA" "copywriter implementa contrato [DECISÃO NOVA] na primeira linha"
checkF "$DIR/acessibilidade/SKILL.md" "$MARKER_NA_PRIMEIRA_LINHA" "acessibilidade implementa contrato [DECISÃO NOVA] na primeira linha"
checkF "$DIR/dev-design/SKILL.md"     "$MARKER_NA_PRIMEIRA_LINHA" "dev-design implementa contrato [DECISÃO NOVA] na primeira linha"

# --- Os dois headers determinísticos do Avaliador ---

checkF "$DIR/avaliador/SKILL.md" '[AVALIADOR] Relatório de Avaliação' "avaliador tem header canônico [AVALIADOR] Relatório de Avaliação"
checkF "$DIR/avaliador/SKILL.md" '[AVALIADOR] Lacuna — rodada k de N' "avaliador tem header compacto [AVALIADOR] Lacuna — rodada k de N"

# --- Classificação blocker-defect / blocker-rigor ---

checkF "$DIR/avaliador/SKILL.md" 'blocker-defect' "avaliador define blocker-defect"
checkF "$DIR/avaliador/SKILL.md" 'blocker-rigor'  "avaliador define blocker-rigor"

# --- Valores embedded/standalone de designContext, nos três arquivos que os usam ---

check "$DIR/orquestrador/SKILL.md" 'embedded'   "orquestrador (Time de Design) define designContext embedded"
check "$DIR/orquestrador/SKILL.md" 'standalone' "orquestrador (Time de Design) define designContext standalone"
check "$DIR/avaliador/SKILL.md"    'designContext' "avaliador liga o critério de feito ao designContext"
check "$DIR/avaliador/SKILL.md"    'embedded'   "avaliador distingue designContext embedded"
check "$DIR/avaliador/SKILL.md"    'standalone' "avaliador distingue designContext standalone"
check "$DIR/time-design/SKILL.md"  'embedded'   "time-design cita designContext embedded (para excluí-lo da sessão)"
check "$DIR/time-design/SKILL.md"  'standalone' "time-design fixa designContext standalone"

# --- time-design referencia orquestrador/SKILL.md (pointer-style, não duplica a mecânica) ---

check "$DIR/time-design/SKILL.md" 'orquestrador/SKILL.md' "time-design aponta para orquestrador/SKILL.md em vez de duplicar a mecânica"

# --- time-design lê CONTEXTO.md antes de tudo, mesmo passo do source
#     commands/time-design.md (achado da rodada 3 do Revisor, Fase 4) ---

check "$DIR/time-design/SKILL.md" '.agents/CONTEXTO.md' "time-design lê CONTEXTO.md antes de iniciar a sessão"

# --- dev principal: consulta ao design system e reabertura de consulta ---

checkF "$DIR/dev/SKILL.md" '.agents/design-system/' "dev consulta .agents/design-system/ antes de escalar"
check "$DIR/dev/SKILL.md" 'reabertura' "dev menciona reabertura de consulta ao Time de Design"

exit $fail
