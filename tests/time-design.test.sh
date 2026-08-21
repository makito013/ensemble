#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
PONTEIRO='Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.'
PERSONAS=(ORQUESTRADOR-DESIGN AVALIADOR UX DEV-DESIGN COPYWRITER ACESSIBILIDADE BRAND)

check() {
  local file="$1" pattern="$2" label="$3"
  if grep -qF -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
  fi
}

# 1 + 2: par fonte/instalado existe, diff vazio, pointer line no instalado
for p in "${PERSONAS[@]}"; do
  SRC="$ROOT/agentes/$p.md"
  INST="$ROOT/.agents/$p.md"

  if [[ -f "$SRC" ]]; then
    echo "PASS: agentes/$p.md existe"
  else
    echo "FAIL: agentes/$p.md não existe"
    fail=1
  fi

  if [[ -f "$INST" ]]; then
    echo "PASS: .agents/$p.md existe"
  else
    echo "FAIL: .agents/$p.md não existe"
    fail=1
  fi

  if [[ -f "$SRC" && -f "$INST" ]]; then
    if diff -q "$SRC" "$INST" >/dev/null; then
      echo "PASS: $p.md — diff fonte×instalado vazio"
    else
      echo "FAIL: $p.md — diff fonte×instalado não vazio"
      fail=1
    fi
  fi

  check "$INST" "$PONTEIRO" "$p.md (instalado) tem a linha-ponteiro final"
done

# 3 + 4: seção "Time de Design" em PIPELINE.md, fonte e instalado
check "$ROOT/agentes/PIPELINE.md" '## Time de Design' "agentes/PIPELINE.md tem a seção Time de Design"
check "$ROOT/.agents/PIPELINE.md" '## Time de Design' ".agents/PIPELINE.md tem a seção Time de Design"

# 5 + 6: ORQUESTRADOR.md referencia DESIGN-STATE.md e a confirmação obrigatória
check "$ROOT/agentes/ORQUESTRADOR.md" 'DESIGN-STATE.md' "agentes/ORQUESTRADOR.md referencia DESIGN-STATE.md"
check "$ROOT/agentes/ORQUESTRADOR.md" 'Você nunca ativa o Time de Design sozinho' "agentes/ORQUESTRADOR.md tem o texto de confirmação obrigatória"
check "$ROOT/.agents/ORQUESTRADOR.md" 'DESIGN-STATE.md' ".agents/ORQUESTRADOR.md referencia DESIGN-STATE.md"
check "$ROOT/.agents/ORQUESTRADOR.md" 'Você nunca ativa o Time de Design sozinho' ".agents/ORQUESTRADOR.md tem o texto de confirmação obrigatória"

# 7: DEV-DESIGN.md referencia o mecanismo de renderização
check "$ROOT/agentes/DEV-DESIGN.md" 'preview' "DEV-DESIGN.md menciona preview"
check "$ROOT/agentes/DEV-DESIGN.md" '.html' "DEV-DESIGN.md menciona formato .html"

# 8: init-project/SKILL.md atualizado com a contagem nova
check "$ROOT/claude/skills/init-project/SKILL.md" '18 personas' "SKILL.md menciona 18 personas"
check "$ROOT/claude/skills/init-project/SKILL.md" '19 arquivos' "SKILL.md menciona 19 arquivos"

exit $fail
