#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/queue.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
export CLAUDE_CONTINUIDADE_QUEUE_DIR="$FIXTURE/queue"
export CLAUDE_CONFIG_DIR="$FIXTURE/.claude-perfil-teste"

fail=0

echo '{"cwd":"/tmp/projeto-x","session_id":"sess-abc"}' | node "$CLI"

FILE=$(find "$FIXTURE/queue" -maxdepth 1 -name '*.json' | head -1)
if [[ -n "$FILE" ]]; then
  echo "PASS: queue.js criou um arquivo na fila"
else
  echo "FAIL: nenhum arquivo criado na fila"
  fail=1
fi

CONTENT=$(cat "$FILE")
if echo "$CONTENT" | grep -q '"cwd": "/tmp/projeto-x"'; then
  echo "PASS: cwd do payload original foi preservado"
else
  echo "FAIL: cwd ausente/incorreto no arquivo: $CONTENT"
  fail=1
fi
if echo "$CONTENT" | grep -q '"session_id": "sess-abc"'; then
  echo "PASS: session_id do payload original foi preservado"
else
  echo "FAIL: session_id ausente/incorreto no arquivo: $CONTENT"
  fail=1
fi
if echo "$CONTENT" | grep -q "\"config_dir\": \"$FIXTURE/.claude-perfil-teste\""; then
  echo "PASS: config_dir foi lido de CLAUDE_CONFIG_DIR"
else
  echo "FAIL: config_dir incorreto no arquivo: $CONTENT"
  fail=1
fi
if echo "$CONTENT" | grep -q '"queued_at":'; then
  echo "PASS: queued_at foi adicionado"
else
  echo "FAIL: queued_at ausente no arquivo: $CONTENT"
  fail=1
fi

# Test malformed JSON with stderr warning
FIXTURE2="$(mktemp -d)"
trap 'rm -rf "$FIXTURE" "$FIXTURE2"' EXIT
export CLAUDE_CONTINUIDADE_QUEUE_DIR="$FIXTURE2/queue"

echo 'isso nao e json valido' | node "$CLI" 2>"$FIXTURE2/stderr.log"

FILE2=$(find "$FIXTURE2/queue" -maxdepth 1 -name '*.json' | head -1)
if [[ -n "$FILE2" ]]; then
  echo "PASS: queue.js criou arquivo mesmo com JSON malformado (fallback preservado)"
else
  echo "FAIL: nenhum arquivo criado na fila com JSON malformado"
  fail=1
fi

if [[ -s "$FIXTURE2/stderr.log" ]]; then
  echo "PASS: aviso foi escrito no stderr"
else
  echo "FAIL: stderr vazio (aviso não foi escrito)"
  fail=1
fi

exit $fail
