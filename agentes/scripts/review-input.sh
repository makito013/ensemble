#!/usr/bin/env bash
# review-input.sh — pré-passo determinístico do Revisor (sem LLM).
# Uso: review-input.sh <dir-saida> <base-ref> [<snapshot-anterior>]
#
# Tira um snapshot do working tree (inclui arquivos novos não ignorados e
# mudanças não commitadas) usando um índice temporário — nunca toca o índice
# real, o working tree nem as refs — e grava em <dir-saida>:
#   diff.patch      git diff <base-ref> <snapshot>
#   diffstat.txt    git diff --stat <base-ref> <snapshot>
#   snapshot.txt    hash da árvore do snapshot (registre no PIPELINE-STATE)
#   delta.patch     git diff <snapshot-anterior> <snapshot>   (só com o 3º argumento)
#   delta-stat.txt  git diff --stat <snapshot-anterior> <snapshot>
# `.agents/` (estado e saídas do pipeline) fica fora do snapshot.
# Imprime o hash do snapshot na saída padrão.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: review-input.sh <dir-saida> <base-ref> [<snapshot-anterior>]" >&2
  exit 1
fi
OUT="$1" BASE="$2" PREV="${3:-}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "review-input.sh: não é um repositório git" >&2
  exit 1
}
git rev-parse --verify --quiet "$BASE^{tree}" >/dev/null || {
  echo "review-input.sh: base inválida: $BASE" >&2
  exit 1
}

mkdir -p "$OUT"
TMP_INDEX="$(mktemp)"
trap 'rm -f "$TMP_INDEX"' EXIT
rm -f "$TMP_INDEX"

TOP="$(git rev-parse --show-toplevel)"
if git rev-parse --verify --quiet HEAD >/dev/null; then
  GIT_INDEX_FILE="$TMP_INDEX" git read-tree HEAD
fi
(cd "$TOP" && GIT_INDEX_FILE="$TMP_INDEX" git add -A -- . ':(exclude).agents')
SNAP="$(cd "$TOP" && GIT_INDEX_FILE="$TMP_INDEX" git write-tree)"

git diff "$BASE" "$SNAP" >"$OUT/diff.patch"
git diff --stat "$BASE" "$SNAP" >"$OUT/diffstat.txt"
echo "$SNAP" >"$OUT/snapshot.txt"

if [[ -n "$PREV" ]]; then
  git rev-parse --verify --quiet "$PREV^{tree}" >/dev/null || {
    echo "review-input.sh: snapshot anterior inválido: $PREV" >&2
    exit 1
  }
  git diff "$PREV" "$SNAP" >"$OUT/delta.patch"
  git diff --stat "$PREV" "$SNAP" >"$OUT/delta-stat.txt"
fi

echo "$SNAP"
