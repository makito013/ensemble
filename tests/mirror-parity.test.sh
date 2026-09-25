#!/usr/bin/env bash
# Mirrored copies must stay byte-identical:
#   commands/*.md                  <-> .claude/commands/*.md (files present in both)
#   skills/coding-standards/SKILL.md <-> .claude/skills/coding-standards/SKILL.md
# commands/ and skills/ are the templates installed in projects; .claude/ is
# the copy this repo uses for itself. Drift means one side was edited alone.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
compared=0

compare() {
  local source="$1" mirror="$2"
  compared=$((compared + 1))
  if cmp -s "$ROOT/$source" "$ROOT/$mirror"; then
    echo "PASS: $mirror == $source"
  else
    echo "FAIL: $mirror diverge de $source"
    diff -u "$ROOT/$source" "$ROOT/$mirror" | head -20 || true
    fail=1
  fi
}

for source in "$ROOT"/commands/*.md; do
  name="$(basename "$source")"
  [[ -f "$ROOT/.claude/commands/$name" ]] || continue
  compare "commands/$name" ".claude/commands/$name"
done

if [[ -f "$ROOT/skills/coding-standards/SKILL.md" && -f "$ROOT/.claude/skills/coding-standards/SKILL.md" ]]; then
  compare "skills/coding-standards/SKILL.md" ".claude/skills/coding-standards/SKILL.md"
else
  echo "FAIL: skills/coding-standards/SKILL.md ou seu espelho em .claude/skills/ não existe"
  fail=1
fi

if [[ "$compared" -lt 2 ]]; then
  echo "FAIL: nenhum par de comandos espelhados encontrado (esperado ao menos 1)"
  fail=1
fi

exit $fail
