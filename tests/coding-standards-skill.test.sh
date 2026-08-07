#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
  fi
}

check "$ROOT/skills/coding-standards/SKILL.md" '^name: coding-standards' "SKILL.md tem frontmatter name correto"
check "$ROOT/skills/coding-standards/SKILL.md" 'always written in English' "SKILL.md exige código sempre em inglês"

check "$ROOT/claude/skills/init-project/SKILL.md" 'SKILLS_DIR' "init-project resolve SKILLS_DIR"
check "$ROOT/claude/skills/init-project/SKILL.md" '\.claude/skills/coding-standards' "init-project instala coding-standards em .claude/skills/"

check "$ROOT/scripts/init-manifest-diff.sh" 'template_skills_dir' "init-manifest-diff.sh documenta o 4º argumento"
check "$ROOT/scripts/init-manifest-diff.sh" 'template_skills="\$4"' "cmd_apply recebe template_skills"

check "$ROOT/README.md" 'coding-standards/SKILL.md' "README documenta a pasta skills/ na estrutura do repo"

# Instala num diretório temporário e roda generate/apply de ponta a ponta
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.agents" "$TMP/.claude/commands" "$TMP/.claude/skills"
cp "$ROOT"/agentes/*.md "$TMP/.agents/"
cp -R "$ROOT"/agentes/scripts "$TMP/.agents/" 2>/dev/null || true
cp "$ROOT"/commands/*.md "$TMP/.claude/commands/"
cp -R "$ROOT"/skills/coding-standards "$TMP/.claude/skills/"

if bash "$ROOT/scripts/init-manifest-diff.sh" generate "$TMP" "$ROOT/agentes" "$ROOT/commands" "$ROOT/skills" \
  && grep -q '.claude/skills/coding-standards/SKILL.md' "$TMP/.agents/.init-manifest.json"; then
  echo "PASS: manifesto rastreia .claude/skills/coding-standards/SKILL.md"
else
  echo "FAIL: manifesto não rastreou a skill coding-standards"
  fail=1
fi

if bash "$ROOT/scripts/init-manifest-diff.sh" apply "$TMP" "$ROOT/agentes" "$ROOT/commands" "$ROOT/skills" \
  | grep -q 'CONFLICTS=0'; then
  echo "PASS: apply sem mudanças não gera conflito na skill"
else
  echo "FAIL: apply gerou conflito inesperado"
  fail=1
fi

exit $fail
