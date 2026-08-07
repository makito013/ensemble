#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/merge-settings.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

fail=0

# --- caso 1: settings.json não existe ainda ---
SETTINGS1="$FIXTURE/settings-novo.json"
node "$CLI" "$SETTINGS1" StopFailure "" 'node "/caminho/queue.js"' 10
if [[ -f "$SETTINGS1" ]]; then
  echo "PASS: cria settings.json quando não existe"
else
  echo "FAIL: settings.json não foi criado"
  fail=1
fi
if grep -q 'StopFailure' "$SETTINGS1" && grep -q 'queue.js' "$SETTINGS1"; then
  echo "PASS: hook StopFailure presente no arquivo novo"
else
  echo "FAIL: hook StopFailure ausente: $(cat "$SETTINGS1")"
  fail=1
fi

# --- caso 2: settings.json já existe com outros hooks (não pode mexer neles) ---
SETTINGS2="$FIXTURE/settings-existente.json"
cat > "$SETTINGS2" <<'EOF'
{
  "hooks": {
    "Notification": [
      { "hooks": [ { "type": "command", "command": "afplay some.aiff" } ] }
    ]
  }
}
EOF
node "$CLI" "$SETTINGS2" StopFailure "" 'node "/caminho/queue.js"' 10
if grep -q 'afplay some.aiff' "$SETTINGS2"; then
  echo "PASS: hook pré-existente (Notification) foi preservado"
else
  echo "FAIL: hook pré-existente foi perdido: $(cat "$SETTINGS2")"
  fail=1
fi
if grep -q 'StopFailure' "$SETTINGS2"; then
  echo "PASS: hook StopFailure foi adicionado ao lado do existente"
else
  echo "FAIL: hook StopFailure não foi adicionado: $(cat "$SETTINGS2")"
  fail=1
fi

# --- caso 3: rodar de novo não duplica (idempotente) ---
node "$CLI" "$SETTINGS2" StopFailure "" 'node "/caminho/queue.js"' 10
COUNT=$(grep -o 'queue.js' "$SETTINGS2" | wc -l | tr -d ' ')
if [[ "$COUNT" == "1" ]]; then
  echo "PASS: rodar o merge de novo não duplica a entrada (idempotente)"
else
  echo "FAIL: entrada duplicada, 'queue.js' aparece $COUNT vezes"
  fail=1
fi

exit $fail
