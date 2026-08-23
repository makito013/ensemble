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

check_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -qF -- "$pattern" "$file"; then
    echo "FAIL: $file ainda contém '$pattern' ($label)"
    fail=1
  else
    echo "PASS: $label"
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
check "$ROOT/claude/skills/init-project/SKILL.md" '6 comandos' "SKILL.md menciona 6 comandos (Fase 3: +/time-design)"

# 9: diff dos 4 pares fonte/espelho tocados nesta Fase 3 (fora do array PERSONAS)
FASE3_PAIRS_DIFFB=("commands/time-design.md:.claude/commands/time-design.md")
for pair in "${FASE3_PAIRS_DIFFB[@]}"; do
  SRC="$ROOT/${pair%%:*}"
  INST="$ROOT/${pair##*:}"
  name="${pair%%:*}"
  if [[ -f "$SRC" && -f "$INST" ]]; then
    if diff -b -q "$SRC" "$INST" >/dev/null; then
      echo "PASS: $name — diff fonte×instalado vazio (whitespace-insensitive)"
    else
      echo "FAIL: $name — diff fonte×instalado não vazio"
      fail=1
    fi
  else
    echo "FAIL: $name — par fonte/instalado ausente"
    fail=1
  fi
done

FASE3_PAIRS_DIFFQ=(ORQUESTRADOR.md DEV.md PIPELINE.md)
for name in "${FASE3_PAIRS_DIFFQ[@]}"; do
  SRC="$ROOT/agentes/$name"
  INST="$ROOT/.agents/$name"
  if [[ -f "$SRC" && -f "$INST" ]]; then
    if diff -q "$SRC" "$INST" >/dev/null; then
      echo "PASS: $name — diff fonte×instalado vazio"
    else
      echo "FAIL: $name — diff fonte×instalado não vazio"
      fail=1
    fi
  else
    echo "FAIL: $name — par fonte/instalado ausente"
    fail=1
  fi
done

# 10: texto antigo "é Fase 3" (comando /time-design e canal de consulta) não sobrevive em PIPELINE.md
# (a única ocorrência legítima restante de "Fase 3" é o exemplo genérico de template do
# PIPELINE-STATE.md — "- [ ] Fase 3 — <nome> — pendente" — que nunca tem o prefixo "é")
check_absent "$ROOT/agentes/PIPELINE.md" 'é Fase 3' "agentes/PIPELINE.md sem o texto antigo 'é Fase 3'"
check_absent "$ROOT/.agents/PIPELINE.md" 'é Fase 3' ".agents/PIPELINE.md sem o texto antigo 'é Fase 3'"

# 11: contrato bilateral do marcador determinístico [DECISÃO NOVA] (achado #2 do Revisor, Fase 3)
ESPECIALISTAS=(BRAND UX ACESSIBILIDADE DEV-DESIGN COPYWRITER)
for p in "${ESPECIALISTAS[@]}"; do
  check "$ROOT/agentes/$p.md" '[DECISÃO NOVA]' "agentes/$p.md define o marcador [DECISÃO NOVA]"
  check "$ROOT/.agents/$p.md" '[DECISÃO NOVA]' ".agents/$p.md define o marcador [DECISÃO NOVA]"
done

check "$ROOT/agentes/ORQUESTRADOR.md" '[DECISÃO NOVA]' "agentes/ORQUESTRADOR.md checa o marcador [DECISÃO NOVA]"
check "$ROOT/.agents/ORQUESTRADOR.md" '[DECISÃO NOVA]' ".agents/ORQUESTRADOR.md checa o marcador [DECISÃO NOVA]"
check_absent "$ROOT/agentes/ORQUESTRADOR.md" 'o especialista sinalizar' "agentes/ORQUESTRADOR.md sem a prosa antiga 'o especialista sinalizar'"
check_absent "$ROOT/.agents/ORQUESTRADOR.md" 'o especialista sinalizar' ".agents/ORQUESTRADOR.md sem a prosa antiga 'o especialista sinalizar'"

exit $fail
