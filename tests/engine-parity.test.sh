#!/usr/bin/env bash
# engine-parity.test.sh — structural parity between the Claude source
# (agentes/, commands/, skills/) and the other engines (gemini/, codex/,
# cursor/). There is no generator for the Gemini copies (they are adapted by
# hand), so this is the safety net that catches drift:
#
#   1. Every persona in agentes/ has a Gemini skill (documented exceptions).
#   2. Essential sections of each source persona/flow exist in its Gemini
#      skill. Headings are compared by text, ignoring the # level, because the
#      Gemini orquestrador folds ORQUESTRADOR + PIPELINE + TIME-DESIGN-FLOW
#      into one file and demotes some headings. Each essential heading must
#      also exist in the source, so renaming it there forces updating this list.
#   3. Every command has a Gemini, Codex and Cursor skill (documented
#      exceptions).
#   4. Implicit-invocation locks: every Codex skill has openai.yaml with
#      allow_implicit_invocation: false; every Cursor skill has
#      disable-model-invocation: true.
#   5. No Gemini pipeline skill says "Sempre ativo"; command skills require
#      their explicit prefix.
#   6. coding-standards has the same rule text in every engine (and is the
#      only always-on piece).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
G="$ROOT/gemini/skills"
fail=0
pass() { echo "PASS: $1"; }
failm() { echo "FAIL: $1"; fail=1; }

lower() { tr '[:upper:]' '[:lower:]' <<<"$1"; }

# Heading texts of a markdown file, without the leading #'s.
headings() { awk '/^#+ /{sub(/^#+ /, ""); print}' "$1"; }
has_heading() { headings "$2" | grep -qxF -- "$1"; }

# --- 1. every persona has a Gemini skill -----------------------------------

# On-demand docs, not personas: their content is folded into Gemini skills.
#   PIPELINE, TIME-DESIGN-FLOW -> gemini/skills/orquestrador
#   PLAN-FLOW                  -> gemini/skills/orquestrador-plan
#   MODELOS                    -> read as-is from .agents/MODELOS.md
#   APRENDIZADOS, TEMPLATES    -> read as-is from .agents/ (source-side docs)
DOC_ONLY=" APRENDIZADOS MODELOS PIPELINE PLAN-FLOW TEMPLATES TIME-DESIGN-FLOW "

personas=()
for f in "$ROOT"/agentes/*.md; do
  P="$(basename "$f" .md)"
  [[ "$DOC_ONLY" == *" $P "* ]] && continue
  personas+=("$P")
  if [[ -f "$G/$(lower "$P")/SKILL.md" ]]; then
    pass "persona $P tem skill gemini"
  else
    failm "persona $P sem gemini/skills/$(lower "$P")/SKILL.md"
  fi
done

# --- 2. essential sections -------------------------------------------------

# source file (agentes/<X>.md) | gemini skill | heading text
ESSENTIALS="
ANALISTA|analista|Missão
ANALISTA|analista|Critérios de aceitação (verificáveis)
ANALISTA|analista|Tier da demanda
ANALISTA|analista|Decisões pendentes (bloqueantes)
ANALISTA|analista|Suposições adotadas
ANALISTA|analista|Auto-verificação antes de entregar
PO|po|Output que você entrega
PO|po|User stories
PO|po|MVP vs. depois
PO|po|Decisões pendentes (bloqueantes)
PO|po|Suposições adotadas
ARQUITETO|arquiteto|Output que você entrega
ARQUITETO|arquiteto|Contratos entre módulos
ARQUITETO|arquiteto|ADRs
ARQUITETO|arquiteto|Fases
ARQUITETO|arquiteto|Decisões pendentes (bloqueantes)
ARQUITETO|arquiteto|Suposições adotadas
BDD|bdd|Antes do Gherkin: alinhamento de fluxos (flows-first)
BDD|bdd|Estrutura de output
BDD|bdd|Regras que você segue
BDD|bdd|Bug fora do escopo encontrado no meio do trabalho
DESIGNER|designer|Output que você entrega
DESIGNER|designer|Recomendação ao Orquestrador
DESIGNER|designer|Decisões pendentes (bloqueantes)
DESIGNER|designer|Suposições adotadas
TL|tl|O que você entrega ao Dev
TL|tl|Tarefas (em ordem de execução)
TL|tl|Estratégia de testes
TL|tl|Comandos de verificação
TL|tl|Decisões pendentes (bloqueantes)
TL|tl|Suposições adotadas
DEV|dev|O que você entrega
DEV|dev|Verificação
DEV|dev|Pontos de atenção
DEV|dev|Decisões pendentes (bloqueantes)
DEV|dev|Suposições adotadas
DEV|dev|Testes por tier
DEV|dev|Verificação obrigatória antes de entregar
DEV|dev|Modo retrabalho
DEV|dev|Quando o plano está errado
DEV|dev|Bug fora do escopo encontrado no meio do trabalho
DEV|dev|Consultando o Time de Design
QA|qa|O que você entrega
QA|qa|Regressão (suíte existente inteira)
QA|qa|Falhas classificadas
QA|qa|Veredito
QA|qa|Testes que o Dev já escreveu
QA|qa|Tratamento de falha
QA|qa|Quando você reprova
QA|qa|Bug fora do escopo encontrado no meio do trabalho
REVISOR|revisor|O que você entrega
REVISOR|revisor|Verificação executada
REVISOR|revisor|Veredito Final
REVISOR|revisor|Verificação antes de julgar
REVISOR|revisor|Evidência obrigatória
REVISOR|revisor|Não reportar
REVISOR|revisor|Critérios de aprovação
REVISOR|revisor|Modo completo (escala rápida)
REVISOR|revisor|Modo lente (escalas padrão, rigorosa e mega)
REVISOR|revisor|Modo verificador (fecha a volta)
REVISOR|revisor|Modo verificação (2ª volta, depois de retrabalho)
REVISOR|revisor|Bloqueantes da volta anterior
SEGURANCA|seguranca|O que você entrega
SEGURANCA|seguranca|Checklist OWASP Top 10
SEGURANCA|seguranca|Análise por perfil de risco
SEGURANCA|seguranca|Recomendações de configuração
SEGURANCA|seguranca|Veredito
SEGURANCA|seguranca|O que você SEMPRE verifica
SEGURANCA|seguranca|Perfis de risco (adapta a severidade do relatório)
UX|ux|O que você NÃO faz
UX|ux|O que você entrega
UX|ux|Consulta pontual do Dev principal (reabertura de consulta)
BRAND|brand|O que você NÃO faz
BRAND|brand|O que você entrega
BRAND|brand|Consulta pontual do Dev principal (reabertura de consulta)
COPYWRITER|copywriter|O que você NÃO faz
COPYWRITER|copywriter|O que você entrega
COPYWRITER|copywriter|Consulta pontual do Dev principal (reabertura de consulta)
ACESSIBILIDADE|acessibilidade|O que você entrega
ACESSIBILIDADE|acessibilidade|Bloqueadores (piso WCAG AA)
ACESSIBILIDADE|acessibilidade|Veredito
ACESSIBILIDADE|acessibilidade|Consultável a qualquer momento
ACESSIBILIDADE|acessibilidade|Consulta pontual do Dev principal (reabertura de consulta)
DEV-DESIGN|dev-design|Preview renderizável (critério de \"feito\")
DEV-DESIGN|dev-design|O que você NÃO faz
DEV-DESIGN|dev-design|O que você entrega
DEV-DESIGN|dev-design|Pontos de atenção
DEV-DESIGN|dev-design|Quando o plano está errado
DEV-DESIGN|dev-design|Consulta pontual do Dev principal (reabertura de consulta)
DESAFIANTE|desafiante|O que você recebe
DESAFIANTE|desafiante|Regras
DESAFIANTE|desafiante|O que você entrega
DESAFIANTE|desafiante|O que você NÃO faz
AVALIADOR|avaliador|O que você entrega
AVALIADOR|avaliador|Veredito Final
AVALIADOR|avaliador|Critérios de aprovação
AVALIADOR|avaliador|Rodadas de verificação
AVALIADOR|avaliador|Contrato de entrada por rodada
AVALIADOR|avaliador|Rodada de lacuna (gap round — k<N)
AVALIADOR|avaliador|Rodada de integração (integration round — k=N)
AVALIADOR|avaliador|Depois do veredito
AVALIADOR|avaliador|Modo duelo (só no \"Me Surpreenda\")
AVALIADOR|avaliador|Crítica do campeão
ORQUESTRADOR-DESIGN|orquestrador-design|O que você NÃO faz
ORQUESTRADOR-DESIGN|orquestrador-design|Como você opera (subagente fresco, sem memória)
ORQUESTRADOR-DESIGN|orquestrador-design|Formato de DESIGN-STATE.md
ORQUESTRADOR-DESIGN|orquestrador-design|Torneio (só no modo surpreenda)
ORQUESTRADOR-DESIGN|orquestrador-design|O que você entrega a cada turno
GRILL|grill|O que você NÃO faz
GRILL|grill|Como você opera (subagente fresco, sem memória)
GRILL|grill|Marcador de conclusão
GRILL|grill|Formato de ESTADO.md (campos que você consolida)
GRILL|grill|O que você entrega a cada turno
GRILL|grill|Revisão final (checklist de prontidão)
ORQUESTRADOR|orquestrador|Como você inicia uma sessão
ORQUESTRADOR|orquestrador|Comportamento durante o pipeline
ORQUESTRADOR|orquestrador|Estado do pipeline (PIPELINE-STATE.md)
ORQUESTRADOR|orquestrador|Loop de Retrabalho
ORQUESTRADOR|orquestrador|Teto de convergência
ORQUESTRADOR|orquestrador|Aprendizado por feedback
ORQUESTRADOR|orquestrador|Bug fora do escopo reportado por uma etapa
PIPELINE|orquestrador|Decisões pendentes (contrato de handoff)
TIME-DESIGN-FLOW|orquestrador|Início da sessão e designContext
TIME-DESIGN-FLOW|orquestrador|Mecânica da sessão viva, turno a turno
TIME-DESIGN-FLOW|orquestrador|Modo \"Me Surpreenda\" (revezamento em torneio)
TIME-DESIGN-FLOW|orquestrador|Encerramento e invariante de escrita de estado
TIME-DESIGN-FLOW|orquestrador|Reabertura de consulta pelo Dev principal
PLAN-FLOW|orquestrador-plan|Menu de etapas
PLAN-FLOW|orquestrador-plan|GRILL (etapa 1)
PLAN-FLOW|orquestrador-plan|OPÇÕES (etapa 2)
PLAN-FLOW|orquestrador-plan|PROTÓTIPO (etapa 3, opcional)
PLAN-FLOW|orquestrador-plan|REVISÃO FINAL (etapa 4)
PLAN-FLOW|orquestrador-plan|Entrega
PLAN-FLOW|orquestrador-plan|Formato de ESTADO.md
PLAN-FLOW|orquestrador-plan|Ciclo de vida
"

covered=" "
while IFS='|' read -r src skill heading; do
  [[ -z "$src" ]] && continue
  covered+="$src "
  sf="$ROOT/agentes/$src.md"
  gf="$G/$skill/SKILL.md"
  if ! has_heading "$heading" "$sf"; then
    failm "lista de seções desatualizada: '$heading' não existe mais em agentes/$src.md"
    continue
  fi
  if [[ -f "$gf" ]] && has_heading "$heading" "$gf"; then
    pass "$src → gemini/$skill tem '$heading'"
  else
    failm "drift: agentes/$src.md tem '$heading' e gemini/skills/$skill/SKILL.md não"
  fi
done <<<"$ESSENTIALS"

# Every persona must have essentials listed, or a new one slips by unchecked.
for P in "${personas[@]}"; do
  [[ "$covered" == *" $P "* ]] && pass "persona $P tem seções essenciais declaradas" \
    || failm "persona $P sem seções essenciais em ESSENTIALS (engine-parity.test.sh)"
done

# --- 3. every command exists in every engine -------------------------------

# aprendizados-sync: writes into agentes/*.md and gemini/skills/ of THIS repo,
# so it only makes sense in the source repo (lives only in .claude/commands/).
CMD_EXCEPTIONS=" aprendizados-sync "

cmds="$( { ls "$ROOT"/commands/*.md; ls "$ROOT"/.claude/commands/*.md; } \
  | xargs -n1 basename | sed 's/\.md$//' | LC_ALL=C sort -u)"
[[ -n "$cmds" ]] || failm "nenhum comando encontrado em commands/"
for n in $cmds; do
  if [[ "$CMD_EXCEPTIONS" == *" $n "* ]]; then
    pass "comando $n: exceção documentada (só no repo-fonte)"
    continue
  fi
  [[ -f "$G/$n/SKILL.md" ]] && pass "comando $n tem skill gemini" || failm "comando $n sem gemini/skills/$n/SKILL.md"
  [[ -f "$ROOT/codex/skills/$n/SKILL.md" ]] && pass "comando $n tem skill codex" || failm "comando $n sem codex/skills/$n/SKILL.md"
  [[ -f "$ROOT/cursor/skills/$n/SKILL.md" ]] && pass "comando $n tem skill cursor" || failm "comando $n sem cursor/skills/$n/SKILL.md"
done

# --- 4. implicit-invocation locks ------------------------------------------

for d in "$ROOT"/codex/skills/*/; do
  n="$(basename "$d")"
  y="$d/agents/openai.yaml"
  if [[ -f "$y" ]] && grep -qx 'policy:' "$y" && grep -qx '  allow_implicit_invocation: false' "$y"; then
    pass "codex/$n trava invocação implícita"
  else
    failm "codex/$n sem agents/openai.yaml com policy.allow_implicit_invocation: false"
  fi
done

# coding-standards is an always-on rule, never a gated skill (in Cursor it is
# a rule under cursor/rules/, checked in section 6).
CURSOR_ALWAYS_ON=" coding-standards "
for d in "$ROOT"/cursor/skills/*/; do
  n="$(basename "$d")"
  [[ "$CURSOR_ALWAYS_ON" == *" $n "* ]] && continue
  if grep -qx 'disable-model-invocation: true' "$d/SKILL.md"; then
    pass "cursor/$n trava invocação implícita"
  else
    failm "cursor/$n sem disable-model-invocation: true"
  fi
done

# --- 5. Gemini triggers are manual -----------------------------------------

GEMINI_ALWAYS_ON=" coding-standards "
for d in "$G"/*/; do
  n="$(basename "$d")"
  [[ "$GEMINI_ALWAYS_ON" == *" $n "* ]] && continue
  if grep -qi 'sempre ativo' "$d/SKILL.md"; then
    failm "gemini/$n diz 'Sempre ativo' (o gatilho do pipeline é sempre manual)"
  else
    pass "gemini/$n não se declara sempre ativo"
  fi
done

for n in $cmds; do
  [[ "$CMD_EXCEPTIONS" == *" $n "* ]] && continue
  f="$G/$n/SKILL.md"
  [[ -f "$f" ]] || continue
  if grep -m1 '^description:' "$f" | grep -qF "prefixo explícito \"$n"; then
    pass "gemini/$n exige o prefixo explícito '$n'"
  else
    failm "gemini/$n: description não exige o prefixo explícito \"$n...\""
  fi
done

# --- 6. coding-standards everywhere, same text -----------------------------

CS="$ROOT/skills/coding-standards/SKILL.md"
body() { awk 'NR==1 && $0=="---"{fm=1; next} fm && $0=="---"{fm=0; started=1; next} !fm' "$1" | sed '/./,$!d'; }

if cmp -s "$CS" "$G/coding-standards/SKILL.md"; then
  pass "gemini/coding-standards idêntica a skills/coding-standards"
else
  failm "gemini/skills/coding-standards/SKILL.md difere de skills/coding-standards/SKILL.md"
fi

MDC="$ROOT/cursor/rules/coding-standards.mdc"
if [[ -f "$MDC" ]] && grep -qx 'alwaysApply: true' "$MDC"; then
  pass "cursor/rules/coding-standards.mdc é sempre aplicada"
else
  failm "cursor/rules/coding-standards.mdc ausente ou sem alwaysApply: true"
fi
if [[ -f "$MDC" ]] && [[ "$(body "$MDC")" == "$(body "$CS")" ]]; then
  pass "cursor/coding-standards tem o mesmo texto da fonte"
else
  failm "cursor/rules/coding-standards.mdc diverge do corpo de skills/coding-standards/SKILL.md"
fi

# Codex: the rule body (minus its H1) must appear verbatim in the AGENTS block.
rule="$(body "$CS" | sed '1{/^# /d}' | sed '/./,$!d')"
if python3 - "$ROOT/codex/AGENTS-block.md" "$rule" <<'PY'
import sys
sys.exit(0 if sys.argv[2] in open(sys.argv[1], encoding="utf-8").read() else 1)
PY
then
  pass "codex/AGENTS-block.md traz a regra coding-standards"
else
  failm "codex/AGENTS-block.md não contém o texto de skills/coding-standards/SKILL.md"
fi

exit $fail
