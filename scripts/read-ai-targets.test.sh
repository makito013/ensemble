#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
READER="$SCRIPT_DIR/read-ai-targets.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

fail=0
case_index=0

# Writes $2 as the ai-targets.json of a fresh fake home, then runs the reader
# with the remaining args. Prints stdout; the exit code is captured separately.
make_home() {
  local content="$1" home
  case_index=$((case_index + 1))
  home="$FIXTURE/home-$case_index"
  mkdir -p "$home/.config/agentes-pipeline"
  if [[ "$content" != "__NO_FILE__" ]]; then
    printf '%s' "$content" > "$home/.config/agentes-pipeline/ai-targets.json"
  fi
  printf '%s' "$home"
}

expect() {
  local label="$1" home="$2" expected="$3"
  shift 3
  local actual exit_code

  set +e
  actual="$(HOME="$home" bash "$READER" "$@" 2>/dev/null)"
  exit_code=$?
  set -e

  if [[ "$exit_code" -ne 0 ]]; then
    echo "FAIL: $label — exit code deveria ser 0, foi $exit_code"
    fail=1
    return
  fi

  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — esperado '$expected', obtido '$actual'"
    fail=1
  fi
}

VALID='{
  "version": 1,
  "aiTargets": ["claude", "antigravity"],
  "updatedAt": "2026-09-04T14:03:11Z",
  "updatedBy": "install.sh"
}'

# 1 — arquivo ausente: devolve o default, sem erro
expect "config ausente cai no default claude" \
  "$(make_home __NO_FILE__)" "claude"

# 2 — config válida é lida de volta
expect "config válida é lida de volta" \
  "$(make_home "$VALID")" "claude antigravity"

# 3 — JSON truncado: não quebra, cai no default
expect "JSON truncado cai no default claude" \
  "$(make_home '{ "version": 1, "aiTargets": ["claude", "curs')" "claude"

# 4 — version desconhecida: ainda assim lê o array
expect "version desconhecida ainda é lida" \
  "$(make_home '{ "version": 99, "aiTargets": ["claude", "cursor"] }')" "claude cursor"

# 5 — id desconhecido misturado com válidos: descarta só o desconhecido
expect "id desconhecido é descartado silenciosamente" \
  "$(make_home '{ "version": 1, "aiTargets": ["claude", "bogus", "codex"] }')" "claude codex"

# 6 — claude ausente do array de origem: é injetado mesmo assim
expect "claude é injetado quando ausente do arquivo" \
  "$(make_home '{ "version": 1, "aiTargets": ["cursor"] }')" "claude cursor"

# 7 — --ai substitui totalmente o arquivo (mesma semântica do instalador)
expect "--ai substitui totalmente a config persistida" \
  "$(make_home "$VALID")" "claude cursor" --ai cursor

# 8 — ordem canônica garantida mesmo com entrada fora de ordem
expect "ordem canônica é garantida com entrada fora de ordem" \
  "$(make_home __NO_FILE__)" "claude antigravity codex cursor" --ai "cursor,codex,antigravity,claude"

# 9 — --ai com id desconhecido é tolerante aqui (nunca erro)
expect "--ai com id desconhecido é tolerante (nunca erro)" \
  "$(make_home __NO_FILE__)" "claude codex" --ai "bogus,codex"

# 10 — arquivo com CRLF (gravado no Windows) é lido sem \r residual
expect "config com CRLF é lida corretamente" \
  "$(make_home $'{\r\n  "version": 1,\r\n  "aiTargets": ["claude", "cursor"]\r\n}\r\n')" \
  "claude cursor"

# 11 — arquivo vazio (escrita interrompida) cai no default, sem travar
expect "config vazia cai no default claude" \
  "$(make_home '')" "claude"

# 12 — array vazio: claude continua garantido
expect "array vazio ainda devolve claude" \
  "$(make_home '{ "version": 1, "aiTargets": [] }')" "claude"

if [[ "$fail" -eq 0 ]]; then
  echo "TODOS OS TESTES PASSARAM"
  exit 0
else
  echo "ALGUM TESTE FALHOU"
  exit 1
fi
