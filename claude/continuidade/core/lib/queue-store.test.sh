#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/queue-store.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
export CLAUDE_CONTINUIDADE_QUEUE_DIR="$FIXTURE/queue"

fail=0

# writeItem cria arquivo dentro da fila
FILE1=$(node -e "
const store = require('$MODULE');
const file = store.writeItem({cwd: '/tmp/projA', session_id: 'sess-1', config_dir: '/tmp/.claude', queued_at: 1000});
console.log(file);
")
if [[ -f "$FILE1" ]]; then
  echo "PASS: writeItem cria o arquivo"
else
  echo "FAIL: writeItem não criou $FILE1"
  fail=1
fi

# listItems lista o item recém-criado
COUNT=$(node -e "
const store = require('$MODULE');
console.log(store.listItems().length);
")
if [[ "$COUNT" == "1" ]]; then
  echo "PASS: listItems encontra 1 item"
else
  echo "FAIL: listItems retornou $COUNT itens, esperado 1"
  fail=1
fi

# readItem retorna o conteúdo certo
SESSION=$(node -e "
const store = require('$MODULE');
const file = store.listItems()[0];
console.log(store.readItem(file).session_id);
")
if [[ "$SESSION" == "sess-1" ]]; then
  echo "PASS: readItem lê session_id corretamente"
else
  echo "FAIL: readItem retornou session_id='$SESSION', esperado 'sess-1'"
  fail=1
fi

# moveToStale move o arquivo pra stale/ e ele some de listItems
node -e "
const store = require('$MODULE');
const file = store.listItems()[0];
store.moveToStale(file);
"
COUNT_AFTER_STALE=$(node -e "
const store = require('$MODULE');
console.log(store.listItems().length);
")
STALE_COUNT=$(find "$FIXTURE/queue/stale" -name '*.json' | wc -l | tr -d ' ')
if [[ "$COUNT_AFTER_STALE" == "0" && "$STALE_COUNT" == "1" ]]; then
  echo "PASS: moveToStale tira o item da fila ativa e o coloca em stale/"
else
  echo "FAIL: após moveToStale, fila ativa=$COUNT_AFTER_STALE (esperado 0), stale=$STALE_COUNT (esperado 1)"
  fail=1
fi

# removeItem apaga um arquivo da fila ativa
FILE2=$(node -e "
const store = require('$MODULE');
const file = store.writeItem({cwd: '/tmp/projB', session_id: 'sess-2', config_dir: '/tmp/.claude', queued_at: 2000});
console.log(file);
")
node -e "
const store = require('$MODULE');
store.removeItem('$FILE2');
"
if [[ ! -f "$FILE2" ]]; then
  echo "PASS: removeItem apaga o arquivo"
else
  echo "FAIL: removeItem não apagou $FILE2"
  fail=1
fi

exit $fail
