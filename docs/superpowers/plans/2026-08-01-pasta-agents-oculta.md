# Pasta instalada oculta (`agentes/` → `.agents/`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer o `/init-project` instalar em `./.agents/` (oculta) em vez de `./agentes/` (visível), unificando com a pasta que o lado Gemini/Antigravity já usa, com migração automática de instalações antigas e entrada automática no `.gitignore` quando já existir um.

**Architecture:** Renomeação do caminho de destino em todos os arquivos que hoje instruem/testam onde o pipeline é instalado dentro do projeto do usuário (`claude/skills/init-project/SKILL.md`, `scripts/init-manifest-diff.sh`, o conteúdo runtime de `agentes/ORQUESTRADOR.md` e `agentes/PIPELINE.md`, `commands/orquestrador*.md`, `gemini/skills/orquestrador*/SKILL.md`), mais lógica nova de migração (detecção + rename + reescrita de chaves do manifest) e automação de `.gitignore` dentro do `init-project/SKILL.md`.

**Tech Stack:** Bash (scripts, testes `*.test.sh` sem framework — só `grep -q` + contagem de `fail`), Markdown com frontmatter YAML (skills Claude/Gemini).

## Global Constraints

- A pasta-fonte `agentes/` na raiz **deste repositório** (`agentes-pipeline`) nunca é renomeada — é o template versionado. Só a cópia instalada dentro do projeto do usuário passa a se chamar `.agents/`.
- `install.sh` / `install.ps1` não são tocados por este plano.
- `agentes` (palavra solteira, sem `/`) permanece na lista `IGNORE_DIRS` de `agentes/scripts/detect-projects.sh` e na lista equivalente em `gemini/skills/orquestrador-init/SKILL.md`, ao lado de `.agents` — não remover, é compatibilidade com projetos ainda não migrados.
- Testes deste repo são scripts bash simples: função `check()` que faz `grep -q -- "$pattern" "$file"` e imprime `PASS`/`FAIL`, acumulando num `fail=0/1` retornado via `exit $fail`. Sem framework, sem mocks. Siga esse padrão em qualquer teste novo ou modificado.
- Toda referência a `agentes/X` que for um **caminho relativo ao projeto instalado** (dentro de conteúdo de persona, skill ou comando) vira `.agents/X`. Toda referência que for **caminho dentro deste repositório-fonte** (ex.: `$ROOT/agentes/PIPELINE.md` num teste, ou a tabela "Estrutura" do README) fica igual.

---

### Task 1: `scripts/init-manifest-diff.sh` — destino passa a `.agents/`

**Files:**
- Modify: `scripts/init-manifest-diff.sh`
- Modify: `scripts/init-manifest-diff.test.sh`
- Modify: `tests/coding-standards-skill.test.sh`

**Interfaces:**
- Produces: `init-manifest-diff.sh {generate|apply} <project_root> <template_agentes_dir> <template_commands_dir> <template_skills_dir>` continua com a mesma assinatura de CLI; internamente, todo caminho relativo gerado/lido agora usa o prefixo `.agents/` em vez de `agentes/`, e o manifesto vive em `<project_root>/.agents/.init-manifest.json`.

- [ ] **Step 1: Atualizar o teste (ainda vai falhar) — `scripts/init-manifest-diff.test.sh`**

Substitua o conteúdo inteiro do arquivo por esta versão (troca os fixtures de projeto instalado de `agentes/` para `.agents/`, adiciona o 4º argumento `template_skills` que faltava nas chamadas — bug pré-existente descoberto ao rodar o teste atual: `scripts/init-manifest-diff.sh` já exige 4 argumentos posicionais desde que o suporte à skill `coding-standards` foi adicionado, mas este teste nunca foi atualizado e falha hoje com `$5: unbound variable` antes mesmo desta mudança):

```bash
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
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash scripts/init-manifest-diff.test.sh`
Expected: FAIL — a saída ainda cria `$PROJ/agentes/...` (não `.agents/`), então os `check_content`/`grep` por `.agents/` não batem.

- [ ] **Step 3: Implementar — trocar o prefixo de destino em `scripts/init-manifest-diff.sh`**

Em `tracked_files()`:
```bash
tracked_files() {
  local template_agentes="$1" template_commands="$2" template_skills="$3" f d name
  for f in "$template_agentes"/*.md; do
    [[ -e "$f" ]] || continue
    printf '.agents/%s\n' "$(basename "$f")"
  done
  for f in "$template_agentes"/scripts/*.sh; do
    [[ -e "$f" ]] || continue
    printf '.agents/scripts/%s\n' "$(basename "$f")"
  done
  for f in "$template_commands"/*.md; do
    [[ -e "$f" ]] || continue
    printf '.claude/commands/%s\n' "$(basename "$f")"
  done
  for d in "$template_skills"/*/; do
    [[ -e "$d" ]] || continue
    name="$(basename "$d")"
    [[ -f "$d/SKILL.md" ]] || continue
    printf '.claude/skills/%s/SKILL.md\n' "$name"
  done
}
```

Em `template_path_of()`:
```bash
template_path_of() {
  local rel="$1" template_agentes="$2" template_commands="$3" template_skills="$4"
  case "$rel" in
    .agents/*) printf '%s/%s' "$template_agentes" "${rel#.agents/}" ;;
    .claude/commands/*) printf '%s/%s' "$template_commands" "${rel#.claude/commands/}" ;;
    .claude/skills/*) printf '%s/%s' "$template_skills" "${rel#.claude/skills/}" ;;
  esac
}
```

Em `cmd_generate()`, troque as duas linhas:
```bash
  local manifest="$project_root/.agents/.init-manifest.json"
  mkdir -p "$project_root/.agents"
```

Em `cmd_apply()`, troque:
```bash
  local manifest="$project_root/.agents/.init-manifest.json"
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash scripts/init-manifest-diff.test.sh`
Expected: PASS em todas as linhas, `exit 0`.

- [ ] **Step 5: Atualizar `tests/coding-standards-skill.test.sh`**

Troque o bloco de fixture (linhas do `mkdir -p "$TMP/agentes" ...` até o fim do arquivo):

```bash
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
```

Note que `"$ROOT/agentes"` (argumento passado ao script, apontando para a pasta-fonte deste repo) **não muda** — só o destino `$TMP/.agents` muda.

- [ ] **Step 6: Rodar os dois testes e confirmar que passam**

Run: `bash scripts/init-manifest-diff.test.sh && bash tests/coding-standards-skill.test.sh`
Expected: PASS em ambos.

- [ ] **Step 7: Commit**

```bash
git add scripts/init-manifest-diff.sh scripts/init-manifest-diff.test.sh tests/coding-standards-skill.test.sh
git commit -m "$(cat <<'EOF'
fix: init-manifest-diff.sh instala em .agents/ em vez de agentes/

Também corrige scripts/init-manifest-diff.test.sh, que faltava o 4º
argumento (template_skills) desde que o suporte à skill
coding-standards foi adicionado — o teste falhava com "$5: unbound
variable" antes mesmo desta mudança de pasta.
EOF
)"
```

---

### Task 2: `claude/skills/init-project/SKILL.md` — migração, marca de instalação e `.gitignore`

**Files:**
- Modify: `claude/skills/init-project/SKILL.md`
- Create: `tests/init-project-agents.test.sh`

**Interfaces:**
- Consumes: nenhuma (arquivo de instrução, sem código executável direto — testado por `grep` de padrões, igual aos demais skills/commands deste repo).

- [ ] **Step 1: Escrever o teste (vai falhar) — `tests/init-project-agents.test.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/claude/skills/init-project/SKILL.md"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$FILE"; then
    echo "PASS: $label"
  else
    echo "FAIL: SKILL.md não contém '$pattern' ($label)"
    fail=1
  fi
}

check './.agents/' "instala em ./.agents/ (oculta)"
check '.agents/PIPELINE.md' "usa .agents/PIPELINE.md como marca de instalação Claude"
check 'não apaga' ".agents/skills/ do Gemini não é apagada numa instalação nova"
check 'mv ./agentes ./.agents' "migra ./agentes legado com mv"
check 'reescreva as chaves do JSON' "migração reescreve as chaves do manifest (não regenera)"
check 'existirem ao mesmo tempo' "trata o conflito de ./agentes legado + .agents/PIPELINE.md coexistindo"
check '.gitignore' "documenta a automação do .gitignore"
check 'não crie o arquivo' ".gitignore não é criado quando não existe"

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash tests/init-project-agents.test.sh`
Expected: FAIL em todos os `check` (o SKILL.md atual ainda fala de `./agentes/` sem migração nem `.gitignore`).

- [ ] **Step 3: Reescrever `claude/skills/init-project/SKILL.md` por completo**

Substitua o conteúdo inteiro do arquivo por:

```markdown
---
name: init-project
description: Bootstrap a project with the standard multi-agent development pipeline (Analista, PO, Arquiteto, BDD, Designer, TL, Dev, QA, Revisor, Segurança, Orquestrador). Use when the user asks to set up, install, or update the agent pipeline in a project via /init-project.
---

# init-project

Instala (ou atualiza) o conjunto padrão de 11 personas de agentes + o documento de
pipeline dentro de `./.agents/`, os comandos `/orquestrador*` dentro de
`./.claude/commands/`, e a skill `coding-standards` (convenção de código sempre
em inglês) dentro de `./.claude/skills/`, no diretório de trabalho atual.

`./.agents/` é compartilhada com o lado Gemini/Antigravity, que instala seus
próprios skills em `./.agents/skills/` — este skill nunca apaga esse
subdiretório, só acrescenta/atualiza as personas na raiz de `./.agents/`.

## Passos

1. Resolva `TEMPLATE_DIR` como `~/agentes-pipeline/agentes/`,
   `COMMANDS_DIR` como `~/agentes-pipeline/commands/` e `SKILLS_DIR` como
   `~/agentes-pipeline/skills/` — repositório git dedicado e portátil que é a
   fonte única dos templates (não fica duplicado dentro deste skill; veja
   `~/agentes-pipeline/README.md` e `~/agentes-pipeline/AGENTS.md`).

2. **Migração de instalação legada.** Verifique `./agentes/` (nome antigo,
   visível) e `./.agents/PIPELINE.md` (marca de instalação atual do lado
   Claude):
   - Se **só** `./agentes/` existir: migre antes de continuar.
     1. Se `./.agents/` ainda não existir: `mv ./agentes ./.agents`.
     2. Se `./.agents/` já existir (ex.: só tinha `skills/` do lado Gemini):
        mova o conteúdo de `./agentes/` para dentro de `./.agents/` (não a
        pasta inteira) e remova `./agentes/` vazia.
     3. Se `./.agents/.init-manifest.json` existir, reescreva as chaves do
        JSON trocando o prefixo `"agentes/` por `".agents/`, mantendo os
        valores (hashes) exatamente como estão — **não** rode
        `init-manifest-diff.sh generate` para "regenerar" o manifesto: isso
        recalcularia o hash a partir do conteúdo local atual, que pode já
        estar customizado, e passaria a tratar a customização como se fosse
        a baseline do template — a próxima atualização real do template
        sobrescreveria a customização silenciosamente.
     4. Registre a migração para citar no resumo final.
   - Se **ambos** `./agentes/` e `./.agents/PIPELINE.md` existirem ao mesmo
     tempo: pare e reporte o conflito ao Bruno (os dois caminhos encontrados),
     sem tocar em nenhum dos dois — não tente adivinhar o merge.
   - Se nenhum dos dois existir, ou só `.agents/PIPELINE.md` existir: siga
     normalmente.

3. Verifique se `./.agents/PIPELINE.md` já existe (critério de "já instalado"
   do lado Claude — não confunda com `./.agents/` existir só por causa do
   `skills/` do Gemini).

4. **Se não existir:** copie o conteúdo de `TEMPLATE_DIR` para dentro de
   `./.agents/` (criando a pasta se não existir, sem apagar `./.agents/skills/`
   se já estiver lá), copie todo o conteúdo de `COMMANDS_DIR` para dentro de
   `./.claude/commands/` (crie a pasta se não existir), e copie todo o
   conteúdo de `SKILLS_DIR` para dentro de `./.claude/skills/` (crie a pasta
   se não existir). Liste os arquivos criados no resumo final.

5. **Se já existir (caso de atualização) e a flag `--update` NÃO foi passada:**
   um diretório não pode ser movido para dentro de si mesmo, então use uma
   renomeação temporária:
   1. `mv ./.agents ./.agents-old-{YYYYMMDD-HHMMSS}` (timestamp do momento da
      execução)
   2. `mkdir ./.agents`
   3. `mv ./.agents-old-{YYYYMMDD-HHMMSS} ./.agents/.backup-{YYYYMMDD-HHMMSS}`
   4. copie o conteúdo de `TEMPLATE_DIR` para dentro de `./.agents/`
   5. Se `./.agents/.backup-{YYYYMMDD-HHMMSS}/CONTEXTO.md` existir, copie-o
      (não mova) para `./.agents/CONTEXTO.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/TEAM.md` existir, copie-o (não
      mova) para `./.agents/TEAM.md`. O backup continua intacto com as cópias
      originais.
   6. copie todo o conteúdo de `COMMANDS_DIR` para dentro de
      `./.claude/commands/` (sobrescrevendo os 4 arquivos do Orquestrador se
      já existirem; não mexa em outros comandos que não sejam
      `orquestrador*.md`)
   7. copie todo o conteúdo de `SKILLS_DIR` para dentro de `./.claude/skills/`
      (sobrescrevendo apenas a pasta `coding-standards/` se já existir; não
      mexa em outras skills que o Bruno tenha instalado ali)
   Liste no resumo o que foi backupeado (caminho do backup), o que foi
   restaurado (`CONTEXTO.md`/`TEAM.md`, se aplicável) e o que foi instalado.

6. **Se já existir e a flag `--update` foi passada:**
   1. Rode:
      ```bash
      bash ~/agentes-pipeline/scripts/init-manifest-diff.sh apply \
        "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands \
        ~/agentes-pipeline/skills
      ```
   2. Se a saída for exatamente `NEED_FULL_REINSTALL` (exit code 2): não há
      manifesto ainda (projeto instalado antes desta funcionalidade existir).
      Caia automaticamente no comportamento do passo 5 (backup completo +
      reinstala tudo — o que já inclui a restauração de
      `CONTEXTO.md`/`TEAM.md` do backup para a pasta viva, conforme o item 5
      do passo 5) e, ao final dele, rode
      `bash ~/agentes-pipeline/scripts/init-manifest-diff.sh generate "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands ~/agentes-pipeline/skills`
      pra criar o manifesto inicial.
   3. Caso contrário, relate ao Bruno o resumo impresso pelo script
      (`INSTALLED=`, `OVERWRITTEN=`, `PRESERVED=`, `CONFLICTS=`) e, se houver
      conflitos, liste cada arquivo `.new` gerado e explique que ele precisa
      revisar manualmente (comparar `<arquivo>` com `<arquivo>.new` e decidir
      o que manter).
   4. `.agents/CONTEXTO.md`, `.agents/TEAM.md` e `.agents/.init-manifest.json`
      nunca são tocados por este fluxo — são dados do projeto, não do
      template.

7. Em todos os casos, o CONTEÚDO de `.agents/CONTEXTO.md` e `.agents/TEAM.md`
   nunca é modificado, sobrescrito ou gerado pelo processo — são dados do
   projeto, não do template. No fluxo do passo 5 eles são temporariamente
   movidos para o backup e depois restaurados (cópia, não edição) para a
   pasta viva com o conteúdo exatamente igual ao original; isso é apenas
   reposicionamento de arquivo, não "tocar" no conteúdo. Nenhum outro arquivo
   do projeto (README.md, `.planning/`, etc.) é afetado.

8. **Gitignore.** Depois de instalar/atualizar (em todos os casos acima,
   inclusive quando migrou), verifique `./.gitignore` na raiz do projeto:
   - Se não existir, não crie o arquivo — não faça nada.
   - Se existir e já tiver uma linha exatamente igual a `.agents`, `.agents/`,
     `/.agents` ou `/.agents/`, não faça nada (já está coberto).
   - Caso contrário, acrescente ao final:
     ```

     # agentes-pipeline (dados locais, não versionados)
     .agents/
     ```
     (uma linha em branco antes, se o arquivo não terminar já em branco).

9. Confirme a conclusão com um resumo curto: quantidade de arquivos
   instalados, o caminho do backup se houve um, se houve migração de
   `agentes/` legado, e se o `.gitignore` ganhou a entrada nova.

## Tratamento de erros

- Se `TEMPLATE_DIR`, `COMMANDS_DIR` ou `SKILLS_DIR` não existirem ou estiverem
  corrompidos (skill instalado incorretamente), reporte o caminho esperado e
  pare — não tente adivinhar o conteúdo.
- Se `./agentes/` (legado) e `./.agents/PIPELINE.md` existirem ao mesmo tempo,
  pare e reporte o conflito — não tente mesclar automaticamente (ver passo 2).
- Erros de permissão de escrita devem ser reportados diretamente ao usuário, sem pular
  arquivos silenciosamente.
- Não há chamadas de rede nem dependências externas — as únicas falhas possíveis são
  de sistema de arquivos local.

## Escopo

Este skill sempre instala o conjunto fixo completo de 12 arquivos em `.agents/`
(11 personas + `PIPELINE.md`) mais os 4 comandos `/orquestrador*` em
`.claude/commands/` mais a skill `coding-standards` em
`.claude/skills/coding-standards/SKILL.md`. A seleção de quais etapas do
pipeline rodar em cada tarefa é uma decisão de runtime feita pela persona
Orquestrador no início de cada sessão — não uma escolha no momento da
instalação.
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash tests/init-project-agents.test.sh`
Expected: PASS em todos os `check`.

- [ ] **Step 5: Rodar também `tests/coding-standards-skill.test.sh`** (ele faz `grep` de trechos deste SKILL.md que não mudaram — `SKILLS_DIR`, `.claude/skills/coding-standards`)

Run: `bash tests/coding-standards-skill.test.sh`
Expected: PASS (nenhum desses padrões foi removido na reescrita).

- [ ] **Step 6: Commit**

```bash
git add claude/skills/init-project/SKILL.md tests/init-project-agents.test.sh
git commit -m "$(cat <<'EOF'
feat: init-project migra agentes/ legado para .agents/ oculta + gitignore automático

.agents/PIPELINE.md passa a ser a marca de "já instalado" do lado
Claude, já que .agents/ agora também pode existir só por causa do
skills/ do Gemini. Projetos com ./agentes/ visível são migrados
automaticamente (rename + reescrita das chaves do manifest, sem
recalcular hash). Toda execução também garante uma entrada .agents/
no .gitignore do projeto, se já existir um.
EOF
)"
```

---

### Task 3: Conteúdo runtime de `agentes/ORQUESTRADOR.md` e `agentes/PIPELINE.md`

**Files:**
- Modify: `agentes/ORQUESTRADOR.md`
- Modify: `agentes/PIPELINE.md`
- Modify: `tests/team-md.test.sh`

**Interfaces:**
- Nenhuma — troca textual de caminho dentro de conteúdo de persona.

- [ ] **Step 1: Atualizar o teste (vai falhar) — `tests/team-md.test.sh`**

Troque a linha 18:
```bash
check "$ROOT/agentes/ORQUESTRADOR.md" '.agents/TEAM.md' "ORQUESTRADOR.md referencia TEAM.md no menu"
```
(As linhas 16-17, que checam `$ROOT/agentes/PIPELINE.md` como caminho de arquivo, **não mudam** — é o caminho-fonte deste repo.)

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash tests/team-md.test.sh`
Expected: FAIL na linha 18 (ORQUESTRADOR.md ainda tem `agentes/TEAM.md`, não `.agents/TEAM.md`).

- [ ] **Step 3: Implementar — substituir todas as ocorrências de `agentes/` por `.agents/` nos dois arquivos**

Use a ferramenta de edição com `replace_all` (todas as ocorrências em cada arquivo são referências de caminho relativo ao projeto instalado — nenhuma se refere à pasta-fonte deste repo):
- Em `agentes/ORQUESTRADOR.md`: substitua toda ocorrência da substring `agentes/` por `.agents/`.
- Em `agentes/PIPELINE.md`: substitua toda ocorrência da substring `agentes/` por `.agents/`.

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `bash tests/team-md.test.sh && bash tests/contexto-md.test.sh`
Expected: PASS em ambos (`contexto-md.test.sh` checa só títulos de seção, sem `agentes/`, então já passava e continua passando).

- [ ] **Step 5: Commit**

```bash
git add agentes/ORQUESTRADOR.md agentes/PIPELINE.md tests/team-md.test.sh
git commit -m "$(cat <<'EOF'
docs: personas Claude referenciam .agents/ em vez de agentes/

Caminhos runtime (CONTEXTO.md, TEAM.md, PIPELINE-STATE.md, arquivos de
persona) apontam pro novo destino oculto do /init-project.
EOF
)"
```

---

### Task 4: `commands/orquestrador*.md`

**Files:**
- Modify: `commands/orquestrador.md`
- Modify: `commands/orquestrador-init.md`
- Modify: `commands/orquestrador-team.md`
- Modify: `commands/orquestrador-fix.md`
- Modify: `commands/commands.test.sh`

**Interfaces:**
- Nenhuma — troca textual de caminho dentro de conteúdo de comando.

- [ ] **Step 1: Atualizar o teste (vai falhar) — `commands/commands.test.sh`**

Troque as 4 linhas de `check` que referenciam `agentes/...` como *padrão de busca* (2º argumento) — os caminhos de arquivo (`$DIR/orquestrador*.md`, 1º argumento) não mudam:

```bash
check "$DIR/orquestrador.md" '.agents/ORQUESTRADOR.md' "orquestrador.md referencia ORQUESTRADOR.md"
```
```bash
check "$DIR/orquestrador-init.md" '.agents/scripts/detect-projects.sh' "orquestrador-init.md referencia detect-projects.sh"
check "$DIR/orquestrador-init.md" '.agents/ORQUESTRADOR.md' "orquestrador-init.md referencia ORQUESTRADOR.md"
```
```bash
check "$DIR/orquestrador-team.md" '.agents/ORQUESTRADOR.md' "orquestrador-team.md referencia ORQUESTRADOR.md"
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash commands/commands.test.sh`
Expected: FAIL nas 4 linhas alteradas (os arquivos `.md` ainda têm `agentes/`, não `.agents/`).

- [ ] **Step 3: Implementar — substituir todas as ocorrências de `agentes/` por `.agents/` nos 4 arquivos**

Use `replace_all` em cada arquivo (todas as ocorrências nos 4 são referências de caminho relativo ao projeto instalado):
- `commands/orquestrador.md`: substitua toda ocorrência de `agentes/` por `.agents/`.
- `commands/orquestrador-init.md`: idem.
- `commands/orquestrador-team.md`: idem.
- `commands/orquestrador-fix.md`: idem.

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash commands/commands.test.sh`
Expected: PASS em todas as linhas.

- [ ] **Step 5: Commit**

```bash
git add commands/orquestrador.md commands/orquestrador-init.md commands/orquestrador-team.md commands/orquestrador-fix.md commands/commands.test.sh
git commit -m "$(cat <<'EOF'
docs: comandos /orquestrador* referenciam .agents/ em vez de agentes/
EOF
)"
```

---

### Task 5: `gemini/skills/orquestrador*/SKILL.md`

**Files:**
- Modify: `gemini/skills/orquestrador/SKILL.md`
- Modify: `gemini/skills/orquestrador-init/SKILL.md`
- Modify: `gemini/skills/orquestrador-team/SKILL.md`
- Modify: `gemini/skills/orquestrador-fix/SKILL.md`
- Modify: `tests/gemini-orquestrador-paridade.test.sh`

**Interfaces:**
- Nenhuma — troca textual de caminho dentro de conteúdo de skill.

- [ ] **Step 1: Atualizar o teste (vai falhar) — `tests/gemini-orquestrador-paridade.test.sh`**

Troque as linhas 17-18:
```bash
check '.agents/TEAM.md' "lê TEAM.md para pré-selecionar o menu"
check '.agents/CONTEXTO.md' "lê CONTEXTO.md como pano de fundo"
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash tests/gemini-orquestrador-paridade.test.sh`
Expected: FAIL nas duas linhas alteradas.

- [ ] **Step 3: Implementar — substituir todas as ocorrências de `agentes/` por `.agents/` nos 4 arquivos**

Use `replace_all` em cada arquivo (nenhum dos 4 tem qualquer outra ocorrência de `agentes/` que precise ficar como está — o `orquestrador-init/SKILL.md` também tem a palavra solteira `agentes` na lista de pastas ignoradas na varredura de projetos, sem a barra `/`, então `replace_all` de `agentes/` não a afeta):
- `gemini/skills/orquestrador/SKILL.md`: substitua toda ocorrência de `agentes/` por `.agents/`.
- `gemini/skills/orquestrador-init/SKILL.md`: idem (só afeta a linha `agentes/PIPELINE.md`, a lista de pastas ignoradas continua com `agentes` solteiro).
- `gemini/skills/orquestrador-team/SKILL.md`: idem.
- `gemini/skills/orquestrador-fix/SKILL.md`: idem.

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `bash tests/gemini-orquestrador-paridade.test.sh && bash tests/gemini-skills.test.sh && bash tests/detect-projects.test.sh`
Expected: PASS nos três (`gemini-skills.test.sh` e `detect-projects.test.sh` checam padrões sem `agentes/` como prefixo, então não precisam mudar e devem continuar passando).

- [ ] **Step 5: Commit**

```bash
git add gemini/skills/orquestrador/SKILL.md gemini/skills/orquestrador-init/SKILL.md gemini/skills/orquestrador-team/SKILL.md gemini/skills/orquestrador-fix/SKILL.md tests/gemini-orquestrador-paridade.test.sh
git commit -m "$(cat <<'EOF'
docs: skills Gemini/Antigravity do Orquestrador referenciam .agents/

Lado Gemini já instalava em .agents/skills/; agora os caminhos que
essas skills leem/escrevem (CONTEXTO.md, TEAM.md, PIPELINE.md) também
apontam pra .agents/, alinhado com a pasta unificada do lado Claude.
EOF
)"
```

---

### Task 6: Documentação (`README.md`, `AGENTS.md`, `gemini/README.md`)

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `gemini/README.md`

**Interfaces:**
- Nenhuma — só prosa. Sem teste automatizado (nenhum teste deste repo cobre esses três arquivos).

- [ ] **Step 1: `README.md` — atualizar a linha do resultado do `/init-project`**

Old:
```
Pronto — o projeto agora tem `./agentes/` (as 11 personas),
`./.claude/commands/orquestrador*.md` e `./.claude/skills/coding-standards/`
(convenção de código sempre em inglês, ativa em qualquer sessão do Claude Code
neste projeto — com ou sem o pipeline rodando). Para usar:
```
New:
```
Pronto — o projeto agora tem `./.agents/` (as 11 personas, oculta — o
instalador acrescenta uma entrada `.agents/` no `.gitignore` do projeto se já
existir um; projetos que já tinham a antiga `./agentes/` visível são migrados
automaticamente na próxima vez que `/init-project` rodar),
`./.claude/commands/orquestrador*.md` e `./.claude/skills/coding-standards/`
(convenção de código sempre em inglês, ativa em qualquer sessão do Claude Code
neste projeto — com ou sem o pipeline rodando). Para usar:
```

(A tabela "Pasta" do topo e a árvore da seção "Estrutura", que mostram `agentes/` como pasta deste repositório, **não mudam** — descrevem a fonte, não o destino instalado.)

- [ ] **Step 2: `AGENTS.md` — atualizar as seções que descrevem o projeto instalado**

Old (linha 4):
```
pasta `./agentes/` instalada a partir daqui, e não tem histórico de conversa prévio.
```
New:
```
pasta `./.agents/` instalada a partir daqui, e não tem histórico de conversa prévio.
```

Old (linha 22):
```
`./agentes/` está instalado.
```
New:
```
`./.agents/` está instalado.
```

Old (linhas 27-30):
```
do arquivo de persona da etapa (ex: `agentes/DEV.md`), (2) o contexto acumulado
das etapas já executadas, e (3) a demanda original do usuário. Detalhes da mecânica
de disparo e do log de contexto acumulado estão em `agentes/ORQUESTRADOR.md`.
```
New:
```
do arquivo de persona da etapa (ex: `.agents/DEV.md`), (2) o contexto acumulado
das etapas já executadas, e (3) a demanda original do usuário. Detalhes da mecânica
de disparo e do log de contexto acumulado estão em `.agents/ORQUESTRADOR.md`.
```

Old (linha 38, cabeçalho):
```
## Se você está num projeto com `./agentes/` instalado a partir daqui
```
New:
```
## Se você está num projeto com `./.agents/` instalado a partir daqui
```

Old (linha 40):
```
1. Ponto de entrada padrão: `agentes/ORQUESTRADOR.md`. Só ative o pipeline via `/orquestrador` (Claude) ou dizendo "orquestrador: ..." (Antigravity). Sem esse gatilho, mesmo que
```
New:
```
1. Ponto de entrada padrão: `.agents/ORQUESTRADOR.md`. Só ative o pipeline via `/orquestrador` (Claude) ou dizendo "orquestrador: ..." (Antigravity). Sem esse gatilho, mesmo que
```

Old (linhas 42-45):
```
2. Diagrama completo do pipeline, tabela de etapas e perfis rápidos (quais etapas
   ativar por tipo de tarefa) estão em `agentes/PIPELINE.md`.
3. Cada etapa individual tem seu próprio arquivo de instruções em `agentes/*.md`
   (ex: `agentes/DEV.md` para a etapa de implementação).
```
New:
```
2. Diagrama completo do pipeline, tabela de etapas e perfis rápidos (quais etapas
   ativar por tipo de tarefa) estão em `.agents/PIPELINE.md`.
3. Cada etapa individual tem seu próprio arquivo de instruções em `.agents/*.md`
   (ex: `.agents/DEV.md` para a etapa de implementação).
```

Old (linha 59):
```
5. Este conjunto de arquivos pode ser atualizado rodando `/init-project` de novo
   no projeto (faz backup do `./agentes/` atual antes de sobrescrever).
```
New:
```
5. Este conjunto de arquivos pode ser atualizado rodando `/init-project` de novo
   no projeto (faz backup do `./.agents/` atual antes de sobrescrever).
```

(A seção "Se você está neste repositório (`agentes-pipeline`)", incluindo a
frase "edite o arquivo correspondente em `agentes/*.md` normalmente" —
**não muda**: fala de editar a fonte deste repo.)

- [ ] **Step 3: `gemini/README.md` — atualizar a linha "Localização no projeto" e adicionar nota de unificação**

Old:
```
| **Localização no projeto** | `./agentes/` | `.agents/skills/` |
```
New:
```
| **Localização no projeto** | `.agents/` (raiz) | `.agents/skills/` |

> As personas Claude e os skills Gemini/Antigravity compartilham a mesma
> pasta oculta `.agents/` no projeto instalado — as personas ficam na raiz
> (`.agents/PIPELINE.md`, `.agents/DEV.md`, etc.) e os skills Gemini em
> `.agents/skills/`.
```

- [ ] **Step 4: Rodar a suíte de testes inteira uma última vez**

Run:
```bash
for f in tests/*.test.sh commands/commands.test.sh scripts/*.test.sh claude/continuidade/install.test.sh claude/continuidade/core/lib/*.test.sh claude/continuidade/core/*.test.sh; do
  [[ -f "$f" ]] || continue
  echo "== $f =="
  bash "$f" || echo "FALHOU: $f"
done
```
Expected: nenhum `FALHOU` na saída (os testes fora do escopo deste plano continuam passando sem alteração; os deste plano já foram verificados individualmente nas tasks anteriores).

- [ ] **Step 5: Commit**

```bash
git add README.md AGENTS.md gemini/README.md
git commit -m "$(cat <<'EOF'
docs: README/AGENTS.md/gemini README refletem .agents/ como pasta instalada
EOF
)"
```
