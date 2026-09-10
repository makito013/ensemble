#!/usr/bin/env bash
# agents-md-block.test.sh — cobertura do contrato de scripts/agents-md-block.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT="$SCRIPT_DIR/../scripts/agents-md-block.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

fail=0
case_index=0
# Define NEXT_DIR diretamente (sem `$(...)`): rodar dentro de uma
# substituição de comando executaria o incremento de case_index numa
# subshell, e o incremento nunca voltaria pro shell principal — toda
# chamada acabaria reaproveitando o mesmo diretório "case-1".
next_dir() {
  case_index=$((case_index + 1))
  NEXT_DIR="$FIXTURE/case-$case_index"
  mkdir -p "$NEXT_DIR"
}

pass() { echo "PASS: $1"; }
fail_msg() { echo "FAIL: $1"; fail=1; }

# Roda o script e captura stdout + exit code, sem derrubar o `set -e` do runner.
run_apply() {
  local agents_md="$1" src="$2" errfile
  errfile="$(mktemp)"
  set +e
  APPLY_OUT="$(bash "$SCRIPT" apply "$agents_md" "$src" 2>"$errfile")"
  APPLY_EXIT=$?
  set -e
  APPLY_ERR="$(cat "$errfile" 2>/dev/null || true)"
  rm -f "$errfile"
}

BEGIN='<!-- agentes-pipeline:begin -->'
END='<!-- agentes-pipeline:end -->'

# ---------------------------------------------------------------------------
# 1 — criação: arquivo não existe
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body v1\n' > "$src"
target="$d/AGENTS.md"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 0 && "$APPLY_OUT" == "CREATED=$target" ]]; then
  pass "criação: exit 0 e CREATED="
else
  fail_msg "criação: esperado exit 0 / CREATED=, obtido exit=$APPLY_EXIT out='$APPLY_OUT' err='$APPLY_ERR'"
fi
expected_content="$BEGIN
body v1
$END"
if [[ -f "$target" && "$(cat "$target")" == "$expected_content" ]]; then
  pass "criação: conteúdo do arquivo criado é o bloco completo"
else
  fail_msg "criação: conteúdo inesperado: $(cat "$target" 2>/dev/null || echo '<ausente>')"
fi

# ---------------------------------------------------------------------------
# 2 — anexação: arquivo existe, sem marcadores
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body v1\n' > "$src"
target="$d/AGENTS.md"
printf 'conteúdo pré-existente\nmais uma linha\n' > "$target"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 0 && "$APPLY_OUT" == "APPENDED=$target" ]]; then
  pass "anexação: exit 0 e APPENDED="
else
  fail_msg "anexação: esperado exit 0 / APPENDED=, obtido exit=$APPLY_EXIT out='$APPLY_OUT' err='$APPLY_ERR'"
fi
expected_content="conteúdo pré-existente
mais uma linha

$BEGIN
body v1
$END"
if [[ "$(cat "$target")" == "$expected_content" ]]; then
  pass "anexação: prefixo original preservado e bloco anexado ao final"
else
  fail_msg "anexação: conteúdo inesperado: $(cat "$target")"
fi

# ---------------------------------------------------------------------------
# 3 — atualização: arquivo com 1 par, miolo substituído, resto preservado
#     byte a byte
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body v2\n' > "$src"
target="$d/AGENTS.md"
printf 'antes do bloco\n%s\nbody v1\n%s\ndepois do bloco\n' "$BEGIN" "$END" > "$target"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 0 && "$APPLY_OUT" == "UPDATED=$target" ]]; then
  pass "atualização: exit 0 e UPDATED="
else
  fail_msg "atualização: esperado exit 0 / UPDATED=, obtido exit=$APPLY_EXIT out='$APPLY_OUT' err='$APPLY_ERR'"
fi
expected_content="antes do bloco
$BEGIN
body v2
$END
depois do bloco"
if [[ "$(cat "$target")" == "$expected_content" ]]; then
  pass "atualização: miolo substituído e conteúdo fora dos marcadores preservado byte a byte"
else
  fail_msg "atualização: conteúdo inesperado: $(cat "$target")"
fi

# ---------------------------------------------------------------------------
# 4 — idempotência: aplicar 2x seguidas dá UPDATED depois UNCHANGED, nunca
#     duplica o marcador
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body idempotente\n' > "$src"
target="$d/AGENTS.md"
printf 'x\n%s\nold\n%s\ny\n' "$BEGIN" "$END" > "$target"

run_apply "$target" "$src"
first_out="$APPLY_OUT"
run_apply "$target" "$src"
second_out="$APPLY_OUT"

if [[ "$first_out" == "UPDATED=$target" && "$second_out" == "UNCHANGED=$target" ]]; then
  pass "idempotência: 1ª chamada UPDATED=, 2ª chamada UNCHANGED="
else
  fail_msg "idempotência: esperado UPDATED= depois UNCHANGED=, obtido '$first_out' depois '$second_out'"
fi
begin_hits="$(grep -c -F -- "$BEGIN" "$target")"
if [[ "$begin_hits" -eq 1 ]]; then
  pass "idempotência: marcador de início nunca duplica (count=1)"
else
  fail_msg "idempotência: marcador de início duplicou (count=$begin_hits)"
fi

# ---------------------------------------------------------------------------
# 5 — marcador solitário (só begin) -> exit 3, arquivo original intacto
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body\n' > "$src"
target="$d/AGENTS.md"
original="a\n$BEGIN\nb\n"
printf '%b' "$original" > "$target"
before="$(cat "$target")"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 3 ]]; then
  pass "marcador solitário (só begin): exit 3"
else
  fail_msg "marcador solitário (só begin): esperado exit 3, obtido $APPLY_EXIT"
fi
if [[ "$(cat "$target")" == "$before" ]]; then
  pass "marcador solitário (só begin): arquivo original intacto"
else
  fail_msg "marcador solitário (só begin): arquivo foi modificado"
fi

# ---------------------------------------------------------------------------
# 5b — marcador solitário (só end) -> exit 3, arquivo original intacto
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body\n' > "$src"
target="$d/AGENTS.md"
printf 'a\n%s\nb\n' "$END" > "$target"
before="$(cat "$target")"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 3 ]]; then
  pass "marcador solitário (só end): exit 3"
else
  fail_msg "marcador solitário (só end): esperado exit 3, obtido $APPLY_EXIT"
fi
if [[ "$(cat "$target")" == "$before" ]]; then
  pass "marcador solitário (só end): arquivo original intacto"
else
  fail_msg "marcador solitário (só end): arquivo foi modificado"
fi

# ---------------------------------------------------------------------------
# 6 — marcadores duplicados (2+ pares) -> exit 3, arquivo original intacto
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body\n' > "$src"
target="$d/AGENTS.md"
printf 'a\n%s\nb\n%s\nc\n%s\nd\n%s\ne\n' "$BEGIN" "$END" "$BEGIN" "$END" > "$target"
before="$(cat "$target")"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 3 ]]; then
  pass "marcadores duplicados: exit 3"
else
  fail_msg "marcadores duplicados: esperado exit 3, obtido $APPLY_EXIT"
fi
if [[ "$(cat "$target")" == "$before" ]]; then
  pass "marcadores duplicados: arquivo original intacto"
else
  fail_msg "marcadores duplicados: arquivo foi modificado"
fi

# ---------------------------------------------------------------------------
# 7 — fonte do bloco contendo os próprios marcadores -> erro, nada escrito
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf '%s\ncorpo malicioso\n' "$BEGIN" > "$src"
target="$d/AGENTS.md"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -ne 0 ]]; then
  pass "fonte com marcadores embutidos: rejeitada com exit != 0"
else
  fail_msg "fonte com marcadores embutidos: deveria ter sido rejeitada, obtido exit 0"
fi
if [[ ! -e "$target" ]]; then
  pass "fonte com marcadores embutidos: nenhum arquivo foi criado"
else
  fail_msg "fonte com marcadores embutidos: arquivo-alvo foi criado indevidamente"
fi

# ---------------------------------------------------------------------------
# 8 — marcadores em ordem invertida (end antes de begin) -> exit 3, intacto
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body\n' > "$src"
target="$d/AGENTS.md"
printf 'a\n%s\nmiolo\n%s\nz\n' "$END" "$BEGIN" > "$target"
before="$(cat "$target")"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 3 ]]; then
  pass "ordem invertida (end antes de begin): exit 3"
else
  fail_msg "ordem invertida: esperado exit 3, obtido $APPLY_EXIT out='$APPLY_OUT'"
fi
if [[ "$(cat "$target")" == "$before" ]]; then
  pass "ordem invertida: arquivo original intacto"
else
  fail_msg "ordem invertida: arquivo foi modificado"
fi

# ---------------------------------------------------------------------------
# 8b — begin e end na MESMA linha -> exit 3, intacto (begin_line == end_line)
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body\n' > "$src"
target="$d/AGENTS.md"
printf 'a\n%s%s\nz\n' "$BEGIN" "$END" > "$target"
before="$(cat "$target")"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 3 ]]; then
  pass "marcadores na mesma linha: exit 3"
else
  fail_msg "marcadores na mesma linha: esperado exit 3, obtido $APPLY_EXIT out='$APPLY_OUT'"
fi
if [[ "$(cat "$target")" == "$before" ]]; then
  pass "marcadores na mesma linha: arquivo original intacto"
else
  fail_msg "marcadores na mesma linha: arquivo foi modificado"
fi

# ---------------------------------------------------------------------------
# 8c — marcador de início com texto na MESMA linha -> exit 3, arquivo intacto.
#      head/tail recortam a linha inteira; manter o bloco apagaria o texto
#      adjacente ("anotação do usuário") num arquivo versionado.
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body\n' > "$src"
target="$d/AGENTS.md"
printf 'topo\n%s anotação do usuário\nmiolo\n%s\nrodapé\n' "$BEGIN" "$END" > "$target"
before="$(cat "$target")"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 3 ]]; then
  pass "marcador begin com texto adjacente: exit 3"
else
  fail_msg "marcador begin com texto adjacente: esperado exit 3, obtido $APPLY_EXIT out='$APPLY_OUT'"
fi
if [[ "$(cat "$target")" == "$before" ]]; then
  pass "marcador begin com texto adjacente: arquivo original intacto (anotação preservada)"
else
  fail_msg "marcador begin com texto adjacente: arquivo foi modificado"
fi

# ---------------------------------------------------------------------------
# 8d — marcador de fim com texto ANTES dele na mesma linha -> exit 3, intacto
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body\n' > "$src"
target="$d/AGENTS.md"
printf 'topo\n%s\nmiolo\nnota do usuário %s\nrodapé\n' "$BEGIN" "$END" > "$target"
before="$(cat "$target")"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 3 ]]; then
  pass "marcador end com texto adjacente: exit 3"
else
  fail_msg "marcador end com texto adjacente: esperado exit 3, obtido $APPLY_EXIT out='$APPLY_OUT'"
fi
if [[ "$(cat "$target")" == "$before" ]]; then
  pass "marcador end com texto adjacente: arquivo original intacto"
else
  fail_msg "marcador end com texto adjacente: arquivo foi modificado"
fi

# ---------------------------------------------------------------------------
# 8e — marcador SOZINHO com whitespace nas bordas -> continua válido (não vira
#      exit 3 por engano). O bloco é reescrito e o marcador é normalizado pra
#      forma canônica sem padding.
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body v2\n' > "$src"
target="$d/AGENTS.md"
printf 'topo\n   %s\t\nvelho\n\t%s   \nrodapé\n' "$BEGIN" "$END" > "$target"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 0 && "$APPLY_OUT" == "UPDATED=$target" ]]; then
  pass "marcador com whitespace nas bordas: exit 0 e UPDATED= (não é ambíguo)"
else
  fail_msg "marcador com whitespace nas bordas: esperado exit 0 / UPDATED=, obtido exit=$APPLY_EXIT out='$APPLY_OUT' err='$APPLY_ERR'"
fi
expected_content="topo
$BEGIN
body v2
$END
rodapé"
if [[ "$(cat "$target")" == "$expected_content" ]]; then
  pass "marcador com whitespace nas bordas: miolo substituído e marcador normalizado"
else
  fail_msg "marcador com whitespace nas bordas: conteúdo inesperado: $(cat "$target")"
fi

# ---------------------------------------------------------------------------
# 9 — fonte do bloco inexistente -> exit 2, nenhum arquivo criado
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
target="$d/AGENTS.md"

run_apply "$target" "$d/nao-existe.md"
if [[ "$APPLY_EXIT" -eq 2 ]]; then
  pass "fonte inexistente: exit 2"
else
  fail_msg "fonte inexistente: esperado exit 2, obtido $APPLY_EXIT"
fi
if [[ ! -e "$target" ]]; then
  pass "fonte inexistente: nenhum arquivo-alvo criado"
else
  fail_msg "fonte inexistente: arquivo-alvo foi criado indevidamente"
fi

# ---------------------------------------------------------------------------
# 9b — erros de uso -> exit 2 em todas as formas inválidas de linha de comando
# ---------------------------------------------------------------------------
usage_exit() {
  set +e
  bash "$SCRIPT" "$@" >/dev/null 2>&1
  local ec=$?
  set -e
  printf '%s' "$ec"
}
if [[ "$(usage_exit)" -eq 2 && "$(usage_exit apply so-um-arg)" -eq 2 \
   && "$(usage_exit subcomando-invalido a b)" -eq 2 ]]; then
  pass "uso inválido (sem args / poucos args / subcomando desconhecido): exit 2"
else
  fail_msg "uso inválido: esperado exit 2 nas três formas, obtido '$(usage_exit)' / '$(usage_exit apply so-um-arg)' / '$(usage_exit subcomando-invalido a b)'"
fi

# ---------------------------------------------------------------------------
# 10 — fonte do bloco VAZIA: bloco degenerado (só os marcadores), sem erro,
#      e ainda idempotente
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
: > "$src"
target="$d/AGENTS.md"

run_apply "$target" "$src"
expected_content="$BEGIN
$END"
if [[ "$APPLY_EXIT" -eq 0 && "$(cat "$target" 2>/dev/null)" == "$expected_content" ]]; then
  pass "fonte vazia: gera bloco degenerado begin+end, sem lixo entre eles"
else
  fail_msg "fonte vazia: exit=$APPLY_EXIT conteúdo='$(cat "$target" 2>/dev/null)'"
fi
run_apply "$target" "$src"
if [[ "$APPLY_OUT" == "UNCHANGED=$target" ]]; then
  pass "fonte vazia: 2ª aplicação é UNCHANGED (idempotente)"
else
  fail_msg "fonte vazia: 2ª aplicação deveria ser UNCHANGED, obtido '$APPLY_OUT'"
fi

# ---------------------------------------------------------------------------
# 11 — AGENTS.md pré-existente com CRLF (projeto-alvo Windows): o bloco emitido
#      é sempre LF, então o arquivo fica com finais mistos. O contrato aqui não
#      é "normaliza", é "não corrompe": prefixo original preservado byte a byte,
#      marcador em linha própria, marcador único e idempotência.
#      Obs.: a linha em branco de separação antes do bloco varia por plataforma
#      (a substituição de comando do MSYS/Git Bash come o `\r`), então NÃO é
#      afirmada aqui — ver o teste de append em LF (caso 2) para essa regra.
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body crlf\n' > "$src"
target="$d/AGENTS.md"
printf '# Projeto\r\n\r\nLinha dois\r\n' > "$target"
prefix_bytes="$(wc -c < "$target" | tr -d '[:space:]')"
prefix_md5="$(head -c "$prefix_bytes" "$target" | md5sum)"

run_apply "$target" "$src"
if [[ "$APPLY_EXIT" -eq 0 && "$APPLY_OUT" == "APPENDED=$target" ]]; then
  pass "CRLF pré-existente: exit 0 e APPENDED="
else
  fail_msg "CRLF pré-existente: esperado APPENDED=, obtido exit=$APPLY_EXIT out='$APPLY_OUT' err='$APPLY_ERR'"
fi
if [[ "$(head -c "$prefix_bytes" "$target" | md5sum)" == "$prefix_md5" ]]; then
  pass "CRLF pré-existente: bytes originais (com \\r\\n) preservados no início do arquivo"
else
  fail_msg "CRLF pré-existente: os bytes originais foram alterados"
fi
if grep -q -E -- '^<!-- agentes-pipeline:begin -->$' "$target"; then
  pass "CRLF pré-existente: marcador de início fica em linha própria"
else
  fail_msg "CRLF pré-existente: marcador de início não está em linha própria"
fi
run_apply "$target" "$src"
if [[ "$APPLY_OUT" == "UNCHANGED=$target" ]]; then
  pass "CRLF pré-existente: 2ª aplicação é UNCHANGED (idempotente)"
else
  fail_msg "CRLF pré-existente: 2ª aplicação deveria ser UNCHANGED, obtido '$APPLY_OUT'"
fi

# ---------------------------------------------------------------------------
# 11b — AGENTS.md CRLF que JÁ tem o par de marcadores: substitui o miolo e
#       preserva o rodapé CRLF byte a byte
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'body v2\n' > "$src"
target="$d/AGENTS.md"
printf 'topo\r\n%s\r\nvelho\r\n%s\r\nrodape\r\n' "$BEGIN" "$END" > "$target"

run_apply "$target" "$src"
expected_content="$(printf 'topo\r\n%s\nbody v2\n%s\nrodape\r\n' "$BEGIN" "$END")"
if [[ "$APPLY_OUT" == "UPDATED=$target" && "$(cat "$target")" == "$expected_content" ]]; then
  pass "CRLF com marcadores: miolo substituído, topo e rodapé CRLF preservados"
else
  fail_msg "CRLF com marcadores: out='$APPLY_OUT' conteúdo inesperado"
fi
if [[ "$(grep -c -F -- "$BEGIN" "$target")" -eq 1 ]]; then
  pass "CRLF com marcadores: marcador de início continua único"
else
  fail_msg "CRLF com marcadores: marcador de início duplicou"
fi

# ---------------------------------------------------------------------------
# 12 — arquivo grande (8k linhas) com o bloco no meio: o resultado tem que ser
#      byte a byte igual a um splice reconstruído independentemente, para provar
#      que nenhuma linha de fora do bloco é perdida ou reordenada.
# ---------------------------------------------------------------------------
next_dir; d="$NEXT_DIR"
src="$d/src.md"
printf 'miolo novo linha 1\nmiolo novo linha 2\n' > "$src"
target="$d/AGENTS.md"
{
  for i in $(seq 1 4000); do echo "antes-$i conteúdo <>&\"' com tab	fim"; done
  echo "$BEGIN"
  echo "MIOLO ANTIGO"
  echo "$END"
  for i in $(seq 1 4000); do echo "depois-$i"; done
} > "$target"
# splice esperado, montado sem usar o script sob teste
{ head -n 4000 "$target"; echo "$BEGIN"; cat "$src"; echo "$END"; tail -n +4004 "$target"; } > "$d/expected.md"

run_apply "$target" "$src"
if [[ "$APPLY_OUT" == "UPDATED=$target" ]] && cmp -s "$target" "$d/expected.md"; then
  pass "arquivo grande: resultado idêntico ao splice reconstruído (nenhuma linha perdida)"
else
  fail_msg "arquivo grande: out='$APPLY_OUT'; resultado diverge do splice esperado"
fi
if [[ "$(grep -c '^antes-' "$target")" -eq 4000 && "$(grep -c '^depois-' "$target")" -eq 4000 ]]; then
  pass "arquivo grande: as 8000 linhas fora do bloco continuam todas presentes"
else
  fail_msg "arquivo grande: antes=$(grep -c '^antes-' "$target") depois=$(grep -c '^depois-' "$target") (esperado 4000/4000)"
fi
run_apply "$target" "$src"
if [[ "$APPLY_OUT" == "UNCHANGED=$target" ]]; then
  pass "arquivo grande: 2ª aplicação é UNCHANGED (idempotente)"
else
  fail_msg "arquivo grande: 2ª aplicação deveria ser UNCHANGED, obtido '$APPLY_OUT'"
fi

# ---------------------------------------------------------------------------
# veredito
# ---------------------------------------------------------------------------
if [[ "$fail" -eq 0 ]]; then
  echo "TODOS OS TESTES PASSARAM"
  exit 0
else
  echo "ALGUM TESTE FALHOU"
  exit 1
fi
