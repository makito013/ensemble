#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/init-manifest-diff.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

TPL_A="$FIXTURE/template/agentes"
TPL_C="$FIXTURE/template/commands"
TPL_S="$FIXTURE/template/skills"
PROJ="$FIXTURE/project"
mkdir -p "$TPL_A" "$TPL_C" "$TPL_S" "$PROJ/.agents" "$PROJ/.claude/commands"

# --- Round 1: instalação inicial idêntica ao template ---
echo "conteudo A v1" > "$TPL_A/A.md"
echo "conteudo B v1" > "$TPL_A/B.md"
echo "conteudo D v1" > "$TPL_A/D.md"
echo "conteudo C v1" > "$TPL_C/C.md"
mkdir -p "$TPL_A/scripts" "$PROJ/.agents/scripts"
echo "script v1" > "$TPL_A/scripts/detect-projects.sh"

cp "$TPL_A/A.md" "$PROJ/.agents/A.md"
cp "$TPL_A/B.md" "$PROJ/.agents/B.md"
cp "$TPL_A/D.md" "$PROJ/.agents/D.md"
cp "$TPL_C/C.md" "$PROJ/.claude/commands/C.md"
cp "$TPL_A/scripts/detect-projects.sh" "$PROJ/.agents/scripts/detect-projects.sh"

bash "$TOOL" generate "$PROJ" "$TPL_A" "$TPL_C" "$TPL_S"

fail=0
if [[ -f "$PROJ/.agents/.init-manifest.json" ]]; then
  echo "PASS: generate cria .init-manifest.json"
else
  echo "FAIL: .init-manifest.json não foi criado"
  fail=1
fi
if grep -q '.agents/A.md' "$PROJ/.agents/.init-manifest.json"; then
  echo "PASS: manifesto registra .agents/A.md"
else
  echo "FAIL: manifesto não registra .agents/A.md"
  fail=1
fi

# --- Round 2: simula mudanças antes do --update ---
echo "conteudo A v2" > "$TPL_A/A.md"                 # template mudou, local intocado -> OVERWRITE
echo "conteudo B CUSTOM" > "$PROJ/.agents/B.md"       # local mudou, template intocado -> PRESERVE
echo "conteudo D v2" > "$TPL_A/D.md"                  # os dois mudaram -> CONFLICT
echo "conteudo D CUSTOM" > "$PROJ/.agents/D.md"
echo "conteudo E v1" > "$TPL_A/E.md"                  # novo arquivo no template -> INSTALL
echo "script v2 (bugfix)" > "$TPL_A/scripts/detect-projects.sh"  # script mudou, local intocado -> OVERWRITE

summary="$(bash "$TOOL" apply "$PROJ" "$TPL_A" "$TPL_C" "$TPL_S")"
echo "$summary"

check_content() {
  local file="$1" expected="$2" label="$3"
  local actual
  actual="$(cat "$file" 2>/dev/null || echo '<ausente>')"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — esperado '$expected', obtido '$actual'"
    fail=1
  fi
}

check_content "$PROJ/.agents/A.md" "conteudo A v2" "A.md foi sobrescrito (OVERWRITE)"
check_content "$PROJ/.agents/B.md" "conteudo B CUSTOM" "B.md foi preservado (PRESERVE)"
check_content "$PROJ/.agents/D.md" "conteudo D CUSTOM" "D.md local preservado apesar do conflito"
check_content "$PROJ/.agents/D.md.new" "conteudo D v2" "D.md.new contém a versão nova do template (CONFLICT)"
check_content "$PROJ/.agents/E.md" "conteudo E v1" "E.md foi instalado (INSTALL)"
check_content "$PROJ/.agents/scripts/detect-projects.sh" "script v2 (bugfix)" "detect-projects.sh (.sh, não .md) também é rastreado e sobrescrito"

if echo "$summary" | grep -q 'INSTALLED=1 OVERWRITTEN=3 PRESERVED=1 CONFLICTS=1'; then
  echo "PASS: resumo bate (1 install, 3 overwrite [A+C+script], 1 preserve, 1 conflict)"
else
  echo "FAIL: resumo não bate: $summary"
  fail=1
fi
if echo "$summary" | grep -q 'CONFLICT: .agents/D.md.new'; then
  echo "PASS: resumo lista o conflito de D.md"
else
  echo "FAIL: resumo não lista o conflito de D.md"
  fail=1
fi

# --- Round 3: sem manifesto -> pede reinstalação completa ---
PROJ2="$FIXTURE/project-sem-manifesto"
mkdir -p "$PROJ2/.agents"
set +e
out2="$(bash "$TOOL" apply "$PROJ2" "$TPL_A" "$TPL_C" "$TPL_S")"
code2=$?
set -e
if [[ "$code2" -eq 2 && "$out2" == "NEED_FULL_REINSTALL" ]]; then
  echo "PASS: sem manifesto, apply pede reinstalação completa (exit 2)"
else
  echo "FAIL: esperado exit 2 + NEED_FULL_REINSTALL, obtido exit=$code2 saida='$out2'"
  fail=1
fi

# --- Round 4: customização sobrevive a um SEGUNDO --update (regressão do
# bug crítico: manifesto não pode rebasear a partir do hash local) ---
PROJ3="$FIXTURE/project-segunda-rodada"
TPL_A3="$FIXTURE/template-segunda-rodada/agentes"
TPL_C3="$FIXTURE/template-segunda-rodada/commands"
TPL_S3="$FIXTURE/template-segunda-rodada/skills"
mkdir -p "$PROJ3/.agents" "$PROJ3/.claude/commands" "$TPL_A3" "$TPL_C3" "$TPL_S3"

echo "conteudo B v1" > "$TPL_A3/B.md"
cp "$TPL_A3/B.md" "$PROJ3/.agents/B.md"
bash "$TOOL" generate "$PROJ3" "$TPL_A3" "$TPL_C3" "$TPL_S3"

echo "conteudo B CUSTOM" > "$PROJ3/.agents/B.md"
bash "$TOOL" apply "$PROJ3" "$TPL_A3" "$TPL_C3" "$TPL_S3" > /dev/null

echo "conteudo B v2" > "$TPL_A3/B.md"
bash "$TOOL" apply "$PROJ3" "$TPL_A3" "$TPL_C3" "$TPL_S3" > /dev/null

final_content="$(cat "$PROJ3/.agents/B.md")"
if [[ "$final_content" == "conteudo B CUSTOM" ]]; then
  echo "PASS: customização sobrevive a um segundo --update (regressão do bug de rebase pelo hash local)"
else
  echo "FAIL: customização foi perdida no segundo --update! conteúdo final: $final_content"
  fail=1
fi

# --- Round 5: backup + install (full reinstall without --update) keep project
# data in place, back up outside .agents/ and never ship test files ---
PROJ5="$FIXTURE/project-reinstall"
TPL_A5="$FIXTURE/template-reinstall/agentes"
TPL_C5="$FIXTURE/template-reinstall/commands"
TPL_S5="$FIXTURE/template-reinstall/skills"
mkdir -p "$TPL_A5/scripts" "$TPL_C5" "$TPL_S5/coding-standards"
echo "persona v2" > "$TPL_A5/DEV.md"
echo "pipeline v2" > "$TPL_A5/PIPELINE.md"
echo "detect v2" > "$TPL_A5/scripts/detect-projects.sh"
echo "snapshot v2" > "$TPL_A5/scripts/design-snapshot.mjs"
echo "test" > "$TPL_A5/scripts/detect-projects.test.sh"
echo "cmd v2" > "$TPL_C5/orquestrador.md"
echo "test" > "$TPL_C5/commands.test.sh"
echo "skill v2" > "$TPL_S5/coding-standards/SKILL.md"

mkdir -p "$PROJ5/.agents/.pipeline-history" "$PROJ5/.agents/design-system/surpresa" \
  "$PROJ5/.agents/planos" "$PROJ5/.agents/skills/dev" "$PROJ5/.agents/.backup-20200101-000000" \
  "$PROJ5/.claude/commands" "$PROJ5/.claude/skills/coding-standards" "$PROJ5/.claude/skills/other"
echo "persona v1 + learned rule" > "$PROJ5/.agents/DEV.md"
echo "pipeline v1" > "$PROJ5/.agents/PIPELINE.md"
echo "state" > "$PROJ5/.agents/PIPELINE-STATE.md"
echo "history" > "$PROJ5/.agents/.pipeline-history/run-1.md"
echo "design state" > "$PROJ5/.agents/DESIGN-STATE.md"
echo "tokens" > "$PROJ5/.agents/design-system/surpresa/tokens.json"
echo "plan" > "$PROJ5/.agents/planos/plan-1.md"
echo "ctx" > "$PROJ5/.agents/CONTEXTO.md"
echo "gemini skill" > "$PROJ5/.agents/skills/dev/SKILL.md"
echo "legacy" > "$PROJ5/.agents/.backup-20200101-000000/DEV.md"
echo "cmd v1" > "$PROJ5/.claude/commands/orquestrador.md"
echo "user cmd" > "$PROJ5/.claude/commands/mine.md"
echo "skill v1" > "$PROJ5/.claude/skills/coding-standards/SKILL.md"
echo "user skill" > "$PROJ5/.claude/skills/other/SKILL.md"

backup_out="$(bash "$TOOL" backup "$PROJ5" "$TPL_A5" "$TPL_C5" "$TPL_S5" 20260101-120000)"
install_out="$(bash "$TOOL" install "$PROJ5" "$TPL_A5" "$TPL_C5" "$TPL_S5")"
BK="$PROJ5/.agents-backups/20260101-120000"

expect_line() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s\n' "$haystack" | grep -qx -- "$needle"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — saída: $haystack"
    fail=1
  fi
}
expect_absent() {
  local path="$1" label="$2"
  if [[ -e "$path" ]]; then
    echo "FAIL: $label — $path existe"
    fail=1
  else
    echo "PASS: $label"
  fi
}

expect_line "$backup_out" "BACKUP=.agents-backups/20260101-120000" "backup reporta caminho fora de .agents/"
expect_line "$backup_out" "LEGACY_BACKUPS=1" "backup conta os .backup-* legados"
expect_line "$install_out" "INSTALLED=6" "install instala só os 6 arquivos de template (sem *.test.*)"
check_content "$BK/.agents/DEV.md" "persona v1 + learned rule" "backup guarda a persona antiga (para restaurar ## Aprendizados)"
check_content "$BK/.agents/PIPELINE-STATE.md" "state" "backup copia PIPELINE-STATE.md"
check_content "$BK/.agents/design-system/surpresa/tokens.json" "tokens" "backup copia design-system/ recursivamente"
check_content "$BK/.claude/commands/orquestrador.md" "cmd v1" "backup copia comandos de template que serão sobrescritos"
expect_absent "$BK/.agents/.backup-20200101-000000" "backup não aninha .backup-* legados"
new_inner="$(find "$PROJ5/.agents" -maxdepth 1 -name '.backup-*' ! -name '.backup-20200101-000000' | wc -l | tr -d ' ')"
if [[ "$new_inner" == "0" ]]; then
  echo "PASS: nenhum backup novo criado dentro de .agents/"
else
  echo "FAIL: backup novo criado dentro de .agents/"
  fail=1
fi
check_content "$PROJ5/.agents/.backup-20200101-000000/DEV.md" "legacy" ".backup-* legado continua no lugar"
check_content "$PROJ5/.agents/DEV.md" "persona v2" "persona de template sobrescrita"
check_content "$PROJ5/.agents/PIPELINE.md" "pipeline v2" "PIPELINE.md sobrescrito"
check_content "$PROJ5/.agents/scripts/design-snapshot.mjs" "snapshot v2" "scripts não-.sh também são template"
check_content "$PROJ5/.agents/PIPELINE-STATE.md" "state" "PIPELINE-STATE.md preservado no lugar"
check_content "$PROJ5/.agents/.pipeline-history/run-1.md" "history" ".pipeline-history/ preservado"
check_content "$PROJ5/.agents/DESIGN-STATE.md" "design state" "DESIGN-STATE.md preservado"
check_content "$PROJ5/.agents/design-system/surpresa/tokens.json" "tokens" "design-system/ preservado"
check_content "$PROJ5/.agents/planos/plan-1.md" "plan" "planos/ preservado"
check_content "$PROJ5/.agents/CONTEXTO.md" "ctx" "CONTEXTO.md preservado"
check_content "$PROJ5/.agents/skills/dev/SKILL.md" "gemini skill" "skills/ do Gemini preservado"
check_content "$PROJ5/.claude/commands/mine.md" "user cmd" "comando do usuário intocado"
check_content "$PROJ5/.claude/skills/other/SKILL.md" "user skill" "skill do usuário intocada"
check_content "$PROJ5/.claude/commands/orquestrador.md" "cmd v2" "comando de template sobrescrito"
check_content "$PROJ5/.claude/skills/coding-standards/SKILL.md" "skill v2" "coding-standards sobrescrita"
expect_absent "$PROJ5/.claude/commands/commands.test.sh" "*.test.sh de commands/ não é copiado"
expect_absent "$PROJ5/.agents/scripts/detect-projects.test.sh" "*.test.sh de agentes/scripts/ não é copiado"
if grep -q 'test\.sh' "$PROJ5/.agents/.init-manifest.json"; then
  echo "FAIL: manifesto rastreia arquivo de teste"
  fail=1
else
  echo "PASS: manifesto não rastreia arquivos de teste"
fi

# Manifest baseline is the template hash: a persona that got its local
# "## Aprendizados" restored after install is PRESERVED by the next --update.
echo "persona v2 + restored learning" > "$PROJ5/.agents/DEV.md"
upd="$(bash "$TOOL" apply "$PROJ5" "$TPL_A5" "$TPL_C5" "$TPL_S5")"
expect_line "$upd" "INSTALLED=0 OVERWRITTEN=5 PRESERVED=1 CONFLICTS=0" "--update depois de install preserva a persona com aprendizado restaurado"

# A second backup on the same timestamp never overwrites the first one.
backup2="$(bash "$TOOL" backup "$PROJ5" "$TPL_A5" "$TPL_C5" "$TPL_S5" 20260101-120000)"
expect_line "$backup2" "BACKUP=.agents-backups/20260101-120000-2" "backup com timestamp repetido ganha sufixo em vez de sobrescrever"

exit $fail
