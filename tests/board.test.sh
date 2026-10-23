#!/usr/bin/env bash
# board.test.sh — contract of agentes/scripts/board.sh (task board, decentralized
# context): cards, status validation, local vs shared mode, related/conflict
# detection, and reading cards that other devs pushed to remote branches.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD="$ROOT/agentes/scripts/board.sh"
fail=0
pass() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Isolate from the machine's git config (signing, push negotiation, default branch).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

new_repo() {
  local dir="$1" name="$2"
  git -c init.defaultBranch=main init -q "$dir"
  git -C "$dir" config user.name "$name"
  git -C "$dir" config user.email "$name@example.com"
  git -C "$dir" config commit.gpgsign false
}

A="$TMP/a"
new_repo "$A" "Dev A"
echo x >"$A/f"
git -C "$A" add f
git -C "$A" commit -qm init
b() { bash "$BOARD" --root "$A" "$@"; }

# --- local mode by default, inside the gitignored .agents/ ---
[[ "$(b where)" == "local $A/.agents/quadro" ]] && pass "modo local por padrão em .agents/quadro" || bad "where: $(b where)"

id="$(b new "Login Google!" "Login com Google")"
[[ "$id" == "$(date '+%Y%m%d')-login-google" ]] && pass "id = data + slug normalizado" || bad "id inesperado: $id"
card="$A/.agents/quadro/tarefas/$id/CARTAO.md"
[[ -f "$card" ]] && pass "cartão criado" || bad "cartão não criado"
grep -qx 'Status: refinando' "$card" && pass "status inicial refinando" || bad "status inicial"
grep -qx 'Responsável: Dev A' "$card" && pass "responsável = git user.name" || bad "responsável"

id2="$(b new "Login Google" "Outra tarefa")"
[[ "$id2" == "$id-2" ]] && pass "colisão de id ganha sufixo, sem contador central" || bad "colisão: $id2"

# --- set / log ---
b set "$id" Status em-andamento
grep -qx 'Status: em-andamento' "$card" && pass "set Status" || bad "set Status"
grep -q 'status: em-andamento' "$card" && pass "mudança de status vai para o log" || bad "log do status"
if b set "$id" Status quase-pronto 2>/dev/null; then bad "status inválido aceito"; else pass "status inválido recusado"; fi
if b set "$id" Criado ontem 2>/dev/null; then bad "campo não editável aceito"; else pass "campo fora da lista recusado"; fi
b log "$id" "fase 1 concluída"
awk '/^## Log/{f=1;next} /^## /{f=0} f' "$card" | tail -1 | grep -q 'Dev A — fase 1 concluída' \
  && pass "log anexa no fim da seção Log" || bad "log fora do lugar"
[[ "$(grep -c '^ID:' "$card")" == 1 ]] && pass "cabeçalho sem campo duplicado" || bad "campo duplicado"

# --- attach ---
echo plan >"$TMP/06-tl.md"
b attach "$id" "$TMP/06-tl.md"
[[ -f "$A/.agents/quadro/tarefas/$id/planejamento/06-tl.md" ]] && pass "attach copia para planejamento/" || bad "attach"

# --- related / conflict (the "Onde" section is the decentralized index) ---
awk '/^## Onde/{print; print "- `src/auth/google.ts` — criar"; skip=1; next} /^## /{skip=0} !skip' "$card" >"$TMP/c" && cat "$TMP/c" >"$card"
out="$(b related src/auth)"
grep -q "^CONFLITO  $id " <<<"$out" && pass "related acusa conflito com tarefa em andamento" || bad "related: $out"
out="$(b related --except "$id" src/auth)"
[[ "$out" == "nenhuma tarefa relacionada" ]] && pass "related --except ignora a própria tarefa" || bad "related --except: $out"
b set "$id" Status concluida
grep -q "^RELACIONADA  $id " <<<"$(b related src/auth)" && pass "tarefa concluída aparece como relacionada" || bad "relacionada"

# --- list ---
out="$(b list)"
grep -q '^CONCLUIDA' <<<"$out" && grep -q '^REFINANDO' <<<"$out" && pass "list agrupa por status" || bad "list: $out"
grep -q 'Quadro local, fora do git' <<<"$out" && pass "list diz que o quadro é local" || bad "cabeçalho do list"

# --- local board is invisible to git (lives under .agents/) ---
printf '.agents/\n' >"$A/.gitignore"
[[ -z "$(git -C "$A" status --porcelain -- .agents)" ]] && pass "quadro local fica fora do git" || bad "quadro local aparece no git"

# --- share: opt-in, moves the board to a versionable folder ---
b share >/dev/null
[[ "$(b where)" == "shared $A/.agents-shared" ]] && pass "share muda para .agents-shared" || bad "share: $(b where)"
[[ -f "$A/.agents-shared/tarefas/$id/CARTAO.md" && ! -e "$A/.agents/quadro" ]] && pass "share move os cartões (sem cópia duplicada)" || bad "share não moveu"
[[ -f "$A/.agents-shared/README.md" ]] && pass "share cria README para quem não usa o pipeline" || bad "README ausente"
git -C "$A" status --porcelain | grep -q '.agents-shared/' && pass "quadro compartilhado fica visível ao git" || bad "pasta compartilhada invisível ao git"
[[ -z "$(git -C "$A" diff --cached --name-only)" ]] && pass "share não faz git add (commit é decisão do usuário)" || bad "share mexeu no index"

# --- remote branches: what other devs pushed but did not merge ---
REMOTE="$TMP/remote.git"
git -c init.defaultBranch=main init -q --bare "$REMOTE"
git -C "$A" add -A
git -C "$A" commit -qm "share board"
git -C "$A" remote add origin "$REMOTE"
git -C "$A" push -q origin main

B="$TMP/b"
git clone -q "$REMOTE" "$B"
git -C "$B" config user.name "Dev B"
git -C "$B" config user.email "b@example.com"
git -C "$B" config commit.gpgsign false
git -C "$B" checkout -q -b feat/pagamento
idb="$(bash "$BOARD" --root "$B" new pagamento "Pagamento com Pix")"
bash "$BOARD" --root "$B" set "$idb" Status em-andamento
git -C "$B" add -A
git -C "$B" commit -qm "card"
git -C "$B" push -q origin feat/pagamento

git -C "$A" fetch -q origin
out="$(b list)"
grep -q "$idb" <<<"$out" && bad "list sem --remote não deveria ler branches remotas" || pass "list sem --remote fica no working tree"
out="$(b list --remote)"
grep -q "$idb  Pagamento com Pix — Dev B (feat/pagamento)" <<<"$out" && pass "list --remote mostra tarefa em andamento de outro dev" || bad "list --remote: $out"
grep -q "\[origin/feat/pagamento\]" <<<"$out" && pass "list --remote diz de qual branch veio" || bad "origem remota ausente"
[[ "$(grep -c "  $id " <<<"$out")" == 1 ]] && pass "cartão local e remoto com o mesmo id aparece uma vez" || bad "dedup: $out"

# --- unshare ---
b unshare >/dev/null
[[ "$(b where)" == "local $A/.agents/quadro" && -f "$A/.agents/quadro/tarefas/$id/CARTAO.md" ]] && pass "unshare volta para local" || bad "unshare"

exit $fail
