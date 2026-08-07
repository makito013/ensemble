#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

# --- Task 1: Tier no Analista ---
check "$ROOT/agentes/ANALISTA.md" 'Tier da demanda' "ANALISTA.md tem seção Tier da demanda"
check "$ROOT/agentes/ANALISTA.md" '\*\*spike\*\*' "ANALISTA.md define tier spike"
check "$ROOT/agentes/ANALISTA.md" '\*\*feature\*\*' "ANALISTA.md define tier feature"
check "$ROOT/agentes/ANALISTA.md" '\*\*critical\*\*' "ANALISTA.md define tier critical"
check "$ROOT/agentes/ANALISTA.md" 'sobrescreva o campo silenciosamente' "ANALISTA.md trata divergência de tier sem sobrescrever"
check "$ROOT/gemini/skills/analista/SKILL.md" 'Tier da demanda' "analista/SKILL.md (Gemini) tem seção Tier da demanda"
check "$ROOT/gemini/skills/analista/SKILL.md" '\*\*critical\*\*' "analista/SKILL.md (Gemini) define tier critical"
check "$ROOT/gemini/skills/analista/SKILL.md" 'sobrescreva o campo silenciosamente' "analista/SKILL.md (Gemini) trata divergência de tier sem sobrescrever"

# --- Task 2: Flows-first no BDD ---
check "$ROOT/agentes/BDD.md" 'alinhamento de fluxos' "BDD.md tem seção de flows-first"
check "$ROOT/agentes/BDD.md" '1 fluxo = 1 caso ponta-a-ponta' "BDD.md tem regra de granularidade"
check "$ROOT/agentes/BDD.md" 'Bug fora do escopo' "BDD.md tem regra de bug fora do escopo"
check "$ROOT/gemini/skills/bdd/SKILL.md" 'alinhamento de fluxos' "bdd/SKILL.md (Gemini) tem seção de flows-first"
check "$ROOT/gemini/skills/bdd/SKILL.md" 'Bug fora do escopo' "bdd/SKILL.md (Gemini) tem regra de bug fora do escopo"

# --- Task 3: Sucesso antes de erro + bug fora do escopo no Dev ---
check "$ROOT/agentes/DEV.md" 'Sucesso antes de erro' "DEV.md tem regra de ordem sucesso-antes-erro"
check "$ROOT/agentes/DEV.md" 'Bug fora do escopo' "DEV.md tem regra de bug fora do escopo"
check "$ROOT/gemini/skills/dev/SKILL.md" 'Sucesso antes de erro' "dev/SKILL.md (Gemini) tem regra de ordem sucesso-antes-erro"
check "$ROOT/gemini/skills/dev/SKILL.md" 'Bug fora do escopo' "dev/SKILL.md (Gemini) tem regra de bug fora do escopo"

# --- Task 4: Sucesso antes de erro + bug fora do escopo no QA ---
check "$ROOT/agentes/QA.md" 'Sucesso antes de erro' "QA.md tem regra de ordem sucesso-antes-erro"
check "$ROOT/agentes/QA.md" 'Bug fora do escopo' "QA.md tem regra de bug fora do escopo"
check "$ROOT/gemini/skills/qa/SKILL.md" 'Sucesso antes de erro' "qa/SKILL.md (Gemini) tem regra de ordem sucesso-antes-erro"
check "$ROOT/gemini/skills/qa/SKILL.md" 'Bug fora do escopo' "qa/SKILL.md (Gemini) tem regra de bug fora do escopo"

# --- Task 5: Menu do Orquestrador exibe o tier ---
check "$ROOT/agentes/ORQUESTRADOR.md" 'Tier sugerido' "ORQUESTRADOR.md mostra tier sugerido no menu"
check "$ROOT/agentes/ORQUESTRADOR.md" 'tier confirmado' "ORQUESTRADOR.md registra tier confirmado no cabeçalho do PIPELINE-STATE"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Tier sugerido' "orquestrador/SKILL.md (Gemini) mostra tier sugerido no menu"

# --- Task 6: PIPELINE.md documenta o tier ---
check "$ROOT/agentes/PIPELINE.md" '## Tier da demanda' "PIPELINE.md documenta tier canonicamente"
check "$ROOT/agentes/PIPELINE.md" 'não força automaticamente um perfil' "PIPELINE.md documenta relação tier x perfil"
check "$ROOT/agentes/PIPELINE.md" 'está repetida de forma autocontida em `BDD.md`, `DEV.md` e' "PIPELINE.md cita onde a regra de bug fora do escopo está repetida"
check "$ROOT/agentes/PIPELINE.md" 'Tier: <tier>' "PIPELINE.md template de PIPELINE-STATE.md inclui linha Tier"

# --- Fix 1: Orquestrador recomenda etapa 10 quando tier é critical ---
check "$ROOT/agentes/ORQUESTRADOR.md" 'recomende explicitamente ativá-la' "ORQUESTRADOR.md recomenda etapa 10 quando tier é critical"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'recomende explicitamente ativá-la' "orquestrador/SKILL.md (Gemini) recomenda etapa 10 quando tier é critical"

# --- Fix 2: Orquestrador recebe reportes de bug fora do escopo ---
check "$ROOT/agentes/ORQUESTRADOR.md" 'Bug fora do escopo reportado por uma etapa' "ORQUESTRADOR.md recebe reportes de bug fora do escopo"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Bug fora do escopo reportado por uma etapa' "orquestrador/SKILL.md (Gemini) recebe reportes de bug fora do escopo"

# --- Fix 3: contradição sobre autoridade do Analista quanto ao tier ---
check "$ROOT/agentes/PIPELINE.md" 'sinaliza divergência em vez de sobrescrever' "PIPELINE.md não dá autoridade de sobrescrita ao Analista"
check "$ROOT/agentes/ANALISTA.md" 'não uma reavaliação sua' "ANALISTA.md esclarece que o campo Tier é o confirmado no menu"

exit $fail
