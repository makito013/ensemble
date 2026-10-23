#!/usr/bin/env bash
# board.sh — task board (one card per task) for the pipeline. Deterministic, no LLM.
#
# The board is decentralized: there is no central index file. Each task is a
# folder with its own CARTAO.md, so two devs working on different tasks never
# touch the same file, and the board is always computed from the cards.
#
# Where the board lives (opt-in sharing):
#   local  (default)  .agents/quadro/   — inside .agents/, which is gitignored
#   shared            .agents-shared/   — a visible folder the team may commit
# `share` / `unshare` move the board between the two. Nothing is ever deleted.
#
# Usage: board.sh [--root DIR] <command> [args]
#   where                         print "<mode> <dir>" (mode: local|shared)
#   new <slug> <title...>         create a card (status: refinando), print its id
#   set <id> <field> <value...>   set a header field (Status, Responsável, Branch, Tier, Perfil, Refinamento)
#   log <id> <message...>         append a line to the card's "## Log"
#   attach <id> <file...>         copy files into the card's planejamento/ folder
#   show <id>                     print the card
#   list [--remote]               board grouped by status; --remote also reads remote branches
#   related [--except <id>] <path...>  cards whose "## Onde" mentions one of the paths
#   share | unshare               move the board to .agents-shared/ or back to .agents/quadro/
#
# Exit codes: 0 ok · 1 not found / refused · 2 usage error
set -euo pipefail

ROOT="."
if [[ "${1:-}" == "--root" ]]; then
  ROOT="${2:?--root requires a directory}"
  shift 2
fi

LOCAL_DIR="$ROOT/.agents/quadro"
SHARED_DIR="$ROOT/.agents-shared"
SHARED_REL=".agents-shared"
STATUSES="refinando pronto em-andamento em-revisao bloqueada concluida cancelada"
FIELDS="Status Responsável Branch Tier Perfil Refinamento"

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "$1" >&2; exit "${2:-1}"; }

now() { date '+%Y-%m-%d %H:%M'; }

author() {
  local name
  name="$(git -C "$ROOT" config user.name 2>/dev/null || true)"
  [[ -n "$name" ]] || name="${USER:-desconhecido}"
  printf '%s' "$name"
}

current_branch() { git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-"; }

mode() { [[ -d "$SHARED_DIR" ]] && echo shared || echo local; }
board_dir() { [[ "$(mode)" == shared ]] && echo "$SHARED_DIR" || echo "$LOCAL_DIR"; }

card_path() {
  local id="$1" dir
  dir="$(board_dir)/tarefas/$id"
  [[ -f "$dir/CARTAO.md" ]] || die "cartão não encontrado: $id"
  printf '%s' "$dir/CARTAO.md"
}

valid_status() {
  local s
  for s in $STATUSES; do [[ "$1" == "$s" ]] && return 0; done
  return 1
}

valid_field() {
  local f
  for f in $FIELDS; do [[ "$1" == "$f" ]] && return 0; done
  return 1
}

# Rewrite a file in place through a temp file (portable: no `sed -i`).
rewrite() {
  local file="$1" tmp
  shift
  tmp="$(mktemp)"
  "$@" <"$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

# Set "Field: value" in the header (before the first "## "); adds it if missing.
set_field() {
  local file="$1" field="$2" value="$3"
  rewrite "$file" awk -v f="$field" -v v="$value" '
    BEGIN { done = 0 }
    !done && /^## / { print f ": " v; done = 1 }
    !done && index($0, f ":") == 1 { print f ": " v; done = 1; next }
    { print }
    END { if (!done) print f ": " v }
  '
}

append_log() {
  local file="$1" line="$2"
  rewrite "$file" awk -v l="$line" '
    { lines[NR] = $0 }
    /^## Log[ \t]*$/ { log_at = NR }
    END {
      if (!log_at) {
        for (i = 1; i <= NR; i++) print lines[i]
        print ""; print "## Log"; print l
        exit
      }
      # Insert after the last non-blank line of the "## Log" section.
      end_at = log_at
      for (i = log_at + 1; i <= NR; i++) {
        if (lines[i] ~ /^## /) break
        if (lines[i] !~ /^[ \t]*$/) end_at = i
      }
      for (i = 1; i <= NR; i++) { print lines[i]; if (i == end_at) print l }
    }
  '
}

touch_card() { set_field "$1" "Atualizado" "$(now)"; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-48
}

cmd_where() { echo "$(mode) $(board_dir)"; }

cmd_new() {
  [[ $# -ge 2 ]] || usage
  local slug title base id n dir
  slug="$(slugify "$1")"
  shift
  title="$*"
  [[ -n "$slug" ]] || die "slug inválido" 2
  base="$(date '+%Y%m%d')-$slug"
  id="$base"
  n=2
  while [[ -e "$(board_dir)/tarefas/$id" ]]; do
    id="$base-$n"
    n=$((n + 1))
  done
  dir="$(board_dir)/tarefas/$id"
  mkdir -p "$dir"
  cat >"$dir/CARTAO.md" <<EOF
# $title

ID: $id
Status: refinando
Responsável: $(author)
Branch: $(current_branch)
Criado: $(now)
Atualizado: $(now)
Tier: -
Perfil: -
Refinamento: -

## Resumo
(preenchido pelo Orquestrador)

## Onde
(arquivos e módulos tocados — preenchido a partir do refinamento)

## Critérios de aceitação

## Progresso

## Decisões

## Log
- $(now) — $(author) — cartão criado
EOF
  echo "$id"
}

cmd_set() {
  [[ $# -ge 3 ]] || usage
  local id="$1" field="$2" file value
  shift 2
  value="$*"
  valid_field "$field" || die "campo não editável: $field (use: $FIELDS)" 2
  if [[ "$field" == Status ]] && ! valid_status "$value"; then
    die "status inválido: $value (use: $STATUSES)" 2
  fi
  file="$(card_path "$id")"
  set_field "$file" "$field" "$value"
  touch_card "$file"
  if [[ "$field" == Status ]]; then
    append_log "$file" "- $(now) — $(author) — status: $value"
  fi
}

cmd_log() {
  [[ $# -ge 2 ]] || usage
  local id="$1" file
  shift
  file="$(card_path "$id")"
  append_log "$file" "- $(now) — $(author) — $*"
  touch_card "$file"
}

cmd_attach() {
  [[ $# -ge 2 ]] || usage
  local id="$1" file dest f
  shift
  file="$(card_path "$id")"
  dest="$(dirname "$file")/planejamento"
  mkdir -p "$dest"
  for f in "$@"; do
    [[ -f "$f" ]] || die "arquivo não encontrado: $f"
    cp "$f" "$dest/"
  done
  touch_card "$file"
}

cmd_show() {
  [[ $# -eq 1 ]] || usage
  cat "$(card_path "$1")"
}

# One TSV row per card on stdin: id, status, title, owner, branch, updated, source.
card_row() {
  awk -v src="$1" '
    # sub() instead of substr(): byte vs character offsets differ between awks
    # for the accented "Responsável:" label.
    NR == 1 && sub(/^# /, "") { title = $0; next }
    /^## / { exit }
    sub(/^ID:/, "") { id = $0; next }
    sub(/^Status:/, "") { st = $0; next }
    sub(/^Responsável:/, "") { owner = $0; next }
    sub(/^Branch:/, "") { br = $0; next }
    sub(/^Atualizado:/, "") { up = $0; next }
    END {
      gsub(/^[ \t]+|[ \t]+$/, "", id); gsub(/^[ \t]+|[ \t]+$/, "", st)
      gsub(/^[ \t]+|[ \t]+$/, "", owner); gsub(/^[ \t]+|[ \t]+$/, "", br)
      gsub(/^[ \t]+|[ \t]+$/, "", up)
      if (id != "") printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, st, title, owner, br, up, src
    }
  '
}

local_rows() {
  local f
  for f in "$(board_dir)"/tarefas/*/CARTAO.md; do
    [[ -f "$f" ]] || continue
    card_row "local" <"$f"
  done
}

# Cards that exist only on remote branches (pushed by other devs, not merged yet).
remote_rows() {
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 0
  local ref path
  git -C "$ROOT" for-each-ref --format='%(refname:short)' refs/remotes | while IFS= read -r ref; do
    [[ "$ref" == */HEAD || "$ref" != */* ]] && continue
    git -C "$ROOT" ls-tree -r --name-only "$ref" -- "$SHARED_REL/tarefas" 2>/dev/null \
      | { grep '/CARTAO\.md$' || true; } | while IFS= read -r path; do
        git -C "$ROOT" show "$ref:$path" 2>/dev/null | card_row "$ref" || true
      done
  done
  return 0
}

cmd_list() {
  local remote=0 rows
  [[ "${1:-}" == "--remote" ]] && remote=1
  rows="$(mktemp)"
  local_rows >"$rows"
  [[ "$remote" == 1 ]] && remote_rows >>"$rows"
  if [[ "$(mode)" == shared ]]; then
    echo "Quadro compartilhado ($(board_dir))"
  else
    echo "Quadro local, fora do git ($(board_dir))"
  fi
  if [[ ! -s "$rows" ]]; then
    echo "  nenhuma tarefa no quadro"
    rm -f "$rows"
    return 0
  fi
  # Dedup by id: the local copy wins; among remote copies, the newest update wins.
  awk -F'\t' -v order="$STATUSES" '
    {
      id = $1
      if (!(id in row)) { row[id] = $0; up[id] = $6; src[id] = $7; ids[++n] = id; next }
      if (src[id] == "local") next
      if ($7 == "local" || $6 > up[id]) { row[id] = $0; up[id] = $6; src[id] = $7 }
    }
    END {
      k = split("em-andamento em-revisao bloqueada pronto refinando concluida cancelada", seq, " ")
      for (s = 1; s <= k; s++) {
        printed = 0
        for (i = 1; i <= n; i++) {
          split(row[ids[i]], c, "\t")
          if (c[2] != seq[s]) continue
          if (!printed) { printf "\n%s\n", toupper(seq[s]); printed = 1 }
          where = (c[7] == "local") ? "" : "  [" c[7] "]"
          printf "  %s  %s — %s (%s) · atualizado %s%s\n", c[1], c[3], c[4], c[5], c[6], where
        }
      }
      for (i = 1; i <= n; i++) {
        split(row[ids[i]], c, "\t")
        if (index(" " order " ", " " c[2] " ") == 0) printf "\n?? status desconhecido: %s (%s)\n", c[1], c[2]
      }
    }
  ' "$rows"
  rm -f "$rows"
}

cmd_related() {
  local except="" f p hits st id title owner br found=0
  if [[ "${1:-}" == "--except" ]]; then
    except="${2:?--except requires an id}"
    shift 2
  fi
  [[ $# -ge 1 ]] || usage
  for f in "$(board_dir)"/tarefas/*/CARTAO.md; do
    [[ -f "$f" ]] || continue
    [[ -n "$except" && "$(basename "$(dirname "$f")")" == "$except" ]] && continue
    hits=""
    for p in "$@"; do
      if awk '/^## Onde[ \t]*$/{s=1; next} /^## /{s=0} s' "$f" | grep -qF -- "$p"; then
        hits="$hits $p"
      fi
    done
    [[ -n "$hits" ]] || continue
    found=1
    IFS=$'\t' read -r id st title owner br _ _ < <(card_row local <"$f")
    if [[ "$st" == em-andamento || "$st" == em-revisao ]]; then
      echo "CONFLITO  $id  $title — $owner ($br) está com status $st e toca:$hits"
    else
      echo "RELACIONADA  $id  $title — $st — toca:$hits"
    fi
  done
  [[ "$found" == 1 ]] || echo "nenhuma tarefa relacionada"
}

cmd_share() {
  if [[ "$(mode)" == shared ]]; then
    echo "o quadro já está compartilhado em $SHARED_DIR"
    return 0
  fi
  if [[ -d "$LOCAL_DIR" ]]; then
    mv "$LOCAL_DIR" "$SHARED_DIR"
  fi
  mkdir -p "$SHARED_DIR/tarefas"
  cat >"$SHARED_DIR/README.md" <<'EOF'
# Quadro de tarefas compartilhado

Cada pasta em `tarefas/` é uma tarefa: `CARTAO.md` diz o status (refinando,
pronto, em-andamento, em-revisao, bloqueada, concluida, cancelada), quem está
com ela, em qual branch, onde mexe e o histórico. `refinamento.html` (abra no
navegador) é o documento de refinamento: o quê, onde, por quê e as dúvidas
respondidas antes do desenvolvimento.

Ver o quadro inteiro, inclusive o que outros devs já subiram em branches
ainda não mergeadas: `bash .agents/scripts/board.sh list --remote`.

Nada aqui pode conter segredo, token, dado pessoal ou URL interna sensível:
esta pasta vai para o repositório.
EOF
  echo "quadro compartilhado em $SHARED_DIR — revise o conteúdo e commite quando quiser"
  echo "AVISO: tudo em $SHARED_REL/ passa a ser versionável; não grave segredos nos cartões"
}

cmd_unshare() {
  if [[ "$(mode)" == local ]]; then
    echo "o quadro já é local em $LOCAL_DIR"
    return 0
  fi
  [[ -e "$LOCAL_DIR" ]] && die "já existe $LOCAL_DIR — mova-o antes de descompartilhar"
  mkdir -p "$ROOT/.agents"
  mv "$SHARED_DIR" "$LOCAL_DIR"
  rm -f "$LOCAL_DIR/README.md"
  echo "quadro movido para $LOCAL_DIR (local)"
  if git -C "$ROOT" ls-files --error-unmatch "$SHARED_REL" >/dev/null 2>&1; then
    echo "AVISO: $SHARED_REL/ já estava commitado; remova-o do histórico com 'git rm -r --cached $SHARED_REL' se for o caso"
  fi
}

cmd="${1:-}"
[[ -n "$cmd" ]] || usage
shift
case "$cmd" in
  where) cmd_where ;;
  new) cmd_new "$@" ;;
  set) cmd_set "$@" ;;
  log) cmd_log "$@" ;;
  attach) cmd_attach "$@" ;;
  show) cmd_show "$@" ;;
  list) cmd_list "$@" ;;
  related) cmd_related "$@" ;;
  share) cmd_share ;;
  unshare) cmd_unshare ;;
  -h|--help|help) usage ;;
  *) usage ;;
esac
