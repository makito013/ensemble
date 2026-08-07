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

# Task 1 — PIPELINE.md: terminologia e formato do estado
check "$ROOT/agentes/PIPELINE.md" 'Fases de execução e estado do pipeline' "PIPELINE.md tem a seção de fases/estado"
check "$ROOT/agentes/PIPELINE.md" 'agentes/PIPELINE-STATE.md' "PIPELINE.md documenta o arquivo de estado"
check "$ROOT/agentes/PIPELINE.md" 'agentes/\.pipeline-history/' "PIPELINE.md documenta o arquivamento"
check "$ROOT/agentes/PIPELINE.md" 'Existe um `PIPELINE-STATE.md` em aberto por vez' "PIPELINE.md documenta single-slot"
check "$ROOT/agentes/PIPELINE.md" 'PIPELINE-STATE.md.corrompido' "PIPELINE.md documenta tratamento de estado malformado"

# Task 2 — ARQUITETO.md: instrução de dividir em fases
check "$ROOT/agentes/ARQUITETO.md" 'Dividir a feature em fases' "ARQUITETO.md instrui divisão em fases"
check "$ROOT/gemini/skills/arquiteto/SKILL.md" 'Dividir a feature em fases' "arquiteto/SKILL.md instrui divisão em fases"

# Task 3 — TL.md: plano organizado por fase
check "$ROOT/agentes/TL.md" 'Organizar o plano de implementação por fase' "TL.md instrui organizar plano por fase"
check "$ROOT/agentes/TL.md" 'Fase N —' "TL.md documenta cabeçalho de fase no plano"
check "$ROOT/gemini/skills/tl/SKILL.md" 'Organizar o plano de implementação por fase' "tl/SKILL.md instrui organizar plano por fase"
check "$ROOT/gemini/skills/tl/SKILL.md" 'Fase N —' "tl/SKILL.md documenta cabeçalho de fase no plano"

# Task 4 — ORQUESTRADOR.md: detecção/gravação/arquivamento do estado
for f in "$ROOT/agentes/ORQUESTRADOR.md" "$ROOT/gemini/skills/orquestrador/SKILL.md"; do
  check "$f" 'PIPELINE-STATE.md' "$(basename "$f") menciona PIPELINE-STATE.md"
  check "$f" 'Continuar de onde parei' "$(basename "$f") pergunta continuar/arquivar"
  check "$f" '\.pipeline-history/' "$(basename "$f") documenta arquivamento"
  check "$f" 'PIPELINE-STATE.md.corrompido' "$(basename "$f") trata estado malformado"
  check "$f" 'Estado do pipeline (PIPELINE-STATE.md)' "$(basename "$f") tem seção de estado"
  check "$f" 'contido dentro da fase atual' "$(basename "$f") escopa retrabalho à fase"
done

exit $fail
