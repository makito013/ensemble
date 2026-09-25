#!/usr/bin/env bash
# gen-command-dispatchers.sh — generates the thin Codex/Cursor dispatchers for
# every Claude command in commands/*.md.
#
# Each dispatcher only tells the engine to read the installed
# `.claude/commands/<name>.md` (single source, installed by init-project for
# every AI) and follow it. Implicit invocation is always locked:
#   - Codex:  codex/skills/<name>/agents/openai.yaml -> allow_implicit_invocation: false
#   - Cursor: cursor/skills/<name>/SKILL.md          -> disable-model-invocation: true
#
# `orquestrador` is excluded: its dispatchers are hand-written because they
# load the persona files directly instead of a command file.
#
# Usage:
#   bash scripts/gen-command-dispatchers.sh generate [repo_root]
#   bash scripts/gen-command-dispatchers.sh check    [repo_root]   (exit 1 on drift)
set -euo pipefail

MODE="${1:-}"
ROOT="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
EXCLUDED=(orquestrador)

usage() { echo "usage: $0 generate|check [repo_root]" >&2; exit 2; }
[[ "$MODE" == generate || "$MODE" == check ]] || usage
[[ -d "$ROOT/commands" ]] || { echo "commands/ not found under $ROOT" >&2; exit 2; }

is_excluded() {
  local n="$1" e
  for e in "${EXCLUDED[@]}"; do [[ "$n" == "$e" ]] && return 0; done
  return 1
}

description_of() {
  # First `description:` line inside the leading YAML frontmatter.
  awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {exit} fm && sub(/^description: /, "") {print; exit}' "$1"
}

emit_codex_skill() {
  local n="$1" desc="$2"
  cat <<EOF
---
name: $n
description: $desc Gatilho sempre manual, nunca automático.
---

# $n

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
\`.claude/commands/$n.md\`, na raiz deste projeto — instalado pelo
\`init-project\` para qualquer IA e fonte única, compartilhada por todas.

Invocação explícita apenas: \`agents/openai.yaml\` desta skill declara
\`policy.allow_implicit_invocation: false\`, então ela nunca é injetada no
contexto por relevância. Só roda quando chamada por \`\$$n\`.

## O que fazer

1. Leia integralmente \`.claude/commands/$n.md\`. Ignore o frontmatter YAML
   (\`description\`, \`argument-hint\`, \`model\`): é metadado do Claude Code.
2. Siga as instruções do corpo desse arquivo, tratando cada \`\$ARGUMENTS\`
   como o texto que o usuário passou junto com a invocação (vazio se ele não
   passou nada).
3. Onde o arquivo citar um comando do Claude Code (\`/orquestrador\`,
   \`/init-project\`, \`/$n\` …), o equivalente aqui é a skill de mesmo nome
   invocada com \`\$\` (\`\$orquestrador\`, \`\$init-project\`, \`\$$n\` …).

Se \`.claude/commands/$n.md\` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode \`\$init-project\`
antes).
EOF
}

emit_codex_yaml() {
  cat <<'EOF'
policy:
  allow_implicit_invocation: false
EOF
}

emit_cursor_skill() {
  local n="$1" desc="$2"
  cat <<EOF
---
name: $n
description: $desc Gatilho sempre manual, nunca automático.
disable-model-invocation: true
---

# $n

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
\`.claude/commands/$n.md\`, na raiz deste projeto — instalado pelo
\`init-project\` para qualquer IA e fonte única, compartilhada por todas.

\`disable-model-invocation: true\` no frontmatter é intencional: esta skill nunca
dispara sozinha por relevância de contexto. Ela aparece na lista de \`/\` e só
roda quando o usuário a chama pelo nome (\`/$n\`).

## O que fazer

1. Leia integralmente \`.claude/commands/$n.md\`. Ignore o frontmatter YAML
   (\`description\`, \`argument-hint\`, \`model\`): é metadado do Claude Code.
2. Siga as instruções do corpo desse arquivo, tratando cada \`\$ARGUMENTS\`
   como o texto que o usuário passou junto com o comando (vazio se ele não
   passou nada).
3. Onde o arquivo citar outro comando (\`/orquestrador\`, \`/init-project\` …),
   o equivalente aqui é a skill de mesmo nome na lista de \`/\`.

Se \`.claude/commands/$n.md\` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode \`init-project\`
antes).
EOF
}

# Writes every generated file under $1 (a repo root or a scratch dir).
generate_into() {
  local out="$1" f n desc
  for f in "$ROOT"/commands/*.md; do
    n="$(basename "$f" .md)"
    is_excluded "$n" && continue
    desc="$(description_of "$f")"
    [[ -n "$desc" ]] || { echo "no description in $f" >&2; exit 2; }
    mkdir -p "$out/codex/skills/$n/agents" "$out/cursor/skills/$n"
    emit_codex_skill "$n" "$desc" > "$out/codex/skills/$n/SKILL.md"
    emit_codex_yaml > "$out/codex/skills/$n/agents/openai.yaml"
    emit_cursor_skill "$n" "$desc" > "$out/cursor/skills/$n/SKILL.md"
  done
}

if [[ "$MODE" == generate ]]; then
  generate_into "$ROOT"
  echo "GENERATED"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
generate_into "$tmp"
drift=0
while IFS= read -r rel; do
  if ! cmp -s "$tmp/$rel" "$ROOT/$rel" 2>/dev/null; then
    echo "DRIFT=$rel"
    drift=1
  fi
done < <(cd "$tmp" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
[[ "$drift" -eq 0 ]] && echo "IN_SYNC"
exit "$drift"
