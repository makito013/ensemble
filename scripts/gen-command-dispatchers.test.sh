#!/usr/bin/env bash
# gen-command-dispatchers.test.sh — the committed Codex/Cursor command
# dispatchers match what the generator produces, and `check` catches drift.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
GEN="$ROOT/scripts/gen-command-dispatchers.sh"
fail=0
pass() { echo "PASS: $1"; }
failm() { echo "FAIL: $1"; fail=1; }

# 1. Repo is in sync with the generator.
if out="$(bash "$GEN" check "$ROOT")"; then
  pass "dispatchers commitados batem com o gerador ($out)"
else
  failm "dispatchers fora de sincronia — rode 'bash scripts/gen-command-dispatchers.sh generate':"
  echo "$out"
fi

# 2. Every command except the hand-written orquestrador gets both dispatchers.
for f in "$ROOT"/commands/*.md; do
  n="$(basename "$f" .md)"
  [[ "$n" == orquestrador ]] && continue
  [[ -f "$ROOT/codex/skills/$n/SKILL.md" && -f "$ROOT/codex/skills/$n/agents/openai.yaml" ]] \
    && pass "codex/$n gerado" || failm "codex/$n ausente"
  [[ -f "$ROOT/cursor/skills/$n/SKILL.md" ]] \
    && pass "cursor/$n gerado" || failm "cursor/$n ausente"
done

# 3. `check` reports drift on a tampered copy and `generate` repairs it.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/commands" "$tmp/codex/skills" "$tmp/cursor/skills"
cp "$ROOT"/commands/*.md "$tmp/commands/"
bash "$GEN" generate "$tmp" >/dev/null
echo "tampered" >> "$tmp/cursor/skills/time-design/SKILL.md"
rm "$tmp/codex/skills/orquestrador-pr/agents/openai.yaml"
if out="$(bash "$GEN" check "$tmp")"; then
  failm "check não detectou drift num arquivo adulterado"
else
  grep -q '^DRIFT=cursor/skills/time-design/SKILL.md$' <<<"$out" \
    && pass "check detecta SKILL.md adulterado" || failm "check não listou o SKILL.md adulterado"
  grep -q '^DRIFT=codex/skills/orquestrador-pr/agents/openai.yaml$' <<<"$out" \
    && pass "check detecta openai.yaml ausente" || failm "check não listou o openai.yaml ausente"
fi
bash "$GEN" generate "$tmp" >/dev/null
bash "$GEN" check "$tmp" >/dev/null && pass "generate repara o drift" || failm "generate não reparou o drift"
[[ ! -e "$tmp/codex/skills/orquestrador" ]] \
  && pass "orquestrador (escrito à mão) não é gerado" || failm "gerador tocou no orquestrador"

# 4. Bad usage exits 2.
set +e
bash "$GEN" bogus "$ROOT" >/dev/null 2>&1; rc=$?
set -e
[[ "$rc" -eq 2 ]] && pass "modo inválido sai com 2" || failm "modo inválido saiu com $rc"

exit $fail
