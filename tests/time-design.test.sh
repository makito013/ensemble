#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
RODAPE='Modelo: definido pelo Orquestrador (ver `.agents/MODELOS.md`).'
PERSONAS=(ORQUESTRADOR-DESIGN AVALIADOR UX DEV-DESIGN COPYWRITER ACESSIBILIDADE BRAND DESAFIANTE)

# Hermético: instala o template num projeto temporário (mesma cópia do passo 4
# de claude/skills/init-project/SKILL.md) em vez de depender de um `.agents/`
# instalado na raiz do repo (que não é versionado).
PROJ="$(mktemp -d)"
trap 'rm -rf "$PROJ"' EXIT
mkdir -p "$PROJ/.agents"
cp -R "$ROOT/agentes/." "$PROJ/.agents/"

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
  INST="$PROJ/.agents/$p.md"

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

  check "$INST" "$RODAPE" "$p.md (instalado) tem o rodapé de modelo final"
done

# 3 + 4: seção "Time de Design" em PIPELINE.md, fonte e instalado
# (movida de PIPELINE.md para o documento sob demanda TIME-DESIGN-FLOW.md)
check "$ROOT/agentes/TIME-DESIGN-FLOW.md" '# Time de Design' "agentes/TIME-DESIGN-FLOW.md tem a seção Time de Design"
check "$PROJ/.agents/TIME-DESIGN-FLOW.md" '# Time de Design' ".agents/TIME-DESIGN-FLOW.md tem a seção Time de Design"
check "$ROOT/agentes/PIPELINE.md" 'TIME-DESIGN-FLOW.md' "agentes/PIPELINE.md aponta o documento sob demanda do Time de Design"

# 5 + 6: ORQUESTRADOR.md referencia DESIGN-STATE.md e a confirmação obrigatória
check "$ROOT/agentes/ORQUESTRADOR.md" 'DESIGN-STATE.md' "agentes/ORQUESTRADOR.md referencia DESIGN-STATE.md"
check "$ROOT/agentes/ORQUESTRADOR.md" 'Você nunca ativa o Time de Design sozinho' "agentes/ORQUESTRADOR.md tem o texto de confirmação obrigatória"
check "$PROJ/.agents/ORQUESTRADOR.md" 'DESIGN-STATE.md' ".agents/ORQUESTRADOR.md referencia DESIGN-STATE.md"
check "$PROJ/.agents/ORQUESTRADOR.md" 'Você nunca ativa o Time de Design sozinho' ".agents/ORQUESTRADOR.md tem o texto de confirmação obrigatória"

# 7: DEV-DESIGN.md referencia o mecanismo de renderização
check "$ROOT/agentes/DEV-DESIGN.md" 'preview' "DEV-DESIGN.md menciona preview"
check "$ROOT/agentes/DEV-DESIGN.md" '.html' "DEV-DESIGN.md menciona formato .html"

# 8: init-project/SKILL.md atualizado com a contagem nova
check "$ROOT/claude/skills/init-project/SKILL.md" '20 personas' "SKILL.md menciona 20 personas"
check "$ROOT/claude/skills/init-project/SKILL.md" '21 arquivos' "SKILL.md menciona 21 arquivos"
check "$ROOT/claude/skills/init-project/SKILL.md" '7 comandos' "SKILL.md menciona 7 comandos (Fase 3: +/time-design, +/orquestrador-plan)"

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

FASE3_PAIRS_DIFFQ=(ORQUESTRADOR.md DEV.md PIPELINE.md TIME-DESIGN-FLOW.md)
for name in "${FASE3_PAIRS_DIFFQ[@]}"; do
  SRC="$ROOT/agentes/$name"
  INST="$PROJ/.agents/$name"
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
check_absent "$PROJ/.agents/PIPELINE.md" 'é Fase 3' ".agents/PIPELINE.md sem o texto antigo 'é Fase 3'"

# 11: contrato bilateral do marcador determinístico [DECISÃO NOVA] (achado #2 do Revisor, Fase 3)
ESPECIALISTAS=(BRAND UX ACESSIBILIDADE DEV-DESIGN COPYWRITER)
for p in "${ESPECIALISTAS[@]}"; do
  check "$ROOT/agentes/$p.md" '[DECISÃO NOVA]' "agentes/$p.md define o marcador [DECISÃO NOVA]"
  check "$PROJ/.agents/$p.md" '[DECISÃO NOVA]' ".agents/$p.md define o marcador [DECISÃO NOVA]"
done

# Reabertura de consulta vive no documento sob demanda TIME-DESIGN-FLOW.md.
check "$ROOT/agentes/TIME-DESIGN-FLOW.md" '[DECISÃO NOVA]' "agentes/TIME-DESIGN-FLOW.md checa o marcador [DECISÃO NOVA]"
check "$PROJ/.agents/TIME-DESIGN-FLOW.md" '[DECISÃO NOVA]' ".agents/TIME-DESIGN-FLOW.md checa o marcador [DECISÃO NOVA]"
check "$ROOT/agentes/ORQUESTRADOR.md" 'reabertura de consulta' "agentes/ORQUESTRADOR.md manda ler o fluxo na reabertura de consulta"
for f in "$ROOT/agentes/ORQUESTRADOR.md" "$PROJ/.agents/ORQUESTRADOR.md" "$ROOT/agentes/TIME-DESIGN-FLOW.md" "$PROJ/.agents/TIME-DESIGN-FLOW.md"; do
  check_absent "$f" 'o especialista sinalizar' "$(basename "$f") sem a prosa antiga 'o especialista sinalizar'"
done

exit $fail
