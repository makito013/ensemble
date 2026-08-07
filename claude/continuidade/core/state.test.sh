#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/state.js"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
PROJ="$FIXTURE/meu-projeto"
mkdir -p "$PROJ"

fail=0

# load sem nenhuma pausa salva -> SEM_ESTADO_PAUSADO, exit 1
set +e
OUT_VAZIO=$(HOME="$FIXTURE" node "$CLI" load --cwd "$PROJ")
CODE_VAZIO=$?
set -e
if [[ "$CODE_VAZIO" == "1" && "$OUT_VAZIO" == "SEM_ESTADO_PAUSADO" ]]; then
  echo "PASS: load sem pausa salva retorna SEM_ESTADO_PAUSADO com exit 1"
else
  echo "FAIL: esperado exit 1 + SEM_ESTADO_PAUSADO, obtido exit=$CODE_VAZIO saida='$OUT_VAZIO'"
  fail=1
fi

# save grava o resumo
echo "Estava implementando o parser de config. Próximo passo: cobrir o caso de arquivo vazio." \
  | HOME="$FIXTURE" node "$CLI" save --cwd "$PROJ" --session-id "sess-42"

FILE_COUNT=$(find "$FIXTURE/.continuidade/state" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FILE_COUNT" == "1" ]]; then
  echo "PASS: save cria exatamente 1 arquivo de estado"
else
  echo "FAIL: esperado 1 arquivo de estado, encontrado $FILE_COUNT"
  fail=1
fi

# load depois do save retorna o conteúdo
OUT_CHEIO=$(HOME="$FIXTURE" node "$CLI" load --cwd "$PROJ")
if echo "$OUT_CHEIO" | grep -q "parser de config"; then
  echo "PASS: load retorna o resumo salvo"
else
  echo "FAIL: load não retornou o resumo esperado. Saída: $OUT_CHEIO"
  fail=1
fi
if echo "$OUT_CHEIO" | grep -q "session_id: sess-42"; then
  echo "PASS: load inclui o session_id salvo"
else
  echo "FAIL: session_id ausente na saída: $OUT_CHEIO"
  fail=1
fi

# save de novo no mesmo cwd sobrescreve (não empilha)
echo "Resumo atualizado depois de terminar o parser." \
  | HOME="$FIXTURE" node "$CLI" save --cwd "$PROJ" --session-id "sess-43"
FILE_COUNT_2=$(find "$FIXTURE/.continuidade/state" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FILE_COUNT_2" == "1" ]]; then
  echo "PASS: segundo save sobrescreve em vez de empilhar (ainda 1 arquivo)"
else
  echo "FAIL: esperado 1 arquivo após segundo save, encontrado $FILE_COUNT_2"
  fail=1
fi
OUT_ATUALIZADO=$(HOME="$FIXTURE" node "$CLI" load --cwd "$PROJ")
if echo "$OUT_ATUALIZADO" | grep -q "Resumo atualizado"; then
  echo "PASS: load retorna o resumo mais recente"
else
  echo "FAIL: load não retornou o resumo atualizado. Saída: $OUT_ATUALIZADO"
  fail=1
fi

# save sem --session-id retorna fallback para 'desconhecido'
FIXTURE_SEM_SESSAO="$(mktemp -d)"
trap 'rm -rf "$FIXTURE" "$FIXTURE_SEM_SESSAO"' EXIT
PROJ_SEM_SESSAO="$FIXTURE_SEM_SESSAO/projeto-sem-id"
mkdir -p "$PROJ_SEM_SESSAO"

echo "Teste de fallback de session_id." | HOME="$FIXTURE_SEM_SESSAO" node "$CLI" save --cwd "$PROJ_SEM_SESSAO"
OUT_SEM_SESSAO=$(HOME="$FIXTURE_SEM_SESSAO" node "$CLI" load --cwd "$PROJ_SEM_SESSAO")
if echo "$OUT_SEM_SESSAO" | grep -q "session_id: desconhecido"; then
  echo "PASS: save sem --session-id fallback para 'desconhecido'"
else
  echo "FAIL: session_id deveria ser 'desconhecido', saída: $OUT_SEM_SESSAO"
  fail=1
fi

# save sem --cwd retorna erro com exit 2 (sem stack trace)
set +e
OUT_SEM_CWD=$(HOME="$FIXTURE_SEM_SESSAO" node "$CLI" save < /dev/null 2>&1)
CODE_SEM_CWD=$?
set -e
if [[ "$CODE_SEM_CWD" == "2" ]]; then
  # Verifica que não há stack trace (TypeError, Cannot read, etc)
  if echo "$OUT_SEM_CWD" | grep -qE "TypeError|Cannot read|undefined"; then
    echo "FAIL: save sem --cwd retorna exit 2 mas tem stack trace: $OUT_SEM_CWD"
    fail=1
  else
    echo "PASS: save sem --cwd retorna exit 2 sem stack trace"
  fi
else
  echo "FAIL: esperado exit 2, obtido exit=$CODE_SEM_CWD. Saída: $OUT_SEM_CWD"
  fail=1
fi

exit $fail
