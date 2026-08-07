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

exit $fail
