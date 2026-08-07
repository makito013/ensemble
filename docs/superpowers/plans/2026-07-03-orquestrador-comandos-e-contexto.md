# Orquestrador: comandos, memória de projeto e update inteligente — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o gatilho de texto do pipeline Orquestrador por comandos reais, dar a ele memória de projeto persistente e escopada (`CONTEXTO.md`/`TEAM.md`), e tornar `init-project --update` capaz de atualizar sem esmagar customizações locais.

**Architecture:** Repositório-fonte `agentes-pipeline` ganha uma pasta `commands/` (comandos Claude), 3 skills novas em `gemini/skills/` (equivalentes Antigravity), e uma pasta `agentes/scripts/` que é copiada para dentro de cada projeto consumidor (lógica de detecção de projeto, usada em runtime por `/orquestrador-init`). O instalador `~/.claude/skills/init-project/SKILL.md` (fora do repo, mas em escopo) ganha um script irmão `agentes-pipeline/scripts/init-manifest-diff.sh` (só para o instalador, nunca copiado para projetos consumidores) que implementa o merge inteligente do `--update`. Todos os `*.test.sh` deste plano moram em `agentes-pipeline/tests/` (nova pasta de nível raiz, nunca copiada para projeto nenhum) — nenhum arquivo de teste do template pode acabar dentro de um projeto consumidor.

**Tech Stack:** Bash + coreutils (`shasum`/`sha256sum`, `find`, `grep -F`) — sem dependências externas, consistente com o `~/bin/init-project` existente. Conteúdo dos agentes continua em Markdown com frontmatter YAML.

## Global Constraints

- Local único para estado por projeto nos dois formatos (Claude e Gemini): `<projeto>/agentes/CONTEXTO.md` e `<projeto>/agentes/TEAM.md`.
- Sem compatibilidade retroativa com o prefixo de texto `"Orquestrador: ..."` no lado Claude — troca explícita para `/orquestrador`.
- `.git` é o marcador primário de fronteira de projeto; `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `composer.json`, `pom.xml`, `Gemfile` só valem na ausência de `.git`.
- `*.code-workspace` **nunca** conta como marcador de projeto (é um agrupador multi-root do VS Code, não um projeto).
- Ignorar sempre ao varrer: `node_modules`, `.git`, `dist`, `build`, `vendor`, `.venv`, `__pycache__`, `.agents`, `.claude`, `agentes`.
- Profundidade máxima de varredura: 6 níveis a partir da raiz de busca.
- `CONTEXTO.md`, `TEAM.md` e `.init-manifest.json` nunca entram no diff do `--update` — são dados do projeto, não do template.
- Sem `--update` (comando puro, sem flag): mantém o comportamento atual do instalador (backup completo do `agentes/` + reinstala tudo).
- Override de modelo (Sonnet→Opus) não funciona ao disparar um *fork* — só em subagentes novos (`subagent_type` diferente de fork).
- Não bloquear skills GSD nos arquivos do pipeline — decisão já tomada (GSD será desinstalado à parte pelo Bruno, fora deste plano).
- Subagentes são memoryless: qualquer instrução de comportamento (realimentação de contexto, escolha de modelo) tem que estar no *prompt de disparo*, nunca só documentada em algum arquivo que o subagente não recebe.

---

### Task 1: Comandos Claude (gatilhos finos)

**Files:**
- Create: `agentes-pipeline/commands/orquestrador.md`
- Create: `agentes-pipeline/commands/orquestrador-init.md`
- Create: `agentes-pipeline/commands/orquestrador-fix.md`
- Create: `agentes-pipeline/commands/orquestrador-team.md`
- Test: `agentes-pipeline/commands/commands.test.sh`

**Interfaces:**
- Produces: 4 arquivos `.md` com frontmatter `description:` e `argument-hint:`, cada um referenciando `agentes/ORQUESTRADOR.md` e injetando `$ARGUMENTS`. Consumidos pela Task 4 (instalador copia `commands/` para `.claude/commands/`).

- [ ] **Step 1: Escrever o teste que falha (arquivos ainda não existem)**

```bash
cat > /Users/bruno.andrade/agentes-pipeline/commands/commands.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe"
    fail=1
    return
  fi
  if ! grep -q -- "$pattern" "$file"; then
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
    return
  fi
  echo "PASS: $label"
}

check "$DIR/orquestrador.md" '^argument-hint: \[descrição da tarefa\]' "orquestrador.md tem argument-hint"
check "$DIR/orquestrador.md" 'agentes/ORQUESTRADOR.md' "orquestrador.md referencia ORQUESTRADOR.md"
check "$DIR/orquestrador.md" '\$ARGUMENTS' "orquestrador.md injeta \$ARGUMENTS"

check "$DIR/orquestrador-init.md" '^argument-hint: \[pasta opcional\]' "orquestrador-init.md tem argument-hint"
check "$DIR/orquestrador-init.md" 'agentes/scripts/detect-projects.sh' "orquestrador-init.md referencia detect-projects.sh"
check "$DIR/orquestrador-init.md" 'agentes/ORQUESTRADOR.md' "orquestrador-init.md referencia ORQUESTRADOR.md"

check "$DIR/orquestrador-fix.md" '^argument-hint: {texto do bug}' "orquestrador-fix.md tem argument-hint"
check "$DIR/orquestrador-fix.md" 'CONTEXTO.md' "orquestrador-fix.md lê CONTEXTO.md"
check "$DIR/orquestrador-fix.md" 'recomendo Analista, TL, Dev, QA, Revisor porque' "orquestrador-fix.md tem exemplo de justificativa da recomendação"

check "$DIR/orquestrador-team.md" '^argument-hint: \[ação opcional' "orquestrador-team.md tem argument-hint"
check "$DIR/orquestrador-team.md" 'TEAM.md' "orquestrador-team.md referencia TEAM.md"
check "$DIR/orquestrador-team.md" 'agentes/ORQUESTRADOR.md' "orquestrador-team.md referencia ORQUESTRADOR.md"

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/commands/commands.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/commands/commands.test.sh`
Expected: várias linhas `FAIL: ... não existe` (os 4 arquivos ainda não existem), exit code 1.

- [ ] **Step 3: Criar `orquestrador.md`**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/commands
cat > /Users/bruno.andrade/agentes-pipeline/commands/orquestrador.md <<'EOF'
---
description: Aciona o pipeline multi-agente completo do Orquestrador para uma solicitação de desenvolvimento.
argument-hint: [descrição da tarefa]
---

Leia integralmente `agentes/ORQUESTRADOR.md` e `agentes/PIPELINE.md` e assuma a
persona Orquestrador para a seguinte solicitação:

$ARGUMENTS

Antes de apresentar o menu de etapas:
- Se existir `agentes/CONTEXTO.md`, leia e use como pano de fundo (nunca leia o
  `CONTEXTO.md` de outro projeto).
- Se existir `agentes/TEAM.md`, use como pré-seleção padrão do menu de etapas
  em vez do padrão fixo descrito em `ORQUESTRADOR.md`.

Siga a mecânica de disparo de subagentes descrita em `ORQUESTRADOR.md`
(inclusive a seção de realimentação de contexto e de escolha de modelo em
`PIPELINE.md`).
EOF
```

- [ ] **Step 4: Criar `orquestrador-init.md`**

```bash
cat > /Users/bruno.andrade/agentes-pipeline/commands/orquestrador-init.md <<'EOF'
---
description: Varre o(s) projeto(s) e gera/atualiza agentes/CONTEXTO.md com o máximo de contexto útil.
argument-hint: [pasta opcional]
---

Consulte `agentes/ORQUESTRADOR.md` para a persona e mecânica base do Orquestrador.
Assuma a persona Orquestrador em modo de coleta de contexto.

Pasta informada (vazio = detectar todos os projetos a partir do cwd):

$ARGUMENTS

Passos:
1. Rode `agentes/scripts/detect-projects.sh $ARGUMENTS` (sem argumento, o
   script usa o diretório atual como raiz de busca) para obter a lista de
   projetos, um caminho absoluto por linha.
2. Para cada projeto da lista, dispare um subagente isolado
   (`subagent_type: general-purpose`) que varre só aquela subárvore e
   escreve/funde `agentes/CONTEXTO.md` naquele projeto, seguindo a estrutura
   de seções descrita em `agentes/PIPELINE.md`.
3. Nunca deixe um subagente ler ou escrever o `CONTEXTO.md` de outro projeto.
4. Ao final, resuma ao Bruno: projetos processados, quais eram novos vs.
   atualizados, e qualquer aviso (ex: nenhum projeto encontrado até a
   profundidade máxima).
EOF
```

- [ ] **Step 5: Criar `orquestrador-fix.md`**

```bash
cat > /Users/bruno.andrade/agentes-pipeline/commands/orquestrador-fix.md <<'EOF'
---
description: Inicia um estudo de bug — Orquestrador analisa o texto e recomenda quais etapas/agentes ativar.
argument-hint: {texto do bug}
---

Assuma a persona Orquestrador em modo de triagem de bug para o seguinte relato:

$ARGUMENTS

Passos:
1. Se existir `agentes/CONTEXTO.md` neste projeto, leia antes de tudo.
2. Faça uma triagem do texto do bug (uma frase de diagnóstico + qual camada
   provavelmente está envolvida) e proponha um subconjunto de etapas
   pré-marcado no menu padrão de `agentes/ORQUESTRADOR.md`, com uma linha de
   justificativa curta para a recomendação (ex: "recomendo Analista, TL, Dev, QA, Revisor porque mexe em lógica compartilhada com o módulo de pagamentos").
3. Apresente o menu já pré-marcado ao Bruno. Ele pode aceitar, adicionar ou
   remover qualquer etapa antes de confirmar.
4. A partir da confirmação, siga a mecânica de disparo normal descrita em
   `ORQUESTRADOR.md`.
EOF
```

- [ ] **Step 6: Criar `orquestrador-team.md`**

```bash
cat > /Users/bruno.andrade/agentes-pipeline/commands/orquestrador-team.md <<'EOF'
---
description: Consulta ou edita agentes/TEAM.md — quais das 10 etapas do pipeline ficam ativas por padrão neste projeto.
argument-hint: [ação opcional: listar|ativar N|desativar N]
---

Consulte `agentes/ORQUESTRADOR.md` para a persona e mecânica base do Orquestrador.

Ação solicitada (vazio = apenas listar o estado atual):

$ARGUMENTS

Passos:
1. Se `agentes/TEAM.md` não existir, crie a partir do template descrito em
   `agentes/PIPELINE.md`, com o padrão recomendado atual (etapas 1, 6, 7, 9
   marcadas — Análise, TL, Dev, Revisão).
2. Sem ação: mostre o checklist atual formatado.
3. Com `ativar N` / `desativar N`: edite a linha correspondente à etapa N em
   `agentes/TEAM.md` (a etapa 7 — Desenvolvimento — não pode ser desativada) e
   confirme a mudança ao Bruno.
4. Deixe claro que isto só muda a pré-seleção do menu de `/orquestrador` — o
   Bruno ainda pode ajustar por sessão.
EOF
```

- [ ] **Step 7: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/commands/commands.test.sh`
Expected: 12 linhas `PASS: ...`, exit code 0.

- [ ] **Step 8: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add commands/
git commit -m "feat: adiciona comandos Claude do Orquestrador (init, fix, team)"
```

---

### Task 2: Migração do gatilho (texto → `/orquestrador`)

**Files:**
- Modify: `agentes-pipeline/agentes/ORQUESTRADOR.md` (linha final, "Gatilho")
- Modify: `agentes-pipeline/AGENTS.md`
- Modify: `agentes-pipeline/agentes/PIPELINE.md`
- Modify: `agentes-pipeline/README.md`
- Test: `agentes-pipeline/tests/trigger-migration.test.sh`

**Interfaces:**
- Consumes: nenhuma (edição de conteúdo existente).
- Produces: nenhuma referência viva a `"Orquestrador: ..."` como gatilho nesses 4 arquivos.

- [ ] **Step 1: Escrever o teste que falha**

Todos os arquivos `*.test.sh` deste plano ficam em `agentes-pipeline/tests/`
— nunca dentro de `agentes/`, `commands/` ou `gemini/skills/`, porque essas
três pastas (ou o conteúdo `*.md` delas) são copiadas inteiras para dentro de
projetos consumidores pelo instalador; `tests/` nunca é copiada.

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/tests
cat > /Users/bruno.andrade/agentes-pipeline/tests/trigger-migration.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check_absent() {
  local file="$1" pattern="$2"
  if grep -q -- "$pattern" "$file"; then
    echo "FAIL: $file ainda contém gatilho antigo ('$pattern')"
    fail=1
  else
    echo "PASS: $file sem gatilho de texto antigo"
  fi
}

check_present() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não menciona '$pattern' ($label)"
    fail=1
  fi
}

check_absent "$ROOT/agentes/ORQUESTRADOR.md" 'mensagem do Bruno começar com "Orquestrador:"'
check_present "$ROOT/agentes/ORQUESTRADOR.md" '/orquestrador' "ORQUESTRADOR.md menciona /orquestrador"

check_absent "$ROOT/AGENTS.md" 'Orquestrador: quero adicionar login com Google'
check_present "$ROOT/AGENTS.md" '/orquestrador' "AGENTS.md menciona /orquestrador"

check_present "$ROOT/README.md" '/orquestrador' "README.md menciona /orquestrador"

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/tests/trigger-migration.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/trigger-migration.test.sh`
Expected: `FAIL` nas linhas de `check_absent` (gatilho antigo ainda presente), exit code 1.

- [ ] **Step 3: Editar o rodapé de `ORQUESTRADOR.md`**

Substituir a última linha do arquivo (`*Gatilho: só ative este fluxo quando a mensagem do Bruno começar com "Orquestrador:". Fora disso, siga o fluxo normal do projeto.*`) por:

```markdown
---
*Gatilho: só ative este fluxo via `/orquestrador` (ou `/orquestrador-init`,
`/orquestrador-fix`, `/orquestrador-team` para os modos específicos). Fora
disso, siga o fluxo normal do projeto.*
```

- [ ] **Step 4: Editar `AGENTS.md`**

Trocar o bloco:

```markdown
O gatilho é sempre manual — o usuário digita um prefixo, ex:

> "Orquestrador: quero adicionar login com Google ao projeto"

Fora desse prefixo, não ative o pipeline; siga o fluxo normal do projeto onde
`./agentes/` está instalado.
```

por:

```markdown
O gatilho é sempre manual. No Claude Code, via comando:

> `/orquestrador quero adicionar login com Google ao projeto`

No Antigravity/Gemini CLI, continua por prefixo de texto (skill discovery):

> "orquestrador: quero adicionar login com Google ao projeto"

Fora desse gatilho, não ative o pipeline; siga o fluxo normal do projeto onde
`./agentes/` está instalado.
```

E, no item 1 da seção "Se você está num projeto com `./agentes/` instalado a
partir daqui", trocar `Só ative o pipeline quando o usuário disser algo como
"Orquestrador: ..."` por `Só ative o pipeline via `/orquestrador` (Claude) ou
dizendo "orquestrador: ..." (Antigravity)`.

- [ ] **Step 5: Editar `agentes/PIPELINE.md` e `README.md`**

Em `PIPELINE.md`, troque qualquer instrução equivalente de gatilho por texto
pela mesma redação usada em `ORQUESTRADOR.md` (Step 3). Em `README.md`, troque
os exemplos de uso:

```markdown
Orquestrador: quero adicionar autenticação JWT ao projeto
```

por:

```markdown
/orquestrador quero adicionar autenticação JWT ao projeto
```

(mantendo a seção de perfis rápidos como está — `[F]`, `[B1]` etc. continuam
válidos como texto dentro do argumento do comando).

- [ ] **Step 6: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/trigger-migration.test.sh`
Expected: 5 linhas `PASS`, exit code 0.

- [ ] **Step 7: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add agentes/ORQUESTRADOR.md AGENTS.md agentes/PIPELINE.md README.md tests/trigger-migration.test.sh
git commit -m "docs: migra gatilho de texto para /orquestrador no lado Claude"
```

---

### Task 3: Skills Gemini equivalentes

**Files:**
- Create: `agentes-pipeline/gemini/skills/orquestrador-init/SKILL.md`
- Create: `agentes-pipeline/gemini/skills/orquestrador-fix/SKILL.md`
- Create: `agentes-pipeline/gemini/skills/orquestrador-team/SKILL.md`
- Test: `agentes-pipeline/tests/gemini-skills.test.sh`

**Interfaces:**
- Consumes: mesma lógica descrita nos comandos Claude (Task 1), adaptada para auto-descoberta por `description:` (sem `$ARGUMENTS`).
- Produces: nenhuma (skills terminais, descobertas pelo Antigravity).

- [ ] **Step 1: Escrever o teste que falha**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/tests
cat > /Users/bruno.andrade/agentes-pipeline/tests/gemini-skills.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../gemini/skills" && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe"
    fail=1
    return
  fi
  if ! grep -q -- "$pattern" "$file"; then
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
    return
  fi
  echo "PASS: $label"
}

check "$DIR/orquestrador-init/SKILL.md" '^name: orquestrador-init' "orquestrador-init tem name correto"
check "$DIR/orquestrador-init/SKILL.md" 'CONTEXTO.md' "orquestrador-init menciona CONTEXTO.md"

check "$DIR/orquestrador-fix/SKILL.md" '^name: orquestrador-fix' "orquestrador-fix tem name correto"
check "$DIR/orquestrador-fix/SKILL.md" 'CONTEXTO.md' "orquestrador-fix lê CONTEXTO.md"
check "$DIR/orquestrador-fix/SKILL.md" 'recomendo Analista, TL, Dev, QA, Revisor porque' "orquestrador-fix/SKILL.md tem o mesmo exemplo de justificativa do lado Claude"

check "$DIR/orquestrador-team/SKILL.md" '^name: orquestrador-team' "orquestrador-team tem name correto"
check "$DIR/orquestrador-team/SKILL.md" 'TEAM.md' "orquestrador-team menciona TEAM.md"

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/tests/gemini-skills.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/gemini-skills.test.sh`
Expected: `FAIL: ... não existe` para os 3 arquivos, exit code 1.

- [ ] **Step 3: Criar `orquestrador-init/SKILL.md`**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/gemini/skills/orquestrador-init
cat > /Users/bruno.andrade/agentes-pipeline/gemini/skills/orquestrador-init/SKILL.md <<'EOF'
---
name: orquestrador-init
description: Varre o(s) projeto(s) do repositório atual e gera/atualiza agentes/CONTEXTO.md com o máximo de contexto útil. Ativa quando o usuário escrever "orquestrador-init" seguido, opcionalmente, de uma pasta.
---

# Agente: Orquestrador — modo coleta de contexto

Assuma a persona Orquestrador (ver `orquestrador/SKILL.md`) em modo de coleta
de contexto. O texto após "orquestrador-init" é a pasta-raiz de busca; se
vazio, use o diretório atual.

Passos:
1. Detecte os projetos a partir da raiz de busca seguindo a regra de fronteira
   de projeto descrita em `agentes/PIPELINE.md` (marcador primário `.git`;
   `*.code-workspace` nunca conta como marcador; ignora `node_modules`,
   `.git`, `dist`, `build`, `vendor`, `.venv`, `__pycache__`, `.agents`,
   `.claude`, `agentes`; profundidade máxima 6).
2. Para cada projeto encontrado, dispare um subagente isolado que varre só
   aquela subárvore e escreve/funde `agentes/CONTEXTO.md` naquele projeto,
   nunca lendo ou escrevendo o `CONTEXTO.md` de outro projeto.
3. Ao final, resuma ao usuário: projetos processados, novos vs. atualizados,
   e qualquer aviso.
EOF
```

- [ ] **Step 4: Criar `orquestrador-fix/SKILL.md`**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/gemini/skills/orquestrador-fix
cat > /Users/bruno.andrade/agentes-pipeline/gemini/skills/orquestrador-fix/SKILL.md <<'EOF'
---
name: orquestrador-fix
description: Inicia um estudo de bug — analisa o texto e recomenda quais etapas/agentes ativar. Ativa quando o usuário escrever "orquestrador-fix" seguido da descrição do bug.
---

# Agente: Orquestrador — modo triagem de bug

Assuma a persona Orquestrador (ver `orquestrador/SKILL.md`) em modo de triagem
de bug. O texto após "orquestrador-fix" é a descrição do bug.

Passos:
1. Se existir `agentes/CONTEXTO.md` neste projeto, leia antes de tudo.
2. Faça uma triagem do bug e proponha um subconjunto de etapas pré-marcado no
   menu padrão, com uma linha de justificativa curta (ex: "recomendo Analista, TL, Dev, QA, Revisor porque mexe em lógica compartilhada com o módulo de pagamentos").
3. Apresente o menu pré-marcado; o usuário pode aceitar, adicionar ou remover
   qualquer etapa antes de confirmar.
4. A partir da confirmação, siga a mecânica de disparo normal.
EOF
```

- [ ] **Step 5: Criar `orquestrador-team/SKILL.md`**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/gemini/skills/orquestrador-team
cat > /Users/bruno.andrade/agentes-pipeline/gemini/skills/orquestrador-team/SKILL.md <<'EOF'
---
name: orquestrador-team
description: Consulta ou edita agentes/TEAM.md — quais das 10 etapas do pipeline ficam ativas por padrão neste projeto. Ativa quando o usuário escrever "orquestrador-team".
---

# Agente: Orquestrador — modo time padrão

Assuma a persona Orquestrador (ver `orquestrador/SKILL.md`) em modo de gestão
de time. O texto após "orquestrador-team" é a ação (vazio = listar).

Passos:
1. Se `agentes/TEAM.md` não existir, crie a partir do padrão recomendado
   (etapas 1, 6, 7, 9 marcadas).
2. Sem ação: mostre o checklist atual.
3. Com `ativar N` / `desativar N`: edite a etapa N (a etapa 7 —
   Desenvolvimento — não pode ser desativada) e confirme.
4. Deixe claro que isto só muda a pré-seleção do menu — o usuário ainda pode
   ajustar por sessão.
EOF
```

- [ ] **Step 6: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/gemini-skills.test.sh`
Expected: 6 linhas `PASS`, exit code 0.

- [ ] **Step 7: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add gemini/skills/orquestrador-init gemini/skills/orquestrador-fix gemini/skills/orquestrador-team tests/gemini-skills.test.sh
git commit -m "feat: adiciona skills Gemini equivalentes (init, fix, team)"
```

---

### Task 4: Instalador copia `commands/` também (sem `--update` ainda)

**Files:**
- Modify: `/Users/bruno.andrade/.claude/skills/init-project/SKILL.md`
- Test: `/private/tmp/claude-502/init-project-copy.test.sh` (fixture temporária, fora do repo)

**Interfaces:**
- Consumes: `agentes-pipeline/commands/*.md` (Task 1), `agentes-pipeline/agentes/*.md`.
- Produces: instalação de `<projeto>/agentes/` **e** `<projeto>/.claude/commands/` a partir de `~/agentes-pipeline/`.

- [ ] **Step 1: Escrever o teste que falha**

```bash
cat > /tmp/init-project-copy.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Simula exatamente os passos que o SKILL.md instrui para instalação nova
TEMPLATE_DIR="$HOME/agentes-pipeline/agentes"
COMMANDS_DIR="$HOME/agentes-pipeline/commands"
cp -R "$TEMPLATE_DIR" "$FIXTURE/agentes"
mkdir -p "$FIXTURE/.claude/commands"
cp "$COMMANDS_DIR"/*.md "$FIXTURE/.claude/commands/"

fail=0
[[ -f "$FIXTURE/agentes/ORQUESTRADOR.md" ]] || { echo "FAIL: agentes/ORQUESTRADOR.md não copiado"; fail=1; }
[[ -f "$FIXTURE/agentes/scripts/detect-projects.sh" ]] || { echo "FAIL: agentes/scripts/detect-projects.sh não copiado"; fail=1; }
[[ -f "$FIXTURE/.claude/commands/orquestrador.md" ]] || { echo "FAIL: .claude/commands/orquestrador.md não copiado"; fail=1; }
[[ -f "$FIXTURE/.claude/commands/orquestrador-init.md" ]] || { echo "FAIL: .claude/commands/orquestrador-init.md não copiado"; fail=1; }
[[ -f "$FIXTURE/.claude/commands/orquestrador-fix.md" ]] || { echo "FAIL: .claude/commands/orquestrador-fix.md não copiado"; fail=1; }
[[ -f "$FIXTURE/.claude/commands/orquestrador-team.md" ]] || { echo "FAIL: .claude/commands/orquestrador-team.md não copiado"; fail=1; }

# Nenhum arquivo de teste do repositório-fonte pode vazar pra dentro do
# projeto instalado — eles ficam em agentes-pipeline/tests/, fora de tudo
# que este passo copia.
leaked="$(find "$FIXTURE" -name '*.test.sh')"
if [[ -z "$leaked" ]]; then
  echo "PASS: nenhum *.test.sh vazou para o projeto instalado"
else
  echo "FAIL: arquivos de teste vazaram para o projeto instalado: $leaked"
  fail=1
fi

if [[ $fail -eq 0 ]]; then echo "PASS: instalação copia agentes/ e .claude/commands/"; fi
exit $fail
EOF
chmod +x /tmp/init-project-copy.test.sh
```

*(Este teste já passaria hoje pra `agentes/ORQUESTRADOR.md`, `detect-projects.sh`
e para a ausência de vazamento (nada disso muda nesta task), mas falha pros 4
arquivos de `.claude/commands/` — é a Task 1 que ainda não estava referenciada
pelo instalador.)*

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /tmp/init-project-copy.test.sh`
Expected: 4 linhas `FAIL: .claude/commands/... não copiado`, exit code 1.

- [ ] **Step 3: Reescrever `~/.claude/skills/init-project/SKILL.md`**

Substituir os passos 1–5 (resolução de `TEMPLATE_DIR` e cópia) por:

```markdown
## Passos

1. Resolva `TEMPLATE_DIR` como `~/agentes-pipeline/agentes/` e
   `COMMANDS_DIR` como `~/agentes-pipeline/commands/` — repositório git
   dedicado e portátil que é a fonte única dos templates (não fica duplicado
   dentro deste skill; veja `~/agentes-pipeline/README.md` e
   `~/agentes-pipeline/AGENTS.md`).

2. Verifique se `./agentes/` já existe no projeto atual (diretório de
   trabalho).

3. **Se não existir:** copie `TEMPLATE_DIR` inteiro para `./agentes/`, e copie
   todo o conteúdo de `COMMANDS_DIR` para dentro de `./.claude/commands/`
   (crie a pasta se não existir). Liste os arquivos criados no resumo final.

4. **Se já existir (caso de atualização) e a flag `--update` NÃO foi passada:**
   um diretório não pode ser movido para dentro de si mesmo, então use uma
   renomeação temporária:
   1. `mv ./agentes ./.agentes-old-{YYYYMMDD-HHMMSS}` (timestamp do momento da
      execução)
   2. `mkdir ./agentes`
   3. `mv ./.agentes-old-{YYYYMMDD-HHMMSS} ./agentes/.backup-{YYYYMMDD-HHMMSS}`
   4. copie `TEMPLATE_DIR` inteiro para dentro de `./agentes/`
   5. copie todo o conteúdo de `COMMANDS_DIR` para dentro de
      `./.claude/commands/` (sobrescrevendo os 4 arquivos do Orquestrador se
      já existirem; não mexa em outros comandos que não sejam
      `orquestrador*.md`)
   Liste no resumo o que foi backupeado (caminho do backup) e o que foi
   instalado.

5. **Se já existir e a flag `--update` foi passada:** siga o fluxo descrito na
   seção "Update inteligente" abaixo (ver Task 13 deste repositório — ainda
   não implementado nesta etapa; até lá, `--update` cai no mesmo
   comportamento do passo 4).

6. Em todos os casos, não toque em `agentes/CONTEXTO.md`, `agentes/TEAM.md`
   nem em nenhum outro arquivo do projeto (README.md, `.planning/`, etc.
   ficam intocados).

7. Confirme a conclusão com um resumo curto: quantidade de arquivos
   instalados, e o caminho do backup se houve um.
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash /tmp/init-project-copy.test.sh`
Expected: `PASS: instalação copia agentes/ e .claude/commands/`, exit code 0.

- [ ] **Step 5: Commit (só o que está dentro do repo)**

O `SKILL.md` do instalador fica fora do repositório `agentes-pipeline` (mora
em `~/.claude/skills/init-project/`), então não há o que commitar no repo
nesta task — a edição já está persistida no arquivo em disco. Confirme que
`agentes-pipeline` continua limpo:

```bash
cd /Users/bruno.andrade/agentes-pipeline
git status --short
```
Expected: nenhuma mudança pendente (esta task não tocou em arquivos do repo).

---

### Task 5: `TEAM.md` — template e leitura no menu

**Files:**
- Modify: `agentes-pipeline/agentes/PIPELINE.md` (documentar o template de `TEAM.md`)
- Modify: `agentes-pipeline/agentes/ORQUESTRADOR.md` (menu lê `TEAM.md` se existir)
- Test: `agentes-pipeline/tests/team-md.test.sh`

**Interfaces:**
- Consumes: nenhuma.
- Produces: seção "Template de TEAM.md" em `PIPELINE.md`, referenciada por
  `commands/orquestrador-team.md` (Task 1) e por `commands/orquestrador.md`.

- [ ] **Step 1: Escrever o teste que falha**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/tests
cat > /Users/bruno.andrade/agentes-pipeline/tests/team-md.test.sh <<'EOF'
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

check "$ROOT/agentes/PIPELINE.md" 'Template de TEAM.md' "PIPELINE.md documenta o template de TEAM.md"
check "$ROOT/agentes/PIPELINE.md" '\[x\] 7\. DESENVOLVIMENTO' "PIPELINE.md mostra etapa 7 sempre marcada"
check "$ROOT/agentes/ORQUESTRADOR.md" 'agentes/TEAM.md' "ORQUESTRADOR.md referencia TEAM.md no menu"

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/tests/team-md.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/team-md.test.sh`
Expected: 3 linhas `FAIL`, exit code 1.

- [ ] **Step 3: Adicionar a seção em `PIPELINE.md`**

Acrescentar, próximo à tabela de etapas existente:

```markdown
## Template de TEAM.md

Se `agentes/TEAM.md` existir no projeto, ele define a pré-seleção do menu de
`/orquestrador` (o Bruno ainda pode ajustar por sessão). Formato:

```
# Time padrão — <projeto>

Define a pré-seleção do menu quando /orquestrador rodar aqui.
O Bruno ainda pode ajustar por sessão — isto só muda o ponto de partida.

[x] 1. ANÁLISE — Analista
[ ] 2. CLARIFICAÇÃO — PO
[x] 3. ARQUITETURA — Arquiteto
[ ] 4. BDD
[ ] 5. UX/UI — Designer
[x] 6. TECH LEAD — TL
[x] 7. DESENVOLVIMENTO — Dev (sempre ativo, não editável)
[ ] 8. TESTES UNITÁRIOS — QA
[x] 9. REVISÃO — Revisor
[ ] 10. SEGURANÇA
```

A etapa 7 (Desenvolvimento) nunca pode ficar desmarcada — `/orquestrador-team`
recusa a edição se o Bruno tentar desativá-la.
```

- [ ] **Step 4: Referenciar `TEAM.md` no menu de `ORQUESTRADOR.md`**

No trecho "Como você inicia uma sessão" de `ORQUESTRADOR.md`, acrescentar
antes do "Menu padrão a apresentar":

```markdown
Se `agentes/TEAM.md` existir, use-o para pré-marcar o menu abaixo (em vez do
padrão fixo) antes de apresentá-lo ao Bruno.
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/team-md.test.sh`
Expected: 3 linhas `PASS`, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add agentes/PIPELINE.md agentes/ORQUESTRADOR.md tests/team-md.test.sh
git commit -m "feat: documenta template de TEAM.md e integra ao menu do Orquestrador"
```

---

### Task 6: `CONTEXTO.md` — template das 7 seções

**Files:**
- Modify: `agentes-pipeline/agentes/PIPELINE.md` (documentar o template de `CONTEXTO.md`)
- Test: `agentes-pipeline/tests/contexto-md.test.sh`

**Interfaces:**
- Produces: seção "Template de CONTEXTO.md" em `PIPELINE.md`, consumida pela
  Task 8 (`/orquestrador-init` gera o arquivo a partir deste template).

- [ ] **Step 1: Escrever o teste que falha**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/tests
cat > /Users/bruno.andrade/agentes-pipeline/tests/contexto-md.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$ROOT/agentes/PIPELINE.md"; then
    echo "PASS: $label"
  else
    echo "FAIL: PIPELINE.md não contém '$pattern' ($label)"
    fail=1
  fi
}

check 'Template de CONTEXTO.md' "seção existe"
check 'Visão geral do projeto' "seção 1"
check 'Integrações externas' "seção 5 (dependências entre projetos)"
check 'Log de atualizações' "seção 7"

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/tests/contexto-md.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/contexto-md.test.sh`
Expected: 4 linhas `FAIL`, exit code 1.

- [ ] **Step 3: Adicionar a seção em `PIPELINE.md`**

```markdown
## Template de CONTEXTO.md

`agentes/CONTEXTO.md` é a memória persistente de um projeto. Gerado/atualizado
por `/orquestrador-init` e realimentado durante o uso normal do pipeline
(ver "Como disparar cada etapa" em `ORQUESTRADOR.md`). Sempre com estas 7
seções, nesta ordem:

1. **Visão geral do projeto** — propósito, domínio, stack.
2. **Arquitetura** — camadas, padrões, decisões estruturais.
3. **Convenções de código** — estilo, nomenclatura, padrões observados no repo.
4. **Decisões importantes e histórico** — por que certas escolhas foram feitas.
5. **Integrações externas / dependências entre projetos** — ex: "consome os
   endpoints X e Y do serviço `ymci-backend`; contrato em `docs/api/...`".
   Existe para o caso de monorepo onde um projeto secundário depende de 1-2
   endpoints do produto principal, sem precisar importar o contexto inteiro
   do outro projeto.
6. **Áreas sensíveis / gotchas conhecidos** — coisas que quebram fácil, dívida
   técnica.
7. **Log de atualizações** — data, o que mudou, origem (`init` ou `pipeline`).

Ao fundir com um `CONTEXTO.md` já existente: preserva o que ainda é válido,
atualiza o que mudou, sempre registra uma linha nova na seção 7.
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/contexto-md.test.sh`
Expected: 4 linhas `PASS`, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add agentes/PIPELINE.md tests/contexto-md.test.sh
git commit -m "docs: documenta template de CONTEXTO.md em PIPELINE.md"
```

---

### Task 7: `detect-projects.sh` — regra E, com testes de fixture

**Files:**
- Create: `agentes-pipeline/agentes/scripts/detect-projects.sh`
- Test: `agentes-pipeline/tests/detect-projects.test.sh` (o teste fica fora de
  `agentes/scripts/` de propósito — `agentes/` inteira é copiada para dentro
  de projetos consumidores, e um `.test.sh` não tem nada a fazer lá; só o
  script `.sh` de verdade é template)

**Interfaces:**
- Produces: `detect-projects.sh [pasta-raiz]` → imprime um caminho absoluto de
  projeto por linha, ordenado. Consumido por `commands/orquestrador-init.md`
  (Task 1, já referenciado) e pela Task 8.

- [ ] **Step 1: Escrever o teste que falha**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/agentes/scripts
mkdir -p /Users/bruno.andrade/agentes-pipeline/tests
cat > /Users/bruno.andrade/agentes-pipeline/tests/detect-projects.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../agentes/scripts" && pwd)"
DETECT="$SCRIPT_DIR/detect-projects.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# Estrutura que espelha o achado real em podesubir: agrupadores sem
# marcador, projetos reais em profundidades 2 e 3, um marcador secundário
# sem .git, e um node_modules que deve ser sempre ignorado.
mkdir -p "$FIXTURE/company/principal/ymci-backend/.git"
touch "$FIXTURE/company/principal/principal.code-workspace"
mkdir -p "$FIXTURE/company/principal/apps/podesubir-app/.git"
mkdir -p "$FIXTURE/company/gateways/access-gateway-x/.git"
mkdir -p "$FIXTURE/company/gateways/access-gateway-x/vendor/weird/.git"
mkdir -p "$FIXTURE/company/standalone-tool"
touch "$FIXTURE/company/standalone-tool/package.json"
mkdir -p "$FIXTURE/company/node_modules/some-pkg/.git"

actual="$(bash "$DETECT" "$FIXTURE/company")"
expected="$FIXTURE/company/gateways/access-gateway-x
$FIXTURE/company/principal/apps/podesubir-app
$FIXTURE/company/principal/ymci-backend
$FIXTURE/company/standalone-tool"

if [[ "$actual" == "$expected" ]]; then
  echo "PASS: detect-projects encontrou exatamente os 4 projetos esperados"
else
  echo "FAIL: saída não bate"
  echo "--- esperado ---"; echo "$expected"
  echo "--- obtido ---"; echo "$actual"
  exit 1
fi

# Caso 2: raiz já é um projeto (tem .git direto) -> retorna só ela, não desce
mkdir -p "$FIXTURE/solo/.git"
mkdir -p "$FIXTURE/solo/sub/outro/.git"
actual2="$(bash "$DETECT" "$FIXTURE/solo")"
if [[ "$actual2" == "$FIXTURE/solo" ]]; then
  echo "PASS: raiz com .git próprio não desce mais"
else
  echo "FAIL: esperado só '$FIXTURE/solo', obtido: $actual2"
  exit 1
fi

# Caso 3: nada encontrado -> saída vazia, exit 0 (quem decide o aviso ao
# usuário é o comando que chama o script, não o script)
mkdir -p "$FIXTURE/vazio/sub1/sub2"
actual3="$(bash "$DETECT" "$FIXTURE/vazio")"
if [[ -z "$actual3" ]]; then
  echo "PASS: nenhum projeto encontrado -> saída vazia"
else
  echo "FAIL: esperado saída vazia, obtido: $actual3"
  exit 1
fi
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/tests/detect-projects.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/detect-projects.test.sh`
Expected: erro `No such file or directory` (o script ainda não existe), exit code diferente de 0.

- [ ] **Step 3: Implementar `detect-projects.sh`**

```bash
cat > /Users/bruno.andrade/agentes-pipeline/agentes/scripts/detect-projects.sh <<'EOF'
#!/usr/bin/env bash
# detect-projects.sh — encontra fronteiras de projeto a partir de uma raiz,
# seguindo a regra E do spec (docs/superpowers/specs/2026-07-03-*).
# Uso: detect-projects.sh [pasta-raiz]
# Imprime um caminho absoluto por linha, um por projeto encontrado, ordenado.
set -euo pipefail
shopt -s nullglob

ROOT="${1:-.}"
if [[ ! -d "$ROOT" ]]; then
  echo "detect-projects.sh: pasta não encontrada: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

MAX_DEPTH=6
IGNORE_DIRS=(node_modules .git dist build vendor .venv __pycache__ .agents .claude agentes)
MARKERS=(package.json pyproject.toml go.mod Cargo.toml composer.json pom.xml Gemfile)

is_ignored() {
  local name="$1" ig
  for ig in "${IGNORE_DIRS[@]}"; do
    [[ "$name" == "$ig" ]] && return 0
  done
  return 1
}

has_marker() {
  local dir="$1" m
  [[ -e "$dir/.git" ]] && return 0
  for m in "${MARKERS[@]}"; do
    [[ -e "$dir/$m" ]] && return 0
  done
  return 1
}

results=()

if has_marker "$ROOT"; then
  results+=("$ROOT")
else
  queue=("$ROOT:0")
  while [[ ${#queue[@]} -gt 0 ]]; do
    entry="${queue[0]}"
    queue=("${queue[@]:1}")
    dir="${entry%:*}"
    depth="${entry##*:}"

    [[ "$depth" -ge "$MAX_DEPTH" ]] && continue

    for child in "$dir"/*/; do
      child="${child%/}"
      name="$(basename "$child")"
      is_ignored "$name" && continue

      if has_marker "$child"; then
        results+=("$child")
      else
        queue+=("$child:$((depth+1))")
      fi
    done
  done
fi

[[ ${#results[@]} -eq 0 ]] && exit 0
printf '%s\n' "${results[@]}" | sort
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/agentes/scripts/detect-projects.sh
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/detect-projects.test.sh`
Expected: 3 linhas `PASS`, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add agentes/scripts/detect-projects.sh tests/detect-projects.test.sh
git commit -m "feat: adiciona detect-projects.sh (regra E de fronteira de projeto)"
```

---

### Task 8: `/orquestrador-init` gera/funde `CONTEXTO.md` (liga D, E, F)

**Files:**
- Modify: `agentes-pipeline/commands/orquestrador-init.md` (adicionar instrução de merge)
- Modify: `agentes-pipeline/gemini/skills/orquestrador-init/SKILL.md` (idem)
- Test: `agentes-pipeline/commands/orquestrador-init-merge.test.sh`

**Interfaces:**
- Consumes: `agentes/scripts/detect-projects.sh` (Task 7), template de 7 seções
  em `PIPELINE.md` (Task 6).
- Produces: instrução explícita de merge (preservar + atualizar + logar) que a
  Task 9 (realimentação) e a Task 12 (nunca tocado pelo `--update`) dependem
  ter documentada num único lugar canônico.

- [ ] **Step 1: Escrever o teste que falha**

```bash
cat > /Users/bruno.andrade/agentes-pipeline/commands/orquestrador-init-merge.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
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

check "$DIR/orquestrador-init.md" 'já existir' "comando Claude documenta o caso de merge"
check "$DIR/orquestrador-init.md" 'preserva o que ainda é válido' "comando Claude documenta a regra de merge"
check "$ROOT/gemini/skills/orquestrador-init/SKILL.md" 'já existir' "skill Gemini documenta o caso de merge"

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/commands/orquestrador-init-merge.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/commands/orquestrador-init-merge.test.sh`
Expected: 3 linhas `FAIL`, exit code 1.

- [ ] **Step 3: Adicionar a instrução de merge em `commands/orquestrador-init.md`**

No passo 2 do arquivo (criado na Task 1), acrescentar a frase final:

```markdown
2. Para cada projeto da lista, dispare um subagente isolado
   (`subagent_type: general-purpose`) que varre só aquela subárvore e
   escreve/funde `agentes/CONTEXTO.md` naquele projeto, seguindo a estrutura
   de seções descrita em `agentes/PIPELINE.md`. Se `CONTEXTO.md` já existir
   naquele projeto, o subagente funde: preserva o que ainda é válido, atualiza
   o que mudou, e sempre registra uma linha nova na seção "Log de
   atualizações" (origem `init`) — nunca sobrescreve cegamente.
```

- [ ] **Step 4: Espelhar a mesma instrução em `gemini/skills/orquestrador-init/SKILL.md`**

No passo 2 daquele arquivo, mesma redação:

```markdown
2. Para cada projeto encontrado, dispare um subagente isolado que varre só
   aquela subárvore e escreve/funde `agentes/CONTEXTO.md` naquele projeto,
   nunca lendo ou escrevendo o `CONTEXTO.md` de outro projeto. Se
   `CONTEXTO.md` já existir, o subagente funde: preserva o que ainda é
   válido, atualiza o que mudou, e sempre registra uma linha nova na seção
   "Log de atualizações" (origem `init`) — nunca sobrescreve cegamente.
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/commands/orquestrador-init-merge.test.sh`
Expected: 3 linhas `PASS`, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add commands/orquestrador-init.md gemini/skills/orquestrador-init/SKILL.md commands/orquestrador-init-merge.test.sh
git commit -m "feat: /orquestrador-init funde CONTEXTO.md em vez de sobrescrever"
```

---

### Task 9: Realimentação de contexto na mecânica de disparo (G)

**Files:**
- Modify: `agentes-pipeline/agentes/ORQUESTRADOR.md` (seção "Como disparar cada etapa")
- Test: `agentes-pipeline/tests/context-feedback.test.sh`

**Interfaces:**
- Consumes: nenhuma.
- Produces: instrução injetada em todo prompt de disparo de subagente,
  consumida implicitamente por todas as personas (Task 10 aponta pra cá).

- [ ] **Step 1: Escrever o teste que falha**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/tests
cat > /Users/bruno.andrade/agentes-pipeline/tests/context-feedback.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$ROOT/agentes/ORQUESTRADOR.md"; then
    echo "PASS: $label"
  else
    echo "FAIL: ORQUESTRADOR.md não contém '$pattern' ($label)"
    fail=1
  fi
}

check 'Atualização de contexto sugerida' "instrução de realimentação presente"
check 'pergunta ao Bruno antes de gravar' "confirmação antes de gravar no CONTEXTO.md"

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/tests/context-feedback.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/context-feedback.test.sh`
Expected: 2 linhas `FAIL`, exit code 1.

- [ ] **Step 3: Editar a seção "Como disparar cada etapa" em `ORQUESTRADOR.md`**

Acrescentar um item 4 à lista existente (que hoje tem 3 itens: conteúdo da
persona, contexto acumulado, tarefa original):

```markdown
4. Uma instrução final pedindo ao subagente que termine sua resposta com uma
   seção opcional "Atualização de contexto sugerida" se ele aprendeu algo que
   muda o entendimento do projeto (ex: durante a implementação percebeu que
   algo mudou). No fim da sessão, o Orquestrador consolida todas as sugestões
   recebidas e, se houver alguma, pergunta ao Bruno antes de gravar em
   `agentes/CONTEXTO.md` — nunca grava silenciosamente.
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/context-feedback.test.sh`
Expected: 2 linhas `PASS`, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add agentes/ORQUESTRADOR.md tests/context-feedback.test.sh
git commit -m "feat: injeta pedido de realimentação de contexto em todo disparo de subagente"
```

---

### Task 10: Subagentes e escolha de modelo (J) — `PIPELINE.md` + ponteiros nas 11 personas

**Files:**
- Modify: `agentes-pipeline/agentes/PIPELINE.md` (nova seção)
- Modify: `agentes-pipeline/agentes/ANALISTA.md`
- Modify: `agentes-pipeline/agentes/ARQUITETO.md`
- Modify: `agentes-pipeline/agentes/BDD.md`
- Modify: `agentes-pipeline/agentes/DESIGNER.md`
- Modify: `agentes-pipeline/agentes/DEV.md`
- Modify: `agentes-pipeline/agentes/ORQUESTRADOR.md`
- Modify: `agentes-pipeline/agentes/PO.md`
- Modify: `agentes-pipeline/agentes/QA.md`
- Modify: `agentes-pipeline/agentes/REVISOR.md`
- Modify: `agentes-pipeline/agentes/SEGURANCA.md`
- Modify: `agentes-pipeline/agentes/TL.md`
- Test: `agentes-pipeline/tests/subagentes-modelo.test.sh`

**Interfaces:**
- Produces: seção única "Subagentes e escolha de modelo" em `PIPELINE.md`,
  referenciada por uma linha-ponteiro idêntica em cada uma das 11 personas.

- [ ] **Step 1: Escrever o teste que falha**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/tests
cat > /Users/bruno.andrade/agentes-pipeline/tests/subagentes-modelo.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
PONTEIRO='Ver "Subagentes e escolha de modelo" em `agentes/PIPELINE.md`.'
PERSONAS=(ANALISTA ARQUITETO BDD DESIGNER DEV ORQUESTRADOR PO QA REVISOR SEGURANCA TL)

if grep -q 'Subagentes e escolha de modelo' "$ROOT/agentes/PIPELINE.md" \
   && grep -q 'não funciona ao disparar um' "$ROOT/agentes/PIPELINE.md"; then
  echo "PASS: PIPELINE.md tem a seção com a ressalva de fork"
else
  echo "FAIL: PIPELINE.md sem a seção completa"
  fail=1
fi

for p in "${PERSONAS[@]}"; do
  if grep -qF "$PONTEIRO" "$ROOT/agentes/$p.md"; then
    echo "PASS: $p.md tem a linha-ponteiro"
  else
    echo "FAIL: $p.md sem a linha-ponteiro"
    fail=1
  fi
done

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/tests/subagentes-modelo.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/subagentes-modelo.test.sh`
Expected: 12 linhas `FAIL` (seção + 11 personas), exit code 1.

- [ ] **Step 3: Adicionar a seção em `PIPELINE.md`**

```markdown
## Subagentes e escolha de modelo

Qualquer agente deste pipeline (inclusive o Orquestrador) pode disparar
subagentes próprios para paralelizar partes independentes do seu próprio
trabalho.

- Modelo padrão: Sonnet. Escale para Opus quando perceber complexidade real
  (refatoração ampla, lógica ambígua exigindo raciocínio profundo, código
  security-sensitive, ou quando um subagente Sonnet já não deu conta).
- **Ressalva:** o override de modelo não funciona ao disparar um *fork* — só
  ao disparar um subagente novo (`subagent_type` diferente de fork). Um fork
  sempre roda no modelo de quem o disparou. A escalação pra Opus só vale para
  subagentes "frescos".
```

- [ ] **Step 4: Adicionar a linha-ponteiro nas 11 personas**

Em cada um dos 11 arquivos, acrescentar ao final (antes de qualquer rodapé
de gatilho já existente) a linha:

```markdown
Ver "Subagentes e escolha de modelo" em `agentes/PIPELINE.md`.
```

```bash
cd /Users/bruno.andrade/agentes-pipeline/agentes
for p in ANALISTA ARQUITETO BDD DESIGNER DEV ORQUESTRADOR PO QA REVISOR SEGURANCA TL; do
  printf '\nVer "Subagentes e escolha de modelo" em `agentes/PIPELINE.md`.\n' >> "$p.md"
done
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/subagentes-modelo.test.sh`
Expected: 12 linhas `PASS`, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add agentes/PIPELINE.md agentes/ANALISTA.md agentes/ARQUITETO.md agentes/BDD.md agentes/DESIGNER.md agentes/DEV.md agentes/ORQUESTRADOR.md agentes/PO.md agentes/QA.md agentes/REVISOR.md agentes/SEGURANCA.md agentes/TL.md tests/subagentes-modelo.test.sh
git commit -m "feat: regra de subagentes e escolha de modelo (Sonnet/Opus), referenciada nas 11 personas"
```

---

### Task 11: Limpeza de documentação (L)

**Files:**
- Modify: `agentes-pipeline/README.md`
- Modify: `agentes-pipeline/gemini/README.md`
- Test: `agentes-pipeline/docs-cleanup.test.sh`

**Interfaces:** nenhuma.

- [ ] **Step 1: Escrever o teste que falha**

```bash
cat > /Users/bruno.andrade/agentes-pipeline/docs-cleanup.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

for f in README.md gemini/README.md; do
  if grep -q '~/bin/init-project' "$ROOT/$f"; then
    echo "FAIL: $f ainda referencia ~/bin/init-project no fluxo Claude"
    fail=1
  else
    echo "PASS: $f sem referência a ~/bin/init-project"
  fi
done

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/docs-cleanup.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/docs-cleanup.test.sh`
Expected: 2 linhas `FAIL`, exit code 1.

- [ ] **Step 3: Remover as referências em `README.md`**

Trocar:

```markdown
### Para Claude / Claude Code

\`\`\`bash
# Via skill (se init-project estiver instalado em ~/bin/):
bash ~/bin/init-project .

# Ou manualmente:
cp -R ~/agentes-pipeline/agentes/ /caminho/do/projeto/agentes/
\`\`\`
```

por:

```markdown
### Para Claude / Claude Code

\`\`\`bash
# Via skill (recomendado):
/init-project

# Para atualizar um projeto já instalado, sem perder customizações locais:
/init-project --update
\`\`\`
```

E, na seção "Atualizando o pipeline" e "Sincronizar em outra máquina",
trocar toda ocorrência de `bash ~/bin/init-project . --force` /
`bash ~/bin/init-project /caminho/do/projeto` por `/init-project` ou
`/init-project --update`, conforme o contexto (instalação nova vs.
atualização).

- [ ] **Step 4: Remover a referência em `gemini/README.md`**

Trocar:

```markdown
### Opção 2 — Via script init-project (se disponível)

\`\`\`bash
bash ~/bin/init-project .
\`\`\`
```

por:

```markdown
### Opção 2 — Via comando /init-project (lado Claude, se instalado no mesmo repositório)

Se este mesmo repositório também usa o pipeline no formato Claude, rodar
`/init-project` lá também deixa os skills Gemini disponíveis em
`.agents/skills/` (ver Opção 1 acima para instalação direta).
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/docs-cleanup.test.sh`
Expected: 2 linhas `PASS`, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add README.md gemini/README.md docs-cleanup.test.sh
git commit -m "docs: remove referências obsoletas a ~/bin/init-project"
```

---

### Task 12: `init-manifest-diff.sh` — manifesto + merge inteligente, com testes de fixture

**Files:**
- Create: `agentes-pipeline/scripts/init-manifest-diff.sh`
- Test: `agentes-pipeline/scripts/init-manifest-diff.test.sh`

**Interfaces:**
- Produces:
  - `init-manifest-diff.sh generate <project_root> <template_agentes_dir> <template_commands_dir>` → (re)escreve `<project_root>/agentes/.init-manifest.json`.
  - `init-manifest-diff.sh apply <project_root> <template_agentes_dir> <template_commands_dir>` → aplica o merge inteligente, imprime resumo `INSTALLED=n OVERWRITTEN=n PRESERVED=n CONFLICTS=n` + uma linha `CONFLICT: <path>.new` por conflito; retorna exit code 2 e imprime `NEED_FULL_REINSTALL` se não houver manifesto ainda.
  - O conjunto rastreado (`tracked_files`) cobre três fontes: `<template_agentes>/*.md`, `<template_agentes>/scripts/*.sh` (ex: `detect-projects.sh` da Task 7 — sem isso, um bug fix nele nunca chegaria a projetos já instalados via `--update`) e `<template_commands>/*.md`.
- Consumed by: Task 13 (instalador liga `--update` a este script).

- [ ] **Step 1: Escrever o teste que falha**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/scripts
cat > /Users/bruno.andrade/agentes-pipeline/scripts/init-manifest-diff.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/init-manifest-diff.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

TPL_A="$FIXTURE/template/agentes"
TPL_C="$FIXTURE/template/commands"
PROJ="$FIXTURE/project"
mkdir -p "$TPL_A" "$TPL_C" "$PROJ/agentes" "$PROJ/.claude/commands"

# --- Round 1: instalação inicial idêntica ao template ---
echo "conteudo A v1" > "$TPL_A/A.md"
echo "conteudo B v1" > "$TPL_A/B.md"
echo "conteudo D v1" > "$TPL_A/D.md"
echo "conteudo C v1" > "$TPL_C/C.md"
mkdir -p "$TPL_A/scripts" "$PROJ/agentes/scripts"
echo "script v1" > "$TPL_A/scripts/detect-projects.sh"

cp "$TPL_A/A.md" "$PROJ/agentes/A.md"
cp "$TPL_A/B.md" "$PROJ/agentes/B.md"
cp "$TPL_A/D.md" "$PROJ/agentes/D.md"
cp "$TPL_C/C.md" "$PROJ/.claude/commands/C.md"
cp "$TPL_A/scripts/detect-projects.sh" "$PROJ/agentes/scripts/detect-projects.sh"

bash "$TOOL" generate "$PROJ" "$TPL_A" "$TPL_C"

fail=0
if [[ -f "$PROJ/agentes/.init-manifest.json" ]]; then
  echo "PASS: generate cria .init-manifest.json"
else
  echo "FAIL: .init-manifest.json não foi criado"
  fail=1
fi
if grep -q 'agentes/A.md' "$PROJ/agentes/.init-manifest.json"; then
  echo "PASS: manifesto registra agentes/A.md"
else
  echo "FAIL: manifesto não registra agentes/A.md"
  fail=1
fi

# --- Round 2: simula mudanças antes do --update ---
echo "conteudo A v2" > "$TPL_A/A.md"                 # template mudou, local intocado -> OVERWRITE
echo "conteudo B CUSTOM" > "$PROJ/agentes/B.md"       # local mudou, template intocado -> PRESERVE
echo "conteudo D v2" > "$TPL_A/D.md"                  # os dois mudaram -> CONFLICT
echo "conteudo D CUSTOM" > "$PROJ/agentes/D.md"
echo "conteudo E v1" > "$TPL_A/E.md"                  # novo arquivo no template -> INSTALL
echo "script v2 (bugfix)" > "$TPL_A/scripts/detect-projects.sh"  # script mudou, local intocado -> OVERWRITE

summary="$(bash "$TOOL" apply "$PROJ" "$TPL_A" "$TPL_C")"
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

check_content "$PROJ/agentes/A.md" "conteudo A v2" "A.md foi sobrescrito (OVERWRITE)"
check_content "$PROJ/agentes/B.md" "conteudo B CUSTOM" "B.md foi preservado (PRESERVE)"
check_content "$PROJ/agentes/D.md" "conteudo D CUSTOM" "D.md local preservado apesar do conflito"
check_content "$PROJ/agentes/D.md.new" "conteudo D v2" "D.md.new contém a versão nova do template (CONFLICT)"
check_content "$PROJ/agentes/E.md" "conteudo E v1" "E.md foi instalado (INSTALL)"
check_content "$PROJ/agentes/scripts/detect-projects.sh" "script v2 (bugfix)" "detect-projects.sh (.sh, não .md) também é rastreado e sobrescrito"

if echo "$summary" | grep -q 'INSTALLED=1 OVERWRITTEN=3 PRESERVED=1 CONFLICTS=1'; then
  echo "PASS: resumo bate (1 install, 3 overwrite [A+C+script], 1 preserve, 1 conflict)"
else
  echo "FAIL: resumo não bate: $summary"
  fail=1
fi
if echo "$summary" | grep -q 'CONFLICT: agentes/D.md.new'; then
  echo "PASS: resumo lista o conflito de D.md"
else
  echo "FAIL: resumo não lista o conflito de D.md"
  fail=1
fi

# --- Round 3: sem manifesto -> pede reinstalação completa ---
PROJ2="$FIXTURE/project-sem-manifesto"
mkdir -p "$PROJ2/agentes"
set +e
out2="$(bash "$TOOL" apply "$PROJ2" "$TPL_A" "$TPL_C")"
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
mkdir -p "$PROJ3/agentes" "$PROJ3/.claude/commands" "$TPL_A3" "$TPL_C3"

echo "conteudo B v1" > "$TPL_A3/B.md"
cp "$TPL_A3/B.md" "$PROJ3/agentes/B.md"
bash "$TOOL" generate "$PROJ3" "$TPL_A3" "$TPL_C3"

echo "conteudo B CUSTOM" > "$PROJ3/agentes/B.md"
bash "$TOOL" apply "$PROJ3" "$TPL_A3" "$TPL_C3" > /dev/null

echo "conteudo B v2" > "$TPL_A3/B.md"
bash "$TOOL" apply "$PROJ3" "$TPL_A3" "$TPL_C3" > /dev/null

final_content="$(cat "$PROJ3/agentes/B.md")"
if [[ "$final_content" == "conteudo B CUSTOM" ]]; then
  echo "PASS: customização sobrevive a um segundo --update (regressão do bug de rebase pelo hash local)"
else
  echo "FAIL: customização foi perdida no segundo --update! conteúdo final: $final_content"
  fail=1
fi

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/scripts/init-manifest-diff.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/scripts/init-manifest-diff.test.sh`
Expected: erro `No such file or directory` (script ainda não existe), exit code diferente de 0.

- [ ] **Step 3: Implementar `init-manifest-diff.sh`**

```bash
cat > /Users/bruno.andrade/agentes-pipeline/scripts/init-manifest-diff.sh <<'EOF'
#!/usr/bin/env bash
# init-manifest-diff.sh — manifesto + merge inteligente para `init-project --update`.
# Só usado pelo instalador; NUNCA é copiado para dentro de projetos consumidores.
# Uso:
#   init-manifest-diff.sh generate <project_root> <template_agentes_dir> <template_commands_dir>
#   init-manifest-diff.sh apply    <project_root> <template_agentes_dir> <template_commands_dir>
set -euo pipefail
shopt -s nullglob

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

manifest_get() {
  local manifest="$1" key="$2" line
  [[ -f "$manifest" ]] || return 1
  line="$(grep -F "\"$key\":" "$manifest" | head -1)" || true
  [[ -n "$line" ]] || return 1
  printf '%s' "$line" | sed -E 's/^[^:]*: *"([^"]*)".*/\1/'
}

tracked_files() {
  local template_agentes="$1" template_commands="$2" f
  for f in "$template_agentes"/*.md; do
    [[ -e "$f" ]] || continue
    printf 'agentes/%s\n' "$(basename "$f")"
  done
  for f in "$template_agentes"/scripts/*.sh; do
    [[ -e "$f" ]] || continue
    printf 'agentes/scripts/%s\n' "$(basename "$f")"
  done
  for f in "$template_commands"/*.md; do
    [[ -e "$f" ]] || continue
    printf '.claude/commands/%s\n' "$(basename "$f")"
  done
}

template_path_of() {
  local rel="$1" template_agentes="$2" template_commands="$3"
  case "$rel" in
    agentes/*) printf '%s/%s' "$template_agentes" "${rel#agentes/}" ;;
    .claude/commands/*) printf '%s/%s' "$template_commands" "${rel#.claude/commands/}" ;;
  esac
}

cmd_generate() {
  local project_root="$1" template_agentes="$2" template_commands="$3"
  local manifest="$project_root/agentes/.init-manifest.json"
  mkdir -p "$project_root/agentes"

  local rel local_path
  local -a rels=() hashes=()
  while IFS= read -r rel; do
    local_path="$project_root/$rel"
    [[ -f "$local_path" ]] || continue
    rels+=("$rel")
    hashes+=("$(sha256_of "$local_path")")
  done < <(tracked_files "$template_agentes" "$template_commands")

  {
    echo "{"
    echo "  \"generatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"files\": {"
    local i last=$(( ${#rels[@]} - 1 ))
    for i in "${!rels[@]}"; do
      if [[ "$i" -eq "$last" ]]; then
        echo "    \"$(json_escape "${rels[$i]}")\": \"${hashes[$i]}\""
      else
        echo "    \"$(json_escape "${rels[$i]}")\": \"${hashes[$i]}\","
      fi
    done
    echo "  }"
    echo "}"
  } > "$manifest"
}

cmd_apply() {
  local project_root="$1" template_agentes="$2" template_commands="$3"
  local manifest="$project_root/agentes/.init-manifest.json"

  if [[ ! -f "$manifest" ]]; then
    echo "NEED_FULL_REINSTALL"
    return 2
  fi

  local rel tpl_path local_path local_hash manifest_hash tpl_hash
  local n_install=0 n_overwrite=0 n_preserve=0 n_conflict=0
  local -a conflicts=()
  # Baseline do manifesto novo: SEMPRE o hash do template, nunca o hash local.
  # Se usássemos o hash local aqui, um arquivo customizado (PRESERVE ou
  # CONFLICT) viraria sua própria baseline — na próxima chamada de --update,
  # "local == manifesto" bateria (os dois são o conteúdo customizado) e o
  # arquivo seria OVERWRITE'd silenciosamente, destruindo a customização sem
  # nenhum aviso. Guardar tpl_hash preserva o histórico de divergência.
  local -a new_rels=() new_hashes=()

  while IFS= read -r rel; do
    tpl_path="$(template_path_of "$rel" "$template_agentes" "$template_commands")"
    local_path="$project_root/$rel"
    tpl_hash="$(sha256_of "$tpl_path")"

    if [[ ! -f "$local_path" ]]; then
      mkdir -p "$(dirname "$local_path")"
      cp "$tpl_path" "$local_path"
      n_install=$((n_install+1))
    else
      local_hash="$(sha256_of "$local_path")"
      manifest_hash="$(manifest_get "$manifest" "$rel" || true)"

      if [[ "$local_hash" == "$manifest_hash" ]]; then
        cp "$tpl_path" "$local_path"
        n_overwrite=$((n_overwrite+1))
      elif [[ "$tpl_hash" == "$manifest_hash" ]]; then
        n_preserve=$((n_preserve+1))
      else
        cp "$tpl_path" "$local_path.new"
        conflicts+=("$rel.new")
        n_conflict=$((n_conflict+1))
      fi
    fi

    new_rels+=("$rel")
    new_hashes+=("$tpl_hash")
  done < <(tracked_files "$template_agentes" "$template_commands")

  {
    echo "{"
    echo "  \"generatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"files\": {"
    local i last=$(( ${#new_rels[@]} - 1 ))
    for i in "${!new_rels[@]}"; do
      if [[ "$i" -eq "$last" ]]; then
        echo "    \"$(json_escape "${new_rels[$i]}")\": \"${new_hashes[$i]}\""
      else
        echo "    \"$(json_escape "${new_rels[$i]}")\": \"${new_hashes[$i]}\","
      fi
    done
    echo "  }"
    echo "}"
  } > "$manifest"

  echo "INSTALLED=$n_install OVERWRITTEN=$n_overwrite PRESERVED=$n_preserve CONFLICTS=$n_conflict"
  # Guarda de contagem antes de expandir: em bash 3.2 (padrão no macOS),
  # "${conflicts[@]}" com o array vazio dispara "unbound variable" sob set -u.
  if [[ ${#conflicts[@]} -gt 0 ]]; then
    local c
    for c in "${conflicts[@]}"; do
      echo "CONFLICT: $c"
    done
  fi
}

case "${1:-}" in
  generate) cmd_generate "$2" "$3" "$4" ;;
  apply) cmd_apply "$2" "$3" "$4" ;;
  *)
    echo "Uso: init-manifest-diff.sh {generate|apply} <project_root> <template_agentes_dir> <template_commands_dir>" >&2
    exit 1
    ;;
esac
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/scripts/init-manifest-diff.sh
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/scripts/init-manifest-diff.test.sh`
Expected: só linhas `PASS` (12 no total), exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add scripts/init-manifest-diff.sh scripts/init-manifest-diff.test.sh
git commit -m "feat: init-manifest-diff.sh — manifesto + merge inteligente do --update"
```

---

### Task 13: Liga `--update` ao instalador

**Files:**
- Modify: `/Users/bruno.andrade/.claude/skills/init-project/SKILL.md`
- Test: `/private/tmp/claude-502/init-project-update.test.sh` (fixture temporária, fora do repo)

**Interfaces:**
- Consumes: `agentes-pipeline/scripts/init-manifest-diff.sh` (Task 12).
- Produces: comportamento final de `/init-project --update`.

- [ ] **Step 1: Escrever o teste que falha**

```bash
cat > /tmp/init-project-update.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

TOOL="$HOME/agentes-pipeline/scripts/init-manifest-diff.sh"
TPL_A="$HOME/agentes-pipeline/agentes"
TPL_C="$HOME/agentes-pipeline/commands"
PROJ="$FIXTURE/project"

# Simula uma instalação já existente e sem customizações
mkdir -p "$PROJ/.claude/commands"
cp -R "$TPL_A" "$PROJ/agentes"
cp "$TPL_C"/*.md "$PROJ/.claude/commands/"
bash "$TOOL" generate "$PROJ" "$TPL_A" "$TPL_C"

# Simula o que o SKILL.md agora instrui pra --update: chamar apply
summary="$(bash "$TOOL" apply "$PROJ" "$TPL_A" "$TPL_C")"

fail=0
if echo "$summary" | grep -qE 'INSTALLED=[0-9]+ OVERWRITTEN=[0-9]+ PRESERVED=[0-9]+ CONFLICTS=0'; then
  echo "PASS: --update num projeto sem customizações não gera conflito"
else
  echo "FAIL: resumo inesperado: $summary"
  fail=1
fi
[[ -f "$PROJ/agentes/.init-manifest.json" ]] && echo "PASS: manifesto presente após update" || { echo "FAIL: manifesto ausente"; fail=1; }

exit $fail
EOF
chmod +x /tmp/init-project-update.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /tmp/init-project-update.test.sh`
Expected: já deve passar tecnicamente (a Task 12 já funciona isoladamente) —
rode e confirme; se passar de cara, o gap real está em o `SKILL.md` do
instalador ainda não *chamar* o script em `--update`. Continue para o Step 3
de qualquer forma: o teste de verdade desta task é a leitura manual do
`SKILL.md` (Step 4) confirmando que ele referencia `init-manifest-diff.sh`.

```bash
grep -q 'init-manifest-diff.sh' "$HOME/.claude/skills/init-project/SKILL.md" && echo "PASS" || echo "FAIL: SKILL.md ainda não referencia o script de update"
```
Expected: `FAIL` antes da edição.

- [ ] **Step 3: Editar `~/.claude/skills/init-project/SKILL.md`**

Substituir o passo 5 ("Se já existir e a flag `--update` foi passada...",
escrito como placeholder na Task 4) por:

```markdown
5. **Se já existir e a flag `--update` foi passada:**
   1. Rode:
      ```bash
      bash ~/agentes-pipeline/scripts/init-manifest-diff.sh apply \
        "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands
      ```
   2. Se a saída for exatamente `NEED_FULL_REINSTALL` (exit code 2): não há
      manifesto ainda (projeto instalado antes desta funcionalidade existir).
      Caia automaticamente no comportamento do passo 4 (backup completo +
      reinstala tudo) e, ao final dele, rode
      `bash ~/agentes-pipeline/scripts/init-manifest-diff.sh generate "$(pwd)" ~/agentes-pipeline/agentes ~/agentes-pipeline/commands`
      pra criar o manifesto inicial.
   3. Caso contrário, relate ao Bruno o resumo impresso pelo script
      (`INSTALLED=`, `OVERWRITTEN=`, `PRESERVED=`, `CONFLICTS=`) e, se houver
      conflitos, liste cada arquivo `.new` gerado e explique que ele precisa
      revisar manualmente (comparar `<arquivo>` com `<arquivo>.new` e decidir
      o que manter).
   4. `agentes/CONTEXTO.md`, `agentes/TEAM.md` e `agentes/.init-manifest.json`
      nunca são tocados por este fluxo — são dados do projeto, não do
      template.
```

- [ ] **Step 4: Confirmar a edição**

Run: `grep -q 'init-manifest-diff.sh' "$HOME/.claude/skills/init-project/SKILL.md" && echo PASS || echo FAIL`
Expected: `PASS`.

- [ ] **Step 5: Rodar o teste end-to-end e confirmar que passa**

Run: `bash /tmp/init-project-update.test.sh`
Expected: 2 linhas `PASS`, exit code 0.

- [ ] **Step 6: Commit (só o que está dentro do repo)**

O `SKILL.md` fica fora do repositório; nada novo para commitar em
`agentes-pipeline` nesta task além do que a Task 12 já commitou. Confirme:

```bash
cd /Users/bruno.andrade/agentes-pipeline
git status --short
```
Expected: nenhuma mudança pendente.

---

### Task 14: Paridade Gemini — TEAM.md/CONTEXTO.md lidos pelo skill principal + regras de contexto/modelo

Achado da revisão final de branch inteira (não é desvio de execução — as
Tasks 5, 9 e 10 escoparam essas regras só para o lado Claude): o skill
`gemini/skills/orquestrador/SKILL.md` nunca lê `agentes/TEAM.md` para
pré-marcar o menu (ao contrário de `commands/orquestrador.md`), nunca lê
`agentes/CONTEXTO.md` como pano de fundo, e não tem equivalente às regras de
realimentação de contexto (Task 9) nem de subagentes/escolha de modelo (Task
10). Esta task fecha essa paridade.

**Files:**
- Modify: `agentes-pipeline/gemini/skills/orquestrador/SKILL.md`
- Test: `agentes-pipeline/tests/gemini-orquestrador-paridade.test.sh`

**Interfaces:**
- Consumes: nenhuma.
- Produces: nenhuma referência viva a "não lê TEAM.md/CONTEXTO.md" — o skill
  principal Gemini passa a ter paridade de comportamento com
  `commands/orquestrador.md` (Task 1) e as regras das Tasks 9/10.

- [ ] **Step 1: Escrever o teste que falha**

```bash
mkdir -p /Users/bruno.andrade/agentes-pipeline/tests
cat > /Users/bruno.andrade/agentes-pipeline/tests/gemini-orquestrador-paridade.test.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$ROOT/gemini/skills/orquestrador/SKILL.md"
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

check 'agentes/TEAM.md' "lê TEAM.md para pré-selecionar o menu"
check 'agentes/CONTEXTO.md' "lê CONTEXTO.md como pano de fundo"
check 'Atualização de contexto sugerida' "instrução de realimentação de contexto presente"
check 'pergunta.*antes de gravar\|antes de gravar' "confirmação antes de gravar em CONTEXTO.md"
check 'subagentes' "menciona disparo de subagentes próprios"

exit $fail
EOF
chmod +x /Users/bruno.andrade/agentes-pipeline/tests/gemini-orquestrador-paridade.test.sh
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/gemini-orquestrador-paridade.test.sh`
Expected: várias linhas `FAIL`, exit code 1.

- [ ] **Step 3: Editar a seção "Como você inicia uma sessão" em `gemini/skills/orquestrador/SKILL.md`**

Adicionar, logo antes de "**Menu padrão a apresentar:**":

```markdown
Se `agentes/CONTEXTO.md` existir, leia e use como pano de fundo (nunca leia
o `CONTEXTO.md` de outro projeto). Se `agentes/TEAM.md` existir, use como
pré-seleção padrão do menu de etapas abaixo, em vez do padrão fixo.
```

- [ ] **Step 4: Editar a seção "Comportamento durante o pipeline"**

Acrescentar dois itens à lista existente:

```markdown
- Ao disparar cada subagente, peça que termine a resposta com uma seção
  opcional "Atualização de contexto sugerida" se aprender algo que muda o
  entendimento do projeto; ao final da sessão, consolide essas sugestões e
  pergunta ao usuário antes de gravar em `agentes/CONTEXTO.md` — nunca grava
  silenciosamente.
- Qualquer agente pode disparar subagentes próprios para paralelizar partes
  do trabalho. Modelo padrão: o mesmo do Orquestrador. Escale para um modelo
  mais capaz quando perceber complexidade real (refatoração ampla, lógica
  ambígua, código security-sensitive).
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash /Users/bruno.andrade/agentes-pipeline/tests/gemini-orquestrador-paridade.test.sh`
Expected: 5 linhas `PASS`, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/bruno.andrade/agentes-pipeline
git add gemini/skills/orquestrador/SKILL.md tests/gemini-orquestrador-paridade.test.sh
git commit -m "feat: fecha paridade Gemini — TEAM.md/CONTEXTO.md lidos pelo skill principal + regras de contexto/modelo"
```

**Nota pós-revisão (fechamento do Important #2 da revisão final de branch
inteira):** o revisor de task apontou que a ressalva de fork de
`agentes/PIPELINE.md` ("o override de modelo não funciona ao disparar um
*fork*") não tinha equivalente no texto Gemini acima. Como "fork" é um
`subagent_type` específico da ferramenta Agent do Claude Code — e o plugin
Superpowers para Antigravity é um port externo cujo mecanismo interno de
subagentes não é documentado neste repositório — não é possível confirmar se
existe uma variante equivalente do lado Gemini. Em vez de assumir a mecânica
exata do Claude ou descartar a ressalva, foi adicionada uma frase genérica ao
item de subagentes/modelo do Step 4:

```markdown
**Ressalva:** se a ferramenta de subagentes usada tiver uma variante que
sempre herda o modelo de quem a disparou (independente do que for pedido), a
escalação de modelo não se aplica a essa variante — só a subagentes
"frescos".
```

E um sexto `check` foi adicionado ao teste (`'sempre herda o modelo'`),
elevando o Step 5 para 6 linhas `PASS`, exit code 0. Suíte completa do
repositório re-executada após a mudança — todos os testes continuam
passando.

---

## Verificação final (depois da Task 14)

Rodar todos os testes do repositório em sequência, do início ao fim, e
confirmar que todos ainda passam juntos (nenhuma task quebrou uma anterior):

```bash
cd /Users/bruno.andrade/agentes-pipeline
for t in $(find . -name '*.test.sh' | sort); do
  echo "== $t =="
  bash "$t" || { echo "QUEBROU: $t"; exit 1; }
done
echo "Todos os testes passaram."
```
