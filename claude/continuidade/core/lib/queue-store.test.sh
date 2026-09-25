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

# tryReadItem never throws on corrupt or non-object JSON
printf '{"cwd": "/tmp/x", "sess' > "$FIXTURE/queue/corrupt.json"
printf '[1,2]' > "$FIXTURE/queue/array.json"
TRY=$(node -e "
const store = require('$MODULE');
const a = store.tryReadItem('$FIXTURE/queue/corrupt.json');
const b = store.tryReadItem('$FIXTURE/queue/array.json');
console.log(Boolean(a.error) + ',' + Boolean(b.error) + ',' + (a.item === undefined));
")
if [[ "$TRY" == "true,true,true" ]]; then
  echo "PASS: tryReadItem devolve { error } para JSON corrompido ou que não é objeto, sem lançar"
else
  echo "FAIL: tryReadItem não tratou JSON inválido: $TRY"
  fail=1
fi
rm -f "$FIXTURE/queue/corrupt.json" "$FIXTURE/queue/array.json"

# updateItem rewrites an item in place without leaving temp files behind
FILE3=$(node -e "
const store = require('$MODULE');
console.log(store.writeItem({cwd: '/tmp/projC', session_id: 'sess-3', config_dir: '/tmp/.claude', queued_at: 3000}));
")
ATTEMPTS=$(node -e "
const store = require('$MODULE');
const item = store.readItem('$FILE3');
store.updateItem('$FILE3', Object.assign({}, item, { attempts: 2 }));
console.log(store.readItem('$FILE3').attempts);
")
TMP_LEFT=$(find "$FIXTURE/queue" -maxdepth 1 -name '*.tmp' | wc -l | tr -d ' ')
if [[ "$ATTEMPTS" == "2" && "$TMP_LEFT" == "0" ]]; then
  echo "PASS: updateItem regrava o item sem deixar arquivo temporário"
else
  echo "FAIL: updateItem attempts=$ATTEMPTS tmp=$TMP_LEFT"
  fail=1
fi

# moveToStale never overwrites an item already in stale/ with the same name
cp "$FILE3" "$FIXTURE/queue/stale/$(basename "$FILE3")"
node -e "require('$MODULE').moveToStale('$FILE3');"
STALE_AFTER=$(find "$FIXTURE/queue/stale" -name '*.json' | wc -l | tr -d ' ')
if [[ "$STALE_AFTER" == "3" ]]; then
  echo "PASS: moveToStale com nome repetido não sobrescreve o item já em stale/"
else
  echo "FAIL: stale/ tem $STALE_AFTER itens, esperado 3"
  fail=1
fi

exit $fail
