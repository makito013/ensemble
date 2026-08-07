#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/decide.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/projeto-existente"

fail=0

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — esperado '$expected', obtido '$actual'"
    fail=1
  fi
}

# item sem session_id -> invalid
R1=$(node -e "
const { decideAction } = require('$MODULE');
console.log(decideAction({cwd: '$FIXTURE/projeto-existente', queued_at: 1000}, 2000));
")
check "sem session_id retorna invalid" "invalid" "$R1"

# cwd não existe -> stale-missing-cwd
R2=$(node -e "
const { decideAction } = require('$MODULE');
console.log(decideAction({cwd: '$FIXTURE/projeto-que-nao-existe', session_id: 's1', queued_at: 1000}, 2000));
")
check "cwd inexistente retorna stale-missing-cwd" "stale-missing-cwd" "$R2"

# mais de 48h -> stale-expired
R3=$(node -e "
const { decideAction, MAX_AGE_MS } = require('$MODULE');
const queuedAt = 1000;
const now = queuedAt + MAX_AGE_MS + 1;
console.log(decideAction({cwd: '$FIXTURE/projeto-existente', session_id: 's1', queued_at: queuedAt}, now));
")
check "mais de 48h retorna stale-expired" "stale-expired" "$R3"

# dentro da janela, cwd existe, campos completos -> retry
R4=$(node -e "
const { decideAction, MAX_AGE_MS } = require('$MODULE');
const queuedAt = 1000;
const now = queuedAt + MAX_AGE_MS - 1;
console.log(decideAction({cwd: '$FIXTURE/projeto-existente', session_id: 's1', queued_at: queuedAt}, now));
")
check "dentro da janela e cwd existe retorna retry" "retry" "$R4"

exit $fail
