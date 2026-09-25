#!/usr/bin/env bash
# Handoffs between pipeline stages: pending-decisions contract, post-analyst
# gate, output templates and traceability (personas + Gemini mirrors).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
G="$ROOT/gemini/skills"
fail=0

# Fixed-string match: patterns contain brackets like "[U]" and "@P0".
check() {
  local file="$1" pattern="$2" label="$3"
  if [[ -f "$file" ]] && grep -qF -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: ${file#"$ROOT"/} não contém '$pattern' ($label)"
    fail=1
  fi
}

check_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -qF -- "$pattern" "$file"; then
    echo "FAIL: ${file#"$ROOT"/} ainda contém '$pattern' ($label)"
    fail=1
  else
    echo "PASS: $label"
  fi
}

# --- Contract defined once in PIPELINE.md ---
check "$ROOT/agentes/PIPELINE.md" '## Decisões pendentes (contrato de handoff)' "PIPELINE.md define o contrato"
check "$ROOT/agentes/PIPELINE.md" '### Decisões pendentes (bloqueantes)' "PIPELINE.md: seção de bloqueantes"
check "$ROOT/agentes/PIPELINE.md" '### Suposições adotadas' "PIPELINE.md: seção de suposições"

# --- Stage personas point to the contract (Claude) and to the orquestrador skill (Gemini) ---
for p in ANALISTA PO ARQUITETO BDD DESIGNER TL DEV QA; do
  check "$ROOT/agentes/$p.md" '`.agents/PIPELINE.md`, "Decisões pendentes"' "$p.md aponta para o contrato"
done
for s in analista po arquiteto bdd designer tl dev qa; do
  check "$G/$s/SKILL.md" 'contrato na skill `orquestrador`, "Decisões pendentes"' "gemini $s aponta para o contrato"
done

# --- No persona talks to the user directly / legacy activation footers ---
for f in "$ROOT"/agentes/*.md "$G"/*/SKILL.md; do
  n="${f#"$ROOT"/}"
  check_absent "$f" 'Espere aprovação do Bruno' "$n sem 'Espere aprovação do Bruno'"
  check_absent "$f" 'Espera a decisão do Bruno' "$n sem 'Espera a decisão do Bruno'"
  check_absent "$f" '**Espera** a decisão' "$n sem '**Espera** a decisão'"
  check_absent "$f" 'Espere aprovação do usuário' "$n sem 'Espere aprovação do usuário'"
  check_absent "$f" 'Para ativar este agente' "$n sem rodapé 'Para ativar este agente'"
done

# --- Output templates ---
for f in "$ROOT/agentes/ANALISTA.md" "$G/analista/SKILL.md"; do
  n="${f#"$ROOT"/}"
  check "$f" '### Critérios de aceitação (verificáveis)' "$n: critérios de aceitação"
  check "$f" '### Fora de escopo' "$n: fora de escopo"
  check_absent "$f" 'para o PO clarificar' "$n: ambiguidade não fica para o PO"
done
for f in "$ROOT/agentes/PO.md" "$G/po/SKILL.md"; do
  n="${f#"$ROOT"/}"
  check "$f" '## Refinamento do PO' "$n: template de saída"
  check "$f" 'US01: Como' "$n: user stories"
  check "$f" '**Pronto quando:** toda RF do Analista está numa US ou marcada fora de escopo.' "$n: critério de pronto"
done
for f in "$ROOT/agentes/ARQUITETO.md" "$G/arquiteto/SKILL.md"; do
  n="${f#"$ROOT"/}"
  check "$f" '## Arquitetura' "$n: template de saída"
  check "$f" '### Contratos entre módulos' "$n: contratos entre módulos"
  check "$f" 'Alternativas rejeitadas' "$n: ADR com alternativas rejeitadas"
  check "$f" 'docs/adr/' "$n: onde gravar ADRs"
  check "$f" '## Fase 1 — ' "$n: fases no formato do TL/PIPELINE-STATE"
  check "$f" '**Fronteira com o TL:**' "$n: fronteira com o TL"
  check "$f" 'Exceção: strings visíveis ao usuário final' "$n: regra de inglês completa"
done
for f in "$ROOT/agentes/DESIGNER.md" "$G/designer/SKILL.md"; do
  n="${f#"$ROOT"/}"
  check "$f" '.agents/design-system/' "$n: consulta o design system"
  check "$f" 'Time de Design' "$n: aponta o Time de Design sem design system"
  check "$f" 'default · loading · vazio · erro · sucesso · disabled' "$n: estados completos"
  check_absent "$f" 'Arquiteto/TL' "$n: não referencia o TL (roda depois)"
done

# --- Traceability ---
for f in "$ROOT/agentes/BDD.md" "$G/bdd/SKILL.md"; do
  n="${f#"$ROOT"/}"
  check "$f" '@RF01 @P0' "$n: tags de rastreabilidade"
  check "$f" '# language: pt' "$n: idioma do Gherkin"
  check "$f" 'aprovação dos fluxos em lote' "$n: aprovação de fluxos em lote via Orquestrador"
done
for f in "$ROOT/agentes/TL.md" "$G/tl/SKILL.md"; do
  n="${f#"$ROOT"/}"
  check "$f" '### Comandos de verificação' "$n: comandos de verificação"
  check "$f" '— cobre: RF01' "$n: tarefa rastreada ao requisito"
  check "$f" '{P/M/G}' "$n: tamanho P/M/G"
  check_absent "$f" 'horas' "$n: sem estimativa em horas"
done
for f in "$ROOT/agentes/QA.md" "$G/qa/SKILL.md"; do
  check "$f" '### Rastreabilidade' "${f#"$ROOT"/}: tabela cenário/RF → teste → status"
done

# --- Repo context before proposing ---
for p in ARQUITETO TL DEV; do
  check "$ROOT/agentes/$p.md" '`.agents/CONTEXTO.md` se existir; cite' "$p.md inspeciona o repo e CONTEXTO.md"
done
for s in arquiteto tl dev; do
  check "$G/$s/SKILL.md" '`.agents/CONTEXTO.md` se existir; cite' "gemini $s inspeciona o repo e CONTEXTO.md"
done

# --- Orchestrator: gate, batched questions, profiles, Time de Design x stage 5 ---
for f in "$ROOT/agentes/ORQUESTRADOR.md" "$G/orquestrador/SKILL.md"; do
  n="${f#"$ROOT"/}"
  check "$f" 'Gate de validação pós-Analista' "$n: gate pós-Analista"
  check "$f" 'numa única mensagem' "$n: decisões pendentes em lote"
  check "$f" 'redispare a **mesma etapa**' "$n: redispara a mesma etapa"
  check "$f" '[U]  Feature com UI' "$n: perfil [U]"
  check "$f" '[T]  Produção com testes' "$n: perfil [T]"
  check "$f" '8. TESTES — QA' "$n: menu renomeado para TESTES"
done
check "$ROOT/agentes/ORQUESTRADOR.md" 'Time de Design ativo ⇒ etapa 5 (Designer) desmarcada' "ORQUESTRADOR.md: Time de Design substitui a etapa 5"
check "$ROOT/agentes/ORQUESTRADOR.md" '`.agents/CONTEXTO.md`, se existir' "ORQUESTRADOR.md: disparo inclui CONTEXTO.md"
check "$ROOT/agentes/PIPELINE.md" '`[U]`' "PIPELINE.md: perfis com código [U]"
check "$ROOT/agentes/PIPELINE.md" '`[T]`' "PIPELINE.md: perfis com código [T]"

exit $fail
