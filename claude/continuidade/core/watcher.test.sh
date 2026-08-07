#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/watcher.js"
STORE="$SCRIPT_DIR/lib/queue-store.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
export CLAUDE_CONTINUIDADE_QUEUE_DIR="$FIXTURE/queue"
mkdir -p "$FIXTURE/projeto-vivo"

fail=0

# stub do binário `claude`: primeira chamada responde sucesso, controlado por
# um arquivo-flag que o teste apaga/cria entre as fases
cat > "$FIXTURE/fake-claude.sh" <<'EOF'
#!/usr/bin/env bash
# Write CLAUDE_CONFIG_DIR to a file for testing
echo "$CLAUDE_CONFIG_DIR" > "$FAKE_CLAUDE_CONFIG_LOG"
if [[ -f "$FAKE_CLAUDE_RATE_LIMIT_FLAG" ]]; then
  echo "ainda em rate limit, tente novamente mais tarde"
  exit 0
fi
echo "retomado com sucesso"
exit 0
EOF
chmod +x "$FIXTURE/fake-claude.sh"

# item 1: cwd existe, deve tentar retomar e conseguir (flag ausente)
node -e "
const store = require('$STORE');
store.writeItem({cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-live', config_dir: '$FIXTURE/.claude', queued_at: 1000});
"

# item 2: cwd não existe, deve virar stale
node -e "
const store = require('$STORE');
store.writeItem({cwd: '$FIXTURE/projeto-fantasma', session_id: 'sess-ghost', config_dir: '$FIXTURE/.claude', queued_at: 1000});
"

export FAKE_CLAUDE_RATE_LIMIT_FLAG="$FIXTURE/rate-limit.flag"
export FAKE_CLAUDE_CONFIG_LOG="$FIXTURE/config-log.txt"
NOW=2000
RESULT=$(node -e "
const { run } = require('$MODULE');
const results = run($NOW, '$FIXTURE/fake-claude.sh');
console.log(JSON.stringify(results));
")

if echo "$RESULT" | grep -q '"action":"resumed"'; then
  echo "PASS: item com cwd válido foi marcado como 'resumed'"
else
  echo "FAIL: item com cwd válido não foi retomado. Resultado: $RESULT"
  fail=1
fi
if echo "$RESULT" | grep -q '"action":"stale-missing-cwd"'; then
  echo "PASS: item com cwd inexistente foi marcado como stale-missing-cwd"
else
  echo "FAIL: item com cwd inexistente não foi marcado como stale. Resultado: $RESULT"
  fail=1
fi

REMAINING=$(find "$FIXTURE/queue" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
if [[ "$REMAINING" == "0" ]]; then
  echo "PASS: fila ativa ficou vazia (item resumido removido, item fantasma movido pra stale)"
else
  echo "FAIL: fila ativa ainda tem $REMAINING item(ns), esperado 0"
  fail=1
fi

STALE_COUNT=$(find "$FIXTURE/queue/stale" -name '*.json' | wc -l | tr -d ' ')
if [[ "$STALE_COUNT" == "1" ]]; then
  echo "PASS: exatamente 1 item foi pra stale/"
else
  echo "FAIL: stale/ tem $STALE_COUNT item(ns), esperado 1"
  fail=1
fi

# Verify that CLAUDE_CONFIG_DIR was correctly passed to the child process
if [[ -f "$FAKE_CLAUDE_CONFIG_LOG" ]]; then
  CONFIG_DIR_RECEIVED=$(cat "$FAKE_CLAUDE_CONFIG_LOG")
  if [[ "$CONFIG_DIR_RECEIVED" == "$FIXTURE/.claude" ]]; then
    echo "PASS: CLAUDE_CONFIG_DIR foi corretamente propagado ao processo filho"
  else
    echo "FAIL: CLAUDE_CONFIG_DIR recebido ($CONFIG_DIR_RECEIVED) não corresponde ao esperado ($FIXTURE/.claude)"
    fail=1
  fi
else
  echo "FAIL: FAKE_CLAUDE_CONFIG_LOG não foi criado pelo processo filho"
  fail=1
fi

# --- fase 2: item ainda em rate limit deve permanecer na fila ---
touch "$FAKE_CLAUDE_RATE_LIMIT_FLAG"
node -e "
const store = require('$STORE');
store.writeItem({cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-live-2', config_dir: '$FIXTURE/.claude', queued_at: 1500});
"
RESULT2=$(node -e "
const { run } = require('$MODULE');
const results = run($NOW, '$FIXTURE/fake-claude.sh');
console.log(JSON.stringify(results));
")
if echo "$RESULT2" | grep -q '"action":"still-blocked"'; then
  echo "PASS: item ainda em rate limit foi marcado como still-blocked"
else
  echo "FAIL: item em rate limit não foi marcado corretamente. Resultado: $RESULT2"
  fail=1
fi
REMAINING2=$(find "$FIXTURE/queue" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
if [[ "$REMAINING2" == "1" ]]; then
  echo "PASS: item ainda bloqueado permanece na fila"
else
  echo "FAIL: fila deveria ter 1 item ainda bloqueado, tem $REMAINING2"
  fail=1
fi

exit $fail
