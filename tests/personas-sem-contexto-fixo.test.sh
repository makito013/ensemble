#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "FAIL: $file ainda contém '$pattern' ($label)"
    fail=1
  else
    echo "PASS: $label"
  fi
}

TERMOS=(
  "Contexto do Projeto"
  "Modelo Mental do Sistema"
  "iPad"
  "PTY"
  "isométrico"
  "Habbo"
  "Escritório Virtual"
  "ngrok"
  "tailscale"
  "na rua"
  "Safari"
)

for f in "$ROOT"/agentes/*.md; do
  for termo in "${TERMOS[@]}"; do
    check_absent "$f" "$termo" "$(basename "$f") sem resíduo '$termo'"
  done
done

exit $fail
