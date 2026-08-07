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
  check "$f" 'Identifiquei estas regras' "$(basename "$f") tem o texto de decisão no resumo final"
  check "$f" '\.aprendizados-globais-pendentes\.md' "$(basename "$f") referencia a fila global"
done

# --- Task 4: convenção de escrita ---
check "$ROOT/agentes/PIPELINE.md" 'Convenção: seção' "PIPELINE.md documenta a convenção de Aprendizados"
check "$ROOT/agentes/PIPELINE.md" 'aprendizados-globais-pendentes' "PIPELINE.md documenta a fila global"
check "$ROOT/agentes/PIPELINE.md" 'aprendizados-sync' "PIPELINE.md referencia o comando de sync"

# --- Task 5: comando de sync ---
check "$ROOT/.claude/commands/aprendizados-sync.md" 'aprendizados-globais-pendentes' "comando lê a fila global"
check "$ROOT/.claude/commands/aprendizados-sync.md" 'repo-fonte' "comando avisa que só roda no repo-fonte"
check "$ROOT/.claude/commands/aprendizados-sync.md" '## Aprendizados' "comando escreve na seção correta"
check_absent "$ROOT/commands/aprendizados-sync.md" "comando NÃO existe em commands/ (só em .claude/commands/)"

exit $fail
