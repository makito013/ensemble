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

# Stub for the `claude` binary. Behaviour is selected by FAKE_CLAUDE_MODE:
#   success           exit 0, plain success text
#   success-mentions  exit 0, but the (successful) output talks about rate limits
#   rate-limit        exit 1, rate-limit message on the last line
#   error             exit 1, unrelated error
#   json-error        exit 0, structured JSON result with is_error=true (rate limit)
#   sleep             sleeps longer than the test timeout
# Every call appends the session id (-r argument) to FAKE_CLAUDE_CALLS.
cat > "$FIXTURE/fake-claude.sh" <<'EOF'
#!/usr/bin/env bash
echo "$CLAUDE_CONFIG_DIR" > "$FAKE_CLAUDE_CONFIG_LOG"
echo "$2" >> "$FAKE_CLAUDE_CALLS"
case "${FAKE_CLAUDE_MODE:-success}" in
  success)
    echo "retomado com sucesso"
    exit 0 ;;
  success-mentions)
    echo "Fixed the rate limit handling in api/client.ts; usage limit reached errors are now retried."
    echo "done"
    exit 0 ;;
  rate-limit)
    echo "Claude AI usage limit reached|1760000000"
    exit 1 ;;
  error)
    echo "Error: something unrelated broke"
    exit 1 ;;
  json-error)
    echo '{"type":"result","subtype":"success","is_error":true,"result":"Claude AI usage limit reached|1760000000"}'
    exit 0 ;;
  sleep)
    sleep 5
    exit 0 ;;
esac
EOF
chmod +x "$FIXTURE/fake-claude.sh"

export FAKE_CLAUDE_CONFIG_LOG="$FIXTURE/config-log.txt"
export FAKE_CLAUDE_CALLS="$FIXTURE/calls.txt"
NOW=2000

write_item() {
  # $1 = JSON object literal
  node -e "require('$STORE').writeItem($1);"
}

run_watcher() {
  node -e "
const { run } = require('$MODULE');
console.log(JSON.stringify(run($NOW, '$FIXTURE/fake-claude.sh')));
"
}

reset_queue() {
  rm -rf "$FIXTURE/queue" "$FAKE_CLAUDE_CALLS"
  touch "$FAKE_CLAUDE_CALLS"
}

queue_count() {
  find "$FIXTURE/queue" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' '
}

stale_count() {
  find "$FIXTURE/queue/stale" -name '*.json' 2>/dev/null | wc -l | tr -d ' '
}

expect() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -q -- "$needle"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label. Resultado: $haystack"
    fail=1
  fi
}

expect_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — esperado '$expected', obtido '$actual'"
    fail=1
  fi
}

# --- phase 1: valid item resumes, item with missing cwd goes stale ---
reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-live', config_dir: '$FIXTURE/.claude', queued_at: 1000}"
write_item "{cwd: '$FIXTURE/projeto-fantasma', session_id: 'sess-ghost', config_dir: '$FIXTURE/.claude', queued_at: 1000}"
RESULT=$(FAKE_CLAUDE_MODE=success run_watcher)
expect "$RESULT" '"action":"resumed"' "item com cwd válido foi marcado como 'resumed'"
expect "$RESULT" '"action":"stale-missing-cwd"' "item com cwd inexistente foi marcado como stale-missing-cwd"
expect_eq "$(queue_count)" "0" "fila ativa ficou vazia (item resumido removido, item fantasma movido pra stale)"
expect_eq "$(stale_count)" "1" "exatamente 1 item foi pra stale/"
expect_eq "$(cat "$FAKE_CLAUDE_CONFIG_LOG" 2>/dev/null)" "$FIXTURE/.claude" "CLAUDE_CONFIG_DIR foi corretamente propagado ao processo filho"

# --- phase 2: a rate-limited run (exit != 0) stays queued and does not count
# as an attempt ---
reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-live-2', config_dir: '$FIXTURE/.claude', queued_at: 1500}"
RESULT2=$(FAKE_CLAUDE_MODE=rate-limit run_watcher)
expect "$RESULT2" '"action":"still-blocked"' "item ainda em rate limit foi marcado como still-blocked"
expect "$RESULT2" '"reason":"rate-limit"' "falha reconhecida como rate limit pelas últimas linhas"
expect "$RESULT2" '"attempts":0' "rate limit não conta como tentativa"
expect_eq "$(queue_count)" "1" "item ainda bloqueado permanece na fila"

# --- phase 3 (regression): a successful resume whose output mentions rate
# limits is still a success ---
reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-mentions', config_dir: '$FIXTURE/.claude', queued_at: 1500}"
RESULT3=$(FAKE_CLAUDE_MODE=success-mentions run_watcher)
expect "$RESULT3" '"action":"resumed"' "exit 0 com 'rate limit' no stdout conta como retomada (não still-blocked)"
expect_eq "$(queue_count)" "0" "item retomado sai da fila mesmo com 'rate limit' no stdout"

# --- phase 4: structured JSON result with is_error=true is a failure even
# with exit 0 ---
reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-json', config_dir: '$FIXTURE/.claude', queued_at: 1500}"
RESULT4=$(FAKE_CLAUDE_MODE=json-error run_watcher)
expect "$RESULT4" '"action":"still-blocked"' "resultado JSON com is_error=true é tratado como falha"
expect "$RESULT4" '"reason":"rate-limit"' "resultado JSON de usage limit é classificado como rate limit"

# --- phase 5: a corrupt JSON item is moved to stale/ and does not block the
# other items ---
reset_queue
mkdir -p "$FIXTURE/queue"
printf '{"cwd": "/tmp/x", "session_' > "$FIXTURE/queue/0000-corrupt.json"
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-after-corrupt', config_dir: '$FIXTURE/.claude', queued_at: 1500}"
set +e
RESULT5=$(FAKE_CLAUDE_MODE=success run_watcher 2>&1)
code5=$?
set -e
expect_eq "$code5" "0" "watcher não lança exceção com item corrompido"
expect "$RESULT5" '"action":"stale-corrupt"' "item com JSON corrompido é marcado como stale-corrupt"
expect "$RESULT5" '"action":"resumed"' "os demais itens continuam sendo processados depois do corrompido"
expect_eq "$(queue_count)" "0" "fila não fica travada pelo item corrompido"
if [[ -f "$FIXTURE/queue/stale/0000-corrupt.json" ]]; then
  echo "PASS: item corrompido foi movido para stale/"
else
  echo "FAIL: item corrompido não está em stale/"
  fail=1
fi

# --- phase 6: several StopFailure items of the same session -> one resume ---
reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-dup', config_dir: '$FIXTURE/.claude', queued_at: 1100}"
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-dup', config_dir: '$FIXTURE/.claude', queued_at: 1200}"
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-dup', config_dir: '$FIXTURE/.claude', queued_at: 1300}"
RESULT6=$(FAKE_CLAUDE_MODE=success run_watcher)
expect_eq "$(grep -c 'sess-dup' "$FAKE_CLAUDE_CALLS")" "1" "3 itens da mesma sessão geram 1 única retomada"
expect_eq "$(printf '%s' "$RESULT6" | grep -o '"action":"duplicate"' | wc -l | tr -d ' ')" "2" "itens redundantes marcados como duplicate"
expect_eq "$(queue_count)" "0" "duplicatas e item retomado saem da fila"

# Duplicates of a still-blocked session collapse into a single queued item.
reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-dup-blocked', config_dir: '$FIXTURE/.claude', queued_at: 1100, attempts: 2}"
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-dup-blocked', config_dir: '$FIXTURE/.claude', queued_at: 1200}"
RESULT6B=$(FAKE_CLAUDE_MODE=error run_watcher)
expect_eq "$(queue_count)" "1" "sessão bloqueada com duplicatas fica com 1 item na fila"
expect "$RESULT6B" '"attempts":3' "contador de tentativas herda o maior valor das duplicatas"

# --- phase 7: timeout on spawnSync ---
reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-slow', config_dir: '$FIXTURE/.claude', queued_at: 1500}"
start=$(date +%s)
RESULT7=$(FAKE_CLAUDE_MODE=sleep CLAUDE_CONTINUIDADE_TIMEOUT_MS=500 run_watcher)
elapsed=$(( $(date +%s) - start ))
expect "$RESULT7" '"reason":"timeout"' "retomada que passa do timeout é interrompida e marcada como timeout"
if [[ "$elapsed" -lt 5 ]]; then
  echo "PASS: watcher não espera o processo travado terminar (${elapsed}s)"
else
  echo "FAIL: watcher esperou ${elapsed}s, timeout não foi aplicado"
  fail=1
fi
ATTEMPTS_SAVED=$(node -e "
const store = require('$STORE');
console.log(store.readItem(store.listItems()[0]).attempts);
")
expect_eq "$ATTEMPTS_SAVED" "1" "timeout conta como tentativa e o contador é persistido no item"

# --- phase 8: attempt limit moves the item to stale/ ---
reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-broken', config_dir: '$FIXTURE/.claude', queued_at: 1500, attempts: 4}"
RESULT8=$(FAKE_CLAUDE_MODE=error run_watcher)
expect "$RESULT8" '"action":"stale-max-attempts"' "5ª falha (limite padrão) move o item para stale"
expect_eq "$(queue_count)" "0" "item que estourou o limite sai da fila ativa"
expect_eq "$(stale_count)" "1" "item que estourou o limite está em stale/"

reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-broken-2', config_dir: '$FIXTURE/.claude', queued_at: 1500, attempts: 1}"
RESULT8B=$(FAKE_CLAUDE_MODE=error CLAUDE_CONTINUIDADE_MAX_ATTEMPTS=2 run_watcher)
expect "$RESULT8B" '"action":"stale-max-attempts"' "limite de tentativas é configurável por CLAUDE_CONTINUIDADE_MAX_ATTEMPTS"

reset_queue
write_item "{cwd: '$FIXTURE/projeto-vivo', session_id: 'sess-rl-many', config_dir: '$FIXTURE/.claude', queued_at: 1500, attempts: 4}"
RESULT8C=$(FAKE_CLAUDE_MODE=rate-limit run_watcher)
expect "$RESULT8C" '"action":"still-blocked"' "rate limit nunca estoura o limite de tentativas (só a idade de 48h)"

exit $fail
