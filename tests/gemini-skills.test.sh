#!/usr/bin/env bash
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

check "$DIR/orquestrador-init/SKILL.md" '^name: orquestrador-init' "orquestrador-init tem name correto"
check "$DIR/orquestrador-init/SKILL.md" 'CONTEXTO.md' "orquestrador-init menciona CONTEXTO.md"

check "$DIR/orquestrador-fix/SKILL.md" '^name: orquestrador-fix' "orquestrador-fix tem name correto"
check "$DIR/orquestrador-fix/SKILL.md" 'CONTEXTO.md' "orquestrador-fix lê CONTEXTO.md"
check "$DIR/orquestrador-fix/SKILL.md" 'recomendo Analista, TL, Dev, QA, Revisor porque' "orquestrador-fix/SKILL.md tem o mesmo exemplo de justificativa do lado Claude"

check "$DIR/orquestrador-team/SKILL.md" '^name: orquestrador-team' "orquestrador-team tem name correto"
check "$DIR/orquestrador-team/SKILL.md" 'TEAM.md' "orquestrador-team menciona TEAM.md"

# --- Time de Design (Fase 4) — 8 arquivos novos/editados ---

check "$DIR/orquestrador-design/SKILL.md" '^name: orquestrador-design' "orquestrador-design tem name correto"
check "$DIR/orquestrador-design/SKILL.md" 'DESIGN-STATE.md' "orquestrador-design menciona DESIGN-STATE.md"

check "$DIR/avaliador/SKILL.md" '^name: avaliador' "avaliador tem name correto"
check "$DIR/avaliador/SKILL.md" 'Relatório de Avaliação' "avaliador menciona um dos headers (Relatório de Avaliação)"

check "$DIR/ux/SKILL.md" '^name: ux' "ux tem name correto"
check "$DIR/ux/SKILL.md" 'Fluxo de interação' "ux menciona Fluxo de interação"

check "$DIR/brand/SKILL.md" '^name: brand' "brand tem name correto"
check "$DIR/brand/SKILL.md" 'Identidade visual' "brand menciona Identidade visual"

check "$DIR/copywriter/SKILL.md" '^name: copywriter' "copywriter tem name correto"
check "$DIR/copywriter/SKILL.md" 'Microcopy aplicado' "copywriter menciona Microcopy aplicado"

check "$DIR/acessibilidade/SKILL.md" '^name: acessibilidade' "acessibilidade tem name correto"
check "$DIR/acessibilidade/SKILL.md" 'piso WCAG AA' "acessibilidade menciona piso WCAG AA"

check "$DIR/dev-design/SKILL.md" '^name: dev-design' "dev-design tem name correto"
check "$DIR/dev-design/SKILL.md" 'Preview renderizável' "dev-design menciona Preview renderizável"

check "$DIR/time-design/SKILL.md" '^name: time-design' "time-design tem name correto"
check "$DIR/time-design/SKILL.md" 'designContext' "time-design menciona designContext"

exit $fail
