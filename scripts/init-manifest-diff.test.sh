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
echo "mjs v1" > "$TPL_A/scripts/design-snapshot.mjs"  # script .mjs novo no template -> INSTALL

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
check_content "$PROJ/.agents/scripts/design-snapshot.mjs" "mjs v1" "design-snapshot.mjs (.mjs) também é rastreado e instalado"

if echo "$summary" | grep -q 'INSTALLED=2 OVERWRITTEN=3 PRESERVED=1 CONFLICTS=1'; then
  echo "PASS: resumo bate (2 install [E+mjs], 3 overwrite [A+C+script], 1 preserve, 1 conflict)"
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

# --- Round 6: local "## Aprendizados" survive --update, full reinstall and
# the Antigravity skills copy (learned rules are project data living inside
# template files).
TPL_A6="$FIXTURE/template6/agentes"
TPL_C6="$FIXTURE/template6/commands"
TPL_S6="$FIXTURE/template6/skills"
TPL_G6="$FIXTURE/template6/gemini-skills"
PROJ6="$FIXTURE/project6"
mkdir -p "$TPL_A6" "$TPL_C6" "$TPL_S6" "$TPL_G6/dev" "$PROJ6"

persona() { # persona <version> [global-rule]
  printf '# DEV\n\ncorpo %s\n\n' "$1"
  if [[ -n "${2:-}" ]]; then printf '## Aprendizados\n- %s\n\n' "$2"; fi
  printf -- '---\n*Ativado como etapa 7.*\n\nModelo: definido pelo Orquestrador (ver `.agents/MODELOS.md`).\n'
}
persona v1 > "$TPL_A6/DEV.md"
persona v1 > "$TPL_A6/QA.md"
persona v1 > "$TPL_A6/REVISOR.md"
printf '# Doc\n\n```markdown\n## Aprendizados\n- <data>: <regra>\n```\n' > "$TPL_A6/APRENDIZADOS.md"
bash "$TOOL" install "$PROJ6" "$TPL_A6" "$TPL_C6" "$TPL_S6" > /dev/null

LOCAL_RULE='2026-09-01: sempre rode o lint antes do commit'
# DEV: only change is a local learning (section created before the final block).
persona v1 "$LOCAL_RULE" > "$PROJ6/.agents/DEV.md"
# QA: local learning + another local customization -> still a conflict.
{ persona v1 "$LOCAL_RULE"; echo "customizacao extra"; } > "$PROJ6/.agents/QA.md"
# REVISOR: learning, but template unchanged -> preserved as is.
persona v1 "$LOCAL_RULE" > "$PROJ6/.agents/REVISOR.md"

# Template evolves: DEV/QA get a new body and DEV already carries a global rule.
persona v2 "2026-01-01: regra global" > "$TPL_A6/DEV.md"
persona v2 > "$TPL_A6/QA.md"
printf '# Doc v2\n\n```markdown\n## Aprendizados\n- <data>: <regra>\n```\n' > "$TPL_A6/APRENDIZADOS.md"

upd6="$(bash "$TOOL" apply "$PROJ6" "$TPL_A6" "$TPL_C6" "$TPL_S6")"
expect_line "$upd6" "INSTALLED=0 OVERWRITTEN=2 PRESERVED=1 CONFLICTS=1" "--update aplica template novo na persona que só tinha aprendizado local"
expect_line "$upd6" "LEARNINGS_CARRIED: .agents/DEV.md" "--update reporta o aprendizado carregado"
expect_line "$upd6" "CONFLICT: .agents/QA.md.new" "persona com outra customização continua em conflito"
expected_dev="$(persona v2 "2026-01-01: regra global"; )"
expected_dev="${expected_dev/regra global/regra global
- $LOCAL_RULE}"
check_content "$PROJ6/.agents/DEV.md" "$expected_dev" "DEV.md: template v2 + regra global + regra local, na mesma seção"
check_content "$PROJ6/.agents/QA.md.new" "$(persona v2 "$LOCAL_RULE")" "QA.md.new já traz o aprendizado local para o merge manual"
check_content "$PROJ6/.agents/REVISOR.md" "$(persona v1 "$LOCAL_RULE")" "REVISOR.md (template inalterado) mantém o aprendizado"
check_content "$PROJ6/.agents/APRENDIZADOS.md" "$(cat "$TPL_A6/APRENDIZADOS.md")" "## Aprendizados dentro de bloco de código não é tratado como seção"

# A second --update with a newer template carries the learning again.
persona v3 "2026-01-01: regra global" > "$TPL_A6/DEV.md"
upd6b="$(bash "$TOOL" apply "$PROJ6" "$TPL_A6" "$TPL_C6" "$TPL_S6")"
expect_line "$upd6b" "LEARNINGS_CARRIED: .agents/DEV.md" "segundo --update carrega o aprendizado de novo"
expected_dev3="${expected_dev/corpo v2/corpo v3}"
check_content "$PROJ6/.agents/DEV.md" "$expected_dev3" "DEV.md no segundo --update: template v3 + regras, sem duplicar"

# Full reinstall: backup + install + restore-learnings.
bk6="$(bash "$TOOL" backup "$PROJ6" "$TPL_A6" "$TPL_C6" "$TPL_S6" 20260202-000000 | sed -n 's/^BACKUP=//p')"
bash "$TOOL" install "$PROJ6" "$TPL_A6" "$TPL_C6" "$TPL_S6" > /dev/null
rest6="$(bash "$TOOL" restore-learnings "$PROJ6" "$bk6")"
expect_line "$rest6" "RESTORED: .agents/DEV.md" "restore-learnings devolve o aprendizado ao DEV.md reinstalado"
expect_line "$rest6" "RESTORED: .agents/REVISOR.md" "restore-learnings devolve o aprendizado ao REVISOR.md reinstalado"
expect_line "$rest6" "RESTORED: .agents/QA.md" "restore-learnings também devolve o aprendizado de persona que estava em conflito"
check_content "$PROJ6/.agents/DEV.md" "$expected_dev3" "DEV.md após reinstalação completa = template + regras"
if grep -q 'APRENDIZADOS.md' <<< "$rest6"; then
  echo "FAIL: restore-learnings tratou exemplo em bloco de código como aprendizado"
  fail=1
else
  echo "PASS: restore-learnings ignora exemplo em bloco de código"
fi
upd6c="$(bash "$TOOL" apply "$PROJ6" "$TPL_A6" "$TPL_C6" "$TPL_S6")"
expect_line "$upd6c" "INSTALLED=0 OVERWRITTEN=1 PRESERVED=3 CONFLICTS=0" "--update depois de restore-learnings preserva as 3 personas com aprendizado"

# Antigravity skills copy: SKILL.md (with frontmatter) keeps local learnings.
skill() { # skill <version> [rule]
  printf -- '---\nname: dev\ndescription: etapa 7\n---\n\n# Dev %s\n\n' "$1"
  if [[ -n "${2:-}" ]]; then printf '## Aprendizados\n- %s\n\n' "$2"; fi
  printf -- '---\n*Etapa 7 do pipeline.*\n'
}
skill v2 > "$TPL_G6/dev/SKILL.md"
skill v1 > "$TPL_G6/qa-SKILL-free.md"
echo "teste" > "$TPL_G6/dev/skill.test.sh"
mkdir -p "$PROJ6/.agents/skills/dev" "$PROJ6/.agents/skills/mine"
skill v1 "$LOCAL_RULE" > "$PROJ6/.agents/skills/dev/SKILL.md"
echo "skill do usuário" > "$PROJ6/.agents/skills/mine/SKILL.md"
cps="$(bash "$TOOL" copy-skills "$TPL_G6" "$PROJ6/.agents/skills")"
expect_line "$cps" "LEARNINGS_CARRIED: dev/SKILL.md" "copy-skills reporta o aprendizado carregado"
check_content "$PROJ6/.agents/skills/dev/SKILL.md" "$(skill v2 "$LOCAL_RULE")" "SKILL.md novo com o aprendizado local antes do bloco final"
check_content "$PROJ6/.agents/skills/qa-SKILL-free.md" "$(skill v1)" "copy-skills copia os demais arquivos"
check_content "$PROJ6/.agents/skills/mine/SKILL.md" "skill do usuário" "copy-skills não toca skill que só existe no destino"
expect_absent "$PROJ6/.agents/skills/dev/skill.test.sh" "copy-skills não copia arquivos de teste"
PERM6="$(ls -l "$PROJ6/.agents/DEV.md" | cut -c1-10)"
if [[ "$PERM6" == "-rw-------" ]]; then
  echo "FAIL: persona com aprendizado carregado ficou com permissão 0600"
  fail=1
else
  echo "PASS: persona com aprendizado carregado mantém permissão normal ($PERM6)"
fi
ln -s "$TPL_G6" "$FIXTURE/skills-link"
cps2="$(bash "$TOOL" copy-skills "$TPL_G6" "$FIXTURE/skills-link")"
expect_line "$cps2" "SAME_DIR: $FIXTURE/skills-link" "copy-skills não falha quando o destino é symlink para a origem"
ln -s "$TPL_G6" "$FIXTURE/src-link"
mkdir -p "$FIXTURE/dest7"
bash "$TOOL" copy-skills "$FIXTURE/src-link" "$FIXTURE/dest7" > /dev/null
check_content "$FIXTURE/dest7/dev/SKILL.md" "$(skill v2)" "copy-skills segue origem que é symlink"

exit $fail
