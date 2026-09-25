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

check_absent() {
  local file="$1" label="$2"
  if [ -e "$file" ]; then
    echo "FAIL: $file existe ($label)"
    fail=1
  else
    echo "PASS: $label"
  fi
}

# --- Task 3: detecção + decisão ---
for f in "$ROOT/agentes/ORQUESTRADOR.md" "$ROOT/gemini/skills/orquestrador/SKILL.md"; do
  check "$f" 'Aprendizado por feedback' "$(basename "$f") tem a seção"
  check "$f" 'regra de aprendizado' "$(basename "$f") menciona regra candidata"
  check "$f" '\.aprendizados-globais-pendentes\.md' "$(basename "$f") referencia a fila global"
done
# Texto de decisão: no lado Claude vive no documento sob demanda
# agentes/APRENDIZADOS.md (o núcleo ORQUESTRADOR.md só aponta para ele).
check "$ROOT/agentes/APRENDIZADOS.md" 'Identifiquei estas regras' "APRENDIZADOS.md tem o texto de decisão no resumo final"
check "$ROOT/agentes/ORQUESTRADOR.md" '.agents/APRENDIZADOS.md' "ORQUESTRADOR.md manda ler APRENDIZADOS.md no resumo final"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Identifiquei estas regras' "orquestrador/SKILL.md (Gemini) tem o texto de decisão"

# --- Task 4: convenção de escrita (movida de PIPELINE.md para APRENDIZADOS.md) ---
check "$ROOT/agentes/APRENDIZADOS.md" 'Convenção: seção' "APRENDIZADOS.md documenta a convenção de Aprendizados"
check "$ROOT/agentes/APRENDIZADOS.md" 'aprendizados-globais-pendentes' "APRENDIZADOS.md documenta a fila global"
check "$ROOT/agentes/APRENDIZADOS.md" 'aprendizados-sync' "APRENDIZADOS.md referencia o comando de sync"

# --- Âncora de posicionamento: rodapé de modelo (não mais a linha-ponteiro para PIPELINE.md) ---
ANCORA='Modelo: definido pelo Orquestrador'
check "$ROOT/agentes/APRENDIZADOS.md" "$ANCORA" "APRENDIZADOS.md posiciona a seção antes do rodapé de modelo"
check "$ROOT/.claude/commands/aprendizados-sync.md" "$ANCORA" "aprendizados-sync usa a mesma âncora"
check "$ROOT/.claude/commands/aprendizados-sync.md" 'agentes/APRENDIZADOS.md' "aprendizados-sync aponta para APRENDIZADOS.md"
for f in "$ROOT/agentes/APRENDIZADOS.md" "$ROOT/.claude/commands/aprendizados-sync.md"; do
  if grep -q 'Subagentes e escolha de modelo' "$f"; then
    echo "FAIL: $f ainda usa a âncora antiga 'Subagentes e escolha de modelo'"
    fail=1
  else
    echo "PASS: $(basename "$f") sem a âncora antiga"
  fi
done

# --- Task 5: comando de sync ---
check "$ROOT/.claude/commands/aprendizados-sync.md" 'aprendizados-globais-pendentes' "comando lê a fila global"
check "$ROOT/.claude/commands/aprendizados-sync.md" 'repo-fonte' "comando avisa que só roda no repo-fonte"
check "$ROOT/.claude/commands/aprendizados-sync.md" '## Aprendizados' "comando escreve na seção correta"
check_absent "$ROOT/commands/aprendizados-sync.md" "comando NÃO existe em commands/ (só em .claude/commands/)"

exit $fail
