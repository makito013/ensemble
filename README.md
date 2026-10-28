# Ensemble

> Nome interno do projeto / pasta local esperada pelos scripts de instalação:
> `agentes-pipeline` (não precisa bater com o nome do repositório no GitHub —
> veja o passo de clone abaixo).

Fonte-da-verdade portátil do pipeline de desenvolvimento multi-agente com **13 agentes**:
Orquestrador, Analista, PO, Arquiteto, BDD, Designer, TL, Antecipador, Refinador, Dev, QA, Revisor e Segurança.

Este repositório é a **única cópia canônica** do pipeline — disponível em dois formatos,
um para cada ferramenta de IA:

| Pasta | Para | Formato |
|-------|------|---------|
| `agentes/` | Claude / Claude Code | `.md` planos por agente |
| `gemini/skills/` | **Antigravity (Gemini CLI)** | `SKILL.md` com frontmatter YAML |

> ⚠️ **Antes de usar:** cada ferramenta precisa do seu plugin **Superpowers** instalado.
> Veja a seção [Pré-requisitos por ferramenta](#pré-requisitos-por-ferramenta) abaixo.

## Setup — usuário novo (Claude Code)

Se você acabou de receber este repositório e usa Claude Code, estes são os
**únicos passos** necessários para sair do zero funcionando. Rode nesta
ordem:

```bash
# 1. Clone o repositório (qualquer pasta — não precisa mais ser um path fixo)
git clone <url-deste-repo> ~/agentes-pipeline
cd ~/agentes-pipeline

# 2. Rode o instalador da sua plataforma. Ele pergunta quais IAs você usa
#    nesta máquina, linka o repo em ~/agentes-pipeline (se você clonou em
#    outro lugar), linka o skill de instalação em
#    ~/.claude/skills/init-project, e deixa pronto o plugin
#    Superpowers-Antigravity (só se você selecionar Antigravity).
./install.sh          # Mac/Linux
.\install.ps1          # Windows (PowerShell)

# 3. Instale o plugin Superpowers do Claude Code (dentro do Claude Code —
#    não dá pra automatizar isso via shell)
/plugin install superpowers@claude-plugins-official

# 4. Dentro do projeto onde você quer os agentes, rode /init-project
cd /caminho/do/seu/projeto
/init-project
```

> Se `.\install.ps1` falhar com erro de política de execução, rode
> `powershell -ExecutionPolicy Bypass -File .\install.ps1` em vez disso.

Pronto — o projeto agora tem `./.agents/` (as 21 personas, oculta — o
instalador acrescenta uma entrada `.agents/` no `.gitignore` do projeto se já
existir um; projetos que já tinham a antiga `./agentes/` visível são migrados
automaticamente na próxima vez que `/init-project` rodar),
`./.claude/commands/orquestrador*.md` e `./.claude/skills/coding-standards/`
(convenção de código sempre em inglês, ativa em qualquer sessão do Claude Code
neste projeto — com ou sem o pipeline rodando). Para usar:

```
/orquestrador quero adicionar autenticação JWT ao projeto
```

Quer usar num segundo projeto? Repita só o passo 4 — os passos 1-3 são
únicos por máquina. Para atualizar o pipeline depois de um `git pull` num
projeto já instalado, veja [Atualizando o pipeline](#atualizando-o-pipeline).
Já rodou o instalador antes e só quer confirmar que os links continuam
corretos? Rode `./install.sh` ou `.\install.ps1` de novo — é seguro, não
duplica nada, só reporta o que já está certo. Se você mover a pasta do
repo depois de instalado, o link antigo fica quebrado — apague
`~/agentes-pipeline` (e o link do skill, se também tiver mudado de perfil)
antes de rodar o instalador de novo.

Usa mais de um perfil de configuração do Claude Code na mesma máquina (ex.:
`~/.claude-work`, além do `~/.claude` padrão — veja
[`claude/continuidade/`](claude/continuidade/README.md))? Rode o instalador
de novo passando `--target`/`-Target` pra cada perfil adicional:

```bash
./install.sh --target ~/.claude-work          # Mac/Linux
.\install.ps1 -Target ~/.claude-work           # Windows (PowerShell)
```

Usa Antigravity/Gemini CLI em vez de Claude Code? Veja
[Pré-requisitos por ferramenta](#pré-requisitos-por-ferramenta) e
[Como instalar num projeto](#como-instalar-num-projeto) abaixo.

### Quais IAs você usa (`--ai`)

Na primeira execução o instalador mostra um menu perguntando quais IAs você
usa nesta máquina:

```
Quais IAs você usa nesta máquina?
  [x] 1) Claude Code               (sempre instalado)
  [ ] 2) Antigravity / Gemini CLI
  [ ] 3) Codex CLI (OpenAI)
  [ ] 4) Cursor
```

Claude Code está sempre incluído e não pode ser desmarcado. A resposta fica
gravada em `~/.config/agentes-pipeline/ai-targets.json` e é reusada nas
execuções seguintes, então rodar o instalador de novo não repete a pergunta se
você só apertar Enter.

Para responder sem menu (scripts, CI, Dockerfile), use a flag ou a variável de
ambiente. As duas aceitam a lista separada por vírgula, em qualquer ordem, e
sempre substituem a seleção anterior por inteiro:

```bash
./install.sh --ai antigravity,cursor          # Mac/Linux
.\install.ps1 -Ai antigravity,cursor           # Windows (PowerShell)

AGENTES_PIPELINE_AI_TARGETS=claude,codex ./install.sh
```

A precedência é `--ai`/`-Ai` > `AGENTES_PIPELINE_AI_TARGETS` > menu interativo >
config já gravada. Um id desconhecido em `--ai` ou na variável de ambiente é
erro de uso (exit code 2) e nada é gravado.

**Quando não há terminal** (stdin redirecionado, pipe, CI), o instalador não
trava esperando resposta: ele usa a config gravada, ou `claude` se não houver
nenhuma, e avisa:

```
AVISO: stdin não é um terminal — usando seleção de IAs: claude (mude com --ai ou AGENTES_PIPELINE_AI_TARGETS)
```

Essa seleção decide o que o instalador faz por conta própria (o plugin
Superpowers-Antigravity só é clonado se `antigravity` estiver selecionado) e o
que o `/init-project` materializa dentro de cada projeto. O conjunto base de
personas e comandos é instalado sempre, para qualquer seleção. Detalhes de
cada adapter na seção [IAs suportadas](#ias-suportadas) abaixo.

## IAs suportadas

O instalador oferece 4 IAs para seleção (ver [Quais IAs você usa
(`--ai`)](#quais-ias-você-usa---ai) acima). `claude` está sempre incluído;
`antigravity`, `codex` e `cursor` são opcionais. Quando uma IA está
selecionada, `/init-project` materializa os adapters correspondentes dentro
do projeto:

| IA | Materializa | Onde |
|----|--------------|------|
| Claude | `.agents/` (29 arquivos: 21 personas + `PIPELINE.md` + 7 documentos sob demanda — `MODELOS.md`, `TIME-DESIGN-FLOW.md`, `PLAN-FLOW.md`, `REFINAMENTO-FLOW.md`, `QUADRO.md`, `APRENDIZADOS.md`, `TEMPLATES.md` — e os scripts em `.agents/scripts/`) + `.claude/commands/` (comandos `orquestrador*`, `time-design`) + `.claude/skills/coding-standards/` | Raiz do projeto |
| Antigravity / Gemini CLI | Cópia de `gemini/skills/` | `.agents/skills/` |
| Codex CLI (OpenAI) | Bloco delimitado (aplicado via `scripts/agents-md-block.sh`, determinístico) a partir de `codex/AGENTS-block.md` + cópia de `codex/skills/` | Bloco em `AGENTS.md` da raiz do projeto + `.codex/skills/` |
| Cursor | Cópia de `cursor/skills/` + regra `cursor/rules/coding-standards.mdc` (`alwaysApply: true`) | `.cursor/skills/` + `.cursor/rules/` |

Claude não muda de comportamento com a seleção — é a linha de base, sempre
instalada. Antigravity, Codex e Cursor recebem cada um sua própria cópia dos
skills no formato que a engine espera (`SKILL.md` com frontmatter, mais
`agents/openai.yaml` no caso do Codex).

**`coding-standards` em toda engine:** a regra de código sempre em inglês é
a única coisa sempre ativa (não depende de gatilho, diferente do pipeline).
Claude recebe `.claude/skills/coding-standards/`; Antigravity,
`gemini/skills/coding-standards/`; Codex, uma seção própria no bloco do
`AGENTS.md`; Cursor, `.cursor/rules/coding-standards.mdc` com
`alwaysApply: true`. `tests/engine-parity.test.sh` garante que o texto da
regra é o mesmo nas quatro.

> ⚠️ **Codex e `~/.codex/config.toml`:** o próprio Codex CLI grava
> automaticamente `trust_level` (por path de projeto) em
> `~/.codex/config.toml` do usuário, na primeira execução em cada projeto
> novo. Isso é comportamento nativo do Codex, não deste instalador nem do
> `/init-project` — mas vale saber que a primeira execução em projeto novo
> toca esse arquivo.

**Cobertura de comandos:** Codex e Cursor têm uma skill para cada comando do
lado Claude — `orquestrador`, `init-project`, `orquestrador-fix`,
`orquestrador-init`, `orquestrador-plan`, `orquestrador-pr`,
`orquestrador-quadro`, `orquestrador-refinar`, `orquestrador-status`,
`orquestrador-team` e `time-design` —, todas só por
invocação explícita (`$<nome>` no Codex, `/<nome>` no Cursor). Exceto
`orquestrador` e `init-project` (escritas à mão), elas são dispatchers finos
gerados por `scripts/gen-command-dispatchers.sh` a partir de `commands/*.md`:
leem o `.claude/commands/<nome>.md` instalado no projeto e seguem. Depois de
criar ou renomear um comando, rode
`bash scripts/gen-command-dispatchers.sh generate` (o teste
`scripts/gen-command-dispatchers.test.sh` falha se esquecer).
`aprendizados-sync` fica de fora de propósito: só roda no repo-fonte.

## Estrutura

```
agentes-pipeline/
├── README.md               ← este arquivo
├── AGENTS.md               ← contexto para IA sem histórico de conversa
├── install.sh              ← instalador de máquina (Mac/Linux)
├── install.ps1             ← instalador de máquina (Windows)
├── install.test.sh         ← teste automatizado de install.sh
│
├── agentes/                ← templates instalados em projetos (formato Claude)
│   ├── ANALISTA.md
│   ├── ANTECIPADOR.md      ← pre-mortem do plano (Time de Refinamento)
│   ├── ARQUITETO.md
│   ├── BDD.md
│   ├── DESIGNER.md
│   ├── DEV.md
│   ├── ORQUESTRADOR.md     ← núcleo, carregado a cada /orquestrador
│   ├── PIPELINE.md         ← núcleo
│   ├── REFINADOR.md        ← fecha o Time de Refinamento
│   ├── MODELOS.md, TIME-DESIGN-FLOW.md, PLAN-FLOW.md,
│   │   REFINAMENTO-FLOW.md, QUADRO.md,
│   │   APRENDIZADOS.md, TEMPLATES.md   ← documentos lidos só sob demanda
│   ├── scripts/            ← detect-projects.sh, pipeline-status.sh,
│   │                         review-input.sh, design-snapshot.mjs,
│   │                         board.sh (quadro), render-refinement.mjs +
│   │                         refinement-template.html (documento fixo)
│   ├── PO.md
│   ├── QA.md
│   ├── REVISOR.md
│   ├── SEGURANCA.md
│   └── TL.md
│
├── claude/                 ← skill pessoal do Claude Code (não instalado em projetos)
│   └── skills/
│       └── init-project/SKILL.md   ← linkar em ~/.claude/skills/init-project
│
├── skills/                 ← template instalado em projetos (formato Claude)
│   └── coding-standards/SKILL.md   ← copiado para ./.claude/skills/ pelo /init-project
│
├── codex/                  ← adapter Codex: AGENTS-block.md + skills/ (dispatchers)
├── cursor/                 ← adapter Cursor: skills/ (dispatchers) + rules/coding-standards.mdc
├── scripts/                ← read-ai-targets.sh, agents-md-block.sh,
│                             init-manifest-diff.sh, gen-command-dispatchers.sh
│
├── tests/                  ← suítes *.test.sh + run-all.sh (roda todas)
├── .github/workflows/      ← CI: tests/run-all.sh (Linux/macOS) e install.test.ps1 (Windows)
│
└── gemini/                 ← formato Antigravity / Gemini CLI
    ├── README.md           ← instruções específicas do Antigravity (árvore completa)
    └── skills/             ← 33 skills: pipeline, comandos auxiliares,
                              Time de Design e continuidade
```

### Testes

```bash
bash tests/run-all.sh      # roda todos os *.test.sh do repo; -v mostra a saída de cada um
```

Algumas suítes (ex.: `tests/time-design.test.sh`) conferem as cópias
**instaladas** em `./.agents/` (ignorada pelo git). Numa cópia limpa do repo,
materialize-as antes, do mesmo jeito que o CI faz:

```bash
bash scripts/init-manifest-diff.sh install "$PWD" "$PWD/agentes" "$PWD/commands" "$PWD/skills"
```

## Pré-requisitos por ferramenta

### Para Claude / Claude Code

O **Superpowers** para Claude Code impõe um fluxo estruturado ao agente:
brainstorming → planejamento → execução paralela de sub-agentes → review.

```bash
# Instalar o plugin Superpowers no Claude Code
/plugin install superpowers@claude-plugins-official
```

> 💡 Sem o Superpowers, o pipeline funciona, mas as etapas rodam de forma
> sequencial e sem guardrails de planejamento.

### Para Antigravity (Gemini CLI)

Antes de tudo, certifique-se de que o **Antigravity CLI** está instalado:

```bash
npm install -g @google/antigravity
agy --version
```

> ⚠️ O Gemini CLI foi descontinuado em junho/2026 — use o `agy` (Antigravity CLI).

O plugin **Superpowers para Antigravity** é clonado automaticamente pelo
`./install.sh` / `.\install.ps1` (veja [Setup — usuário novo](#setup--usuário-novo-claude-code)),
em `~/.gemini/config/plugins/superpowers`. Se preferir instalar manualmente:

```bash
git clone https://github.com/roundpilot/superpowers-antigravity \
  ~/.gemini/config/plugins/superpowers
# revisão fixada pelo install.sh/install.ps1 (SUPERPOWERS_ANTIGRAVITY_REF sobrescreve):
git -C ~/.gemini/config/plugins/superpowers checkout adc31f80fc2252f09b077604a483a4ead85ee554

# Ou via gerenciador de plugins (se disponível):
agy plugin install superpowers
```

O Superpowers habilita:
- ✅ Execução paralela de sub-agentes (múltiplas etapas ao mesmo tempo)
- ✅ Fluxo brainstorming → plano aprovado → execução
- ✅ Guardrails que impedem o agente de pular etapas críticas
- ✅ Coordenação de múltiplos agentes simultâneos

---

## Como instalar num projeto

### Para Claude / Claude Code

> Pressupõe o skill já linkado em `~/.claude/skills/init-project` — se for a
> primeira vez nesta máquina, veja [Setup — usuário novo](#setup--usuário-novo-claude-code) primeiro.

```bash
# Via skill (recomendado):
/init-project

# Para atualizar um projeto já instalado, sem perder customizações locais:
/init-project --update
```

### Para Antigravity (Gemini CLI)

```bash
# Copiar os skills para a pasta .agents do projeto:
mkdir -p /caminho/do/projeto/.agents
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/

# Ou como symlink (sempre atualizado):
ln -s ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/skills
```

O Antigravity descobre skills automaticamente em `.agents/skills/` na raiz do projeto.

## Como usar (ambas as ferramentas)

Após instalar, acione o Orquestrador com qualquer tarefa de desenvolvimento.

No Claude Code, via comando:

```
/orquestrador quero adicionar autenticação JWT ao projeto
```

No Antigravity/Gemini CLI, continua por prefixo de texto (skill discovery):

```
orquestrador: quero adicionar autenticação JWT ao projeto
```

Ou com perfil rápido:

```
/orquestrador [F] criar endpoint de cadastro de gateway
```

```
orquestrador: [F] criar endpoint de cadastro de gateway
```

### Como uma sessão é configurada (passo a passo)

O `/orquestrador` não despeja mais um menu de checkboxes: ele pergunta uma
coisa por vez, e passo que não se aplica nem aparece. No Claude Code cada
passo vem como pergunta de opções clicáveis (`AskUserQuestion`):

1. **Time** — perfil recomendado, duas alternativas ou "Personalizar"
   (Refinamento: PO, Arquiteto, BDD, TL · Interface e qualidade: Designer,
   QA, Revisor, Segurança).
2. **Rigor** — tier `spike` / `feature` / `critical`.
3. **Revisão** (só se o Revisor estiver no time) — quantos revisores
   independentes: 1, 3, 5 ou 7. Cada revisor é um subagente **novo e
   limpo**: não vê a conversa nem o que os outros revisores acharam, só o
   pedido, os critérios e o diff. Um verificador, também novo, junta os
   achados e tenta derrubar cada um; só o que sobrevive com evidência
   reprova.
4. **Time de Design** (só se a demanda falar de tela).
5. **Quadro** (só na primeira vez no projeto) — local ou compartilhado.
6. **Resumo** — confirmar ou voltar a um passo.

Escolhas já escritas na demanda (`/orquestrador [F] revisão 3 ...`) pulam
o passo correspondente.

### Time de Refinamento e documento de refinamento

Quando alguma etapa de planejamento (PO, Arquiteto, BDD, Designer, TL)
roda, o **Refinador** fecha o Time de Refinamento: consolida tudo em
`refinamento.json` e o script `render-refinement.mjs` preenche um
**template HTML fixo** (`refinement-template.html`) — mesmo layout em toda
tarefa:

1. Dúvidas que precisam de resposta antes do desenvolvimento
2. O que será feito · 3. Por quê · 4. Onde (arquivo, criar/alterar/remover, motivo)
5. Como (tarefas em ordem, por fase) · 6. Critérios de aceitação
7. Fora de escopo · 8. Riscos · 9. Se acontecer — decisões já autorizadas
10. Suposições · 11. Verificação · 12. Fontes

O Dev só começa depois do **gate de refinamento**: o documento renderizado,
as dúvidas bloqueantes respondidas por você (o script sai com código 3
enquanto houver alguma aberta) e sua aprovação. As respostas viram
decisões fechadas para o Dev e o "onde" vira o escopo que o Revisor
confere.

Antes do Refinador, o **Antecipador** faz o *pre-mortem* do plano: simula
a implementação tarefa a tarefa contra o código real e pergunta onde o Dev
vai travar. O que só você decide vira dúvida no gate; o que tem resposta
padrão razoável vira **contingência** ("se o endpoint devolver 404, faça
X; pare e reporte se Y"), que você aprova junto com o documento. Roda
sempre no `/orquestrador-refinar` e, no `/orquestrador`, em tier
`critical` com o TL ou quando você pede.

Com o refinamento aprovado, o desenvolvimento **segue o documento sem
perguntar**, por mais que demore ou mude de mãos: dúvida que o Dev levanta
é conferida primeiro contra as respostas e contingências, e só chega a você
o que o documento não cobre — e essa resposta é gravada no documento para
ninguém perguntar de novo.

`/orquestrador-refinar <demanda>` roda **só** o refinamento e deixa a
tarefa `pronto` no quadro; depois, você ou outro dev desenvolve com
`/orquestrador <id-da-tarefa>`, que pula o planejamento e entrega ao Dev o
refinamento e o planejamento integral anexados ao cartão.

### Quadro de tarefas (contexto descentralizado)

Cada tarefa é uma pasta com um `CARTAO.md` (status, responsável, branch,
onde mexe, critérios, decisões, log), o `refinamento.html` e o
planejamento integral. Não existe arquivo central: o quadro é calculado a
partir dos cartões, então dois devs em tarefas diferentes nunca brigam no
merge. Status: `refinando`, `pronto`, `em-andamento`, `em-revisao`,
`bloqueada`, `concluida`, `cancelada`.

- **Local (padrão):** `.agents/quadro/`, fora do git — só você vê.
- **Compartilhado (só se você quiser):** `/orquestrador-quadro compartilhar`
  move o quadro para `.agents-shared/`, uma pasta versionável. O pipeline
  nunca faz commit dela; commitar é decisão sua. Quem der pull vê o que já
  foi feito, o que está pronto para pegar e o que está em andamento.
- `/orquestrador-quadro` mostra o quadro, inclusive cartões que outros devs
  já subiram em branches ainda não mergeadas (`board.sh list --remote`).
- Ao refinar, o Orquestrador cruza o "onde" com os outros cartões
  (`board.sh related`) e avisa quando alguém já está mexendo nos mesmos
  arquivos.

### Perfis rápidos

| Código | Perfil | Etapas |
|--------|--------|--------|
| `[X]` | Trivial (typo, uma linha, config) | 7, 9 (Revisor rápido), só uma confirmação |
| `[P]` | Projeto pessoal/protótipo | 1, 7, 9 |
| `[F]` | Feature simples | 1, 2, 6, 7, 9 |
| `[U]` | Feature com UI | 1, 2, 3, 5, 6, 7, 9 |
| `[T]` | Produção com testes | 1, 2, 3, 4, 6, 7, 8, 9 |
| `[S]` | Produção completa | todas (1 ao 10) |
| `[B1]` | Bug simples | 1, 7, 9 |
| `[B2]` | Bug complexo | 1, 6, 7, 8, 9 |
| `[B3]` | Bug de segurança | 1, 6, 7, 8, 9, 10 |

Para ver o pipeline em aberto (só leitura, sem gastar o contexto do
Orquestrador): `/orquestrador-status` (Antigravity: `orquestrador-status`).
Para ver o quadro de tarefas: `/orquestrador-quadro` (Antigravity:
`orquestrador-quadro`).
Cada etapa grava a saída integral em `.agents/.pipeline-run/`, e as etapas
seguintes a recebem por caminho — é daí que a retomada após `/clear` lê.

## Sincronizar em outra máquina

Setup completo numa máquina nova:

```bash
# 1. Clonar este repositório (qualquer pasta)
git clone <url-deste-repo> ~/agentes-pipeline
cd ~/agentes-pipeline

# 2. Rodar o instalador — linka o repo, o skill init-project (Claude) e
#    deixa pronto o plugin Superpowers-Antigravity (útil se você também
#    usar Antigravity/Gemini CLI).
#    Usa mais de um perfil do Claude Code? Rode de novo com
#    --target/-Target <pasta-do-perfil> pra cada perfil adicional.
./install.sh          # Mac/Linux
.\install.ps1          # Windows (PowerShell)

# ── CLAUDE / CLAUDE CODE ──────────────────────────────────
# 3. Instalar o plugin Superpowers no Claude Code
/plugin install superpowers@claude-plugins-official

# 4. Instalar os agentes num projeto
cd /caminho/do/projeto
/init-project


# ── ANTIGRAVITY (GEMINI CLI) ──────────────────────────────
# 3. Instalar o Antigravity CLI (se ainda não tiver)
npm install -g @google/antigravity

# 4. Instalar os skills num projeto
mkdir -p /caminho/do/projeto/.agents
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/
```

## Atualizando o pipeline

Edite os arquivos em `agentes/`, `skills/` ou em `gemini/skills/` e commite.
Para reinstalar num projeto existente:

```bash
# Claude:
/init-project --update

# Claude, reinstalação completa (sem --update): faz backup integral em
# ./.agents-backups/<timestamp>/ e sobrescreve só os arquivos de template;
# dados do projeto em .agents/ (CONTEXTO.md, TEAM.md, PIPELINE-STATE.md,
# design-system/, planos/, ...) ficam no lugar.
/init-project

# Antigravity (sobrescreve):
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/
```

## Aprendizado por feedback

Durante uma sessão de `/orquestrador`, se o usuário corrigir o comportamento
de um agente ("sempre faça X", "nunca faça Y"), o Orquestrador identifica
isso como candidata a regra de aprendizado e, no resumo final, pergunta se
deve gravar como regra **local** (só este projeto, seção `## Aprendizados`
em `.agents/<PERSONA>.md`) ou **global** (fica pendente em
`.agents/.aprendizados-globais-pendentes.md` até ser sincronizada com o
repo-fonte). Esse mecanismo de detecção/decisão funciona igual nas duas
ferramentas — Claude Code e Antigravity —, mas o comando `/aprendizados-sync`
descrito abaixo (o que de fato aplica as pendências globais nas
personas-fonte) só existe no lado Claude Code, rodando aqui neste repo.

As regras **locais** sobrevivem às atualizações: `/init-project --update`
aplica a versão nova de cada persona e reinsere a seção `## Aprendizados`
local (reportado como `LEARNINGS_CARRIED:`); a reinstalação completa as
devolve a partir do backup, e a cópia das skills do Antigravity preserva as
de `.agents/skills/<persona>/SKILL.md`. Se a persona tiver outras
customizações locais além dos aprendizados, ela continua em conflito, mas o
`.new` gerado já vem com as regras locais.

Também vale notar: os loops de retrabalho (QA/Revisor reprova → volta pro
Dev) têm um teto de 2 voltas por fase — se a 2ª tentativa também falhar, o
Orquestrador não dispara uma 3ª automaticamente, escala a decisão ao usuário
(e escala imediatamente, sem esperar a 2ª volta, se a reprovação repetir o
mesmo motivo da 1ª).

Para aplicar as pendências globais de um projeto às personas-fonte deste
repo, rode (aqui no repo-fonte):

```bash
/aprendizados-sync /caminho/do/projeto
```

Ele apresenta cada regra pendente para aprovação antes de gravar em
`agentes/<PERSONA>.md` e `gemini/skills/<persona>/SKILL.md`.
