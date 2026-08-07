#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check_absent() {
  local file="$1" pattern="$2"
  if grep -q -- "$pattern" "$file"; then
    echo "FAIL: $file ainda contém gatilho antigo ('$pattern')"
    fail=1
  else
    echo "PASS: $file sem gatilho de texto antigo"
  fi
}

check_present() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não menciona '$pattern' ($label)"
    fail=1
  fi
}

check_absent "$ROOT/agentes/ORQUESTRADOR.md" 'mensagem do Bruno começar com "Orquestrador:"'
check_present "$ROOT/agentes/ORQUESTRADOR.md" '/orquestrador' "ORQUESTRADOR.md menciona /orquestrador"

check_absent "$ROOT/AGENTS.md" 'Orquestrador: quero adicionar login com Google'
check_present "$ROOT/AGENTS.md" '/orquestrador' "AGENTS.md menciona /orquestrador"

check_present "$ROOT/README.md" '/orquestrador' "README.md menciona /orquestrador"

exit $fail
