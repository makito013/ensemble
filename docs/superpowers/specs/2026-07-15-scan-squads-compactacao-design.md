# Scan automático, squads alternativos e compactação de contexto

Data: 2026-07-15
Repositório: `agentes-pipeline` (fonte dos templates `agentes/`, `squads/` e `gemini/skills/`)

## Objetivo

Trazer 3 ideias observadas em ferramentas concorrentes (Compozy, AIOX Core)
pro pipeline próprio, sem virar um binário standalone nem depender de
roteamento multi-CLI (fora de escopo — exigiria reescrever a arquitetura
inteira, ver conversa que originou este spec):

1. **Scan automático de codebase** — hoje `agentes/CONTEXTO.md` só é
   gerado/atualizado via `/orquestrador-init` manual. Passa a disparar
   sozinho quando necessário.
2. **Squads alternativos** — hoje o pipeline só sabe rodar um time fixo de
   10 personas de desenvolvimento. Passa a suportar times alternativos
   (ex: marketing) instaláveis lado a lado, com consulta cruzada entre eles.
3. **Compactação automática de `CONTEXTO.md`** — hoje o arquivo só cresce
   (contexto novo entra via confirmação explícita do Bruno, nunca é revisto
   pra trás). Passa a se auto-compactar por tamanho, sem perder informação
   necessária pra uma sessão futura continuar o trabalho.

**Fora de escopo deste spec:** roteamento entre múltiplos CLIs/modelos de IA
e empacotamento como binário standalone — ambos exigiriam o pipeline deixar
de viver dentro do Claude Code (via `Agent`/`Task`) e virar um orquestrador
externo, o que é uma reescrita de arquitetura, não um incremento.

---

## A. Scan automático de codebase (staleness-based)

### Gatilho

`commands/orquestrador.md` passa a checar, antes de montar o menu de etapas:

1. **`agentes/CONTEXTO.md` não existe** → dispara automaticamente a mesma
   mecânica de scan do `/orquestrador-init` (subagente isolado, mesma lógica
   de fusão descrita em `PIPELINE.md`/seção D do spec de 2026-07-03), sem
   perguntar. Avisa o Bruno no início da resposta: *"Não encontrei
   CONTEXTO.md, gerei um antes de começar."*
2. **`agentes/CONTEXTO.md` existe** → roda `agentes/scripts/check-staleness.sh`
   (novo script, mesmo estilo de `detect-projects.sh`):
   - Extrai o hash mais recente registrado na seção 7 (Log de atualizações)
     do `CONTEXTO.md`.
   - Roda `git rev-list --count <hash>..HEAD` no projeto.
   - Se o projeto não tiver `.git`, ou o log não tiver nenhum hash registrado
     ainda (formato antigo), o script retorna "não aplicável" — sem quebrar,
     sem forçar refresh.
   - Se a contagem passar de **15 commits** (default; ajustável por uma
     variável no topo do script), considera desatualizado e dispara o mesmo
     subagente de refresh do item 1, com fusão (nunca sobrescreve cego).

### Mudança de formato no Log de atualizações

Cada entrada passa a incluir o hash do HEAD no momento do scan:

```
- 2026-07-15 — init — <resumo> (HEAD: abc1234)
```

Entradas antigas sem hash continuam válidas (só não participam da checagem
de staleness até a próxima atualização gravar um hash).

### O que não muda

`/orquestrador-init` continua existindo como comando manual, pra forçar
refresh imediato sem esperar o limite de staleness.

### Escopo por squad

Esta checagem roda sempre sobre o `CONTEXTO.md` do squad que está sendo
usado na sessão: `agentes/CONTEXTO.md` quando disparada por
`commands/orquestrador.md` (squad ativo), ou
`agentes/squads/<nome>/CONTEXTO.md` quando disparada por `commands/squad.md`
(seção B) — mesma lógica, escopo diferente. A checagem de compactação
(seção C) segue a mesma regra de escopo.

---

## B. Squads alternativos

### Layout de arquivos

**No repo-fonte (`agentes-pipeline`):**

```
agentes-pipeline/
├── agentes/          ← squad padrão (dev), como já existe hoje
└── squads/
    └── marketing/
        ├── PIPELINE.md
        ├── ESTRATEGISTA.md
        ├── COPYWRITER.md
        ├── DESIGNER-CAMPANHA.md
        └── ANALISTA-METRICAS.md
```

**Num projeto instalado:**

```
<projeto>/agentes/
├── ANALISTA.md, PO.md, ... PIPELINE.md   ← squad ATIVO (governa /orquestrador)
├── CONTEXTO.md, TEAM.md
└── squads/
    └── marketing/
        ├── PIPELINE.md, CONTEXTO.md, TEAM.md   ← squad instalado, não-ativo
        └── ESTRATEGISTA.md, COPYWRITER.md, ...
```

- O squad ativo vive em `agentes/*.md` direto — por padrão continua sendo o
  de dev, exatamente como hoje. Zero disrupção pra projetos já instalados.
- Squads extras (não-ativos) ficam em `agentes/squads/<nome>/`, cada um com
  seu próprio `CONTEXTO.md`/`TEAM.md` (a compactação da seção C se aplica
  a cada um independentemente).
- Trocar qual squad é o ativo = mover arquivos entre `agentes/*.md` e
  `agentes/squads/<nome-antigo>/` (swap, não reinstalação).

### Mudança de arquitetura: Orquestrador agnóstico de squad

Hoje `agentes/ORQUESTRADOR.md` tem o menu das 10 etapas escrito inline no
texto. Pra squads funcionarem sem duplicar a lógica de orquestração por
squad, o menu passa a ser montado a partir da tabela de etapas de qualquer
`PIPELINE.md` instalado como ativo — o Orquestrador não muda seu
comportamento, só para de hardcodar os nomes das 10 personas de dev no texto
do menu.

### Instalação

`/init-project` ganha dois modos novos, além do atual (sem flag = squad dev,
comportamento de hoje):

- `--squad <nome>` — instala `squads/<nome>/` como o squad **ativo** do
  projeto (`agentes/*.md`), no lugar do squad de dev. Se o projeto já tiver
  um squad ativo diferente de `<nome>`, faz o swap descrito em "Layout de
  arquivos": move o squad ativo atual para `agentes/squads/<nome-atual>/`
  antes de instalar `<nome>` como o novo ativo — nunca sobrescreve o squad
  atual sem preservá-lo. Se `<nome>` já for o ativo, comporta-se como um
  update normal (mesma lógica de `--update` do fluxo já existente).
- `--add-squad <nome>` — instala `squads/<nome>/` em
  `agentes/squads/<nome>/` como squad **extra**, sem trocar o ativo.

`TEMPLATE_DIR` do skill `init-project` deixa de ser fixo em
`~/agentes-pipeline/agentes/` e passa a resolver com base na flag:
`~/agentes-pipeline/agentes/` (default) ou
`~/agentes-pipeline/squads/<nome>/` (com `--squad`/`--add-squad`).

### Consulta entre squads (duas formas, as duas nesta entrega)

1. **Comando manual direto** — novo `commands/squad.md`:
   `/squad marketing "revise este texto de onboarding"` roda uma sessão do
   Orquestrador escopada só ao squad instalado em `agentes/squads/marketing/`
   (mesma mecânica do `/orquestrador`, apontando pro `PIPELINE.md` de dentro
   de `squads/marketing/`), sem trocar o squad ativo do projeto.

2. **Consulta automática de dentro do pipeline ativo** — regra transversal
   nova em `agentes/PIPELINE.md` (mesmo padrão da seção já existente
   "Subagentes e escolha de modelo"): qualquer persona ativa pode, durante
   seu próprio trabalho, disparar um subagente usando uma persona de um squad
   instalado em `agentes/squads/`, como consultoria pontual — sem pedir
   permissão antes (é leitura/opinião, não grava nada no squad ativo nem no
   consultado). O Bruno pode pedir isso explicitamente na tarefa (ex: "implementa
   isso e confirma o texto do botão com o Copywriter de marketing") ou a
   persona pode decidir por conta própria que a consulta é necessária.

### Squad de exemplo: marketing (prova de conceito)

4 personas, cobrindo um pipeline de campanha enxuto:

| # | Etapa | Agente | Obrigatório? |
|---|-------|--------|--------------|
| 1 | Estratégia — interpreta o pedido, define público/objetivo | Estrategista | Sempre |
| 2 | Redação do conteúdo/textos | Copywriter | Sempre |
| 3 | Direção visual/formato da campanha | Designer de Campanha | Opcional |
| 4 | Define métricas de sucesso, checa contra o objetivo do Estrategista | Analista de Métricas | Opcional |

Mesma mecânica de menu configurável por sessão que o squad de dev já tem
(sem perfis rápidos `[P]`/`[F]`/etc. nesta primeira versão — só o menu
completo).

---

## C. Compactação automática de `CONTEXTO.md`

### Gatilho

Tamanho do arquivo. Mesmo ponto de checagem e mesmo escopo por squad da
seção A (ver "Escopo por squad"): se o `CONTEXTO.md` relevante passar de
**200 linhas** (default, ajustável), dispara a compactação antes de
prosseguir.

### Quem compacta

Subagente dedicado (`subagent_type: general-purpose`), disparado pelo
Orquestrador com mandato único: *"condense este CONTEXTO.md sem perder
nenhuma informação necessária para que uma sessão futura retome o trabalho
de onde parou."*

### O que é condensado

- **Seções 1-6** (Visão geral, Arquitetura, Convenções, Decisões,
  Integrações, Gotchas) — corta verbosidade e redundância acumulada, mas
  preserva todo fato, decisão e nome próprio citado. Edição de estilo, não
  resumo com perda.
- **Seção 7 (Log de atualizações)** — entradas mais antigas que as últimas
  10 sessões são condensadas num único parágrafo "Resumo histórico" no topo
  da seção; as 10 mais recentes continuam linha a linha, granulares (inclusive
  com o hash de HEAD da seção A, quando presente).

### Escrita

Automática, sem perguntar ao Bruno (compactação não decide conteúdo novo,
só condensa o que já foi aprovado — a regra de "nunca grava silenciosamente"
continua valendo só para conteúdo novo sugerido pelos subagentes de pipeline,
seção G do spec de 2026-07-03). Antes de sobrescrever, salva a versão
anterior como `agentes/CONTEXTO.md.bak` (sobrescrevendo o backup anterior a
cada compactação) — rede de segurança sem adicionar fricção ao fluxo.

Ao final, o Orquestrador avisa em uma linha: *"Compactei o CONTEXTO.md (de X
para Y linhas), backup em CONTEXTO.md.bak."*

---

## Ordem de implementação

1. Squads (B) — maior mudança estrutural, tudo mais depende do Orquestrador
   já ser agnóstico de squad:
   1. Generalizar `ORQUESTRADOR.md` (menu a partir do `PIPELINE.md` instalado)
   2. Layout `squads/marketing/` no repo-fonte + personas de prova de conceito
   3. `--squad`/`--add-squad` em `init-project`
   4. `commands/squad.md`
   5. Regra transversal de consulta cruzada em `PIPELINE.md`
2. Scan automático (A) — depende só do Orquestrador existente:
   1. `agentes/scripts/check-staleness.sh`
   2. Mudança de formato do log (hash de HEAD)
   3. Checagem em `commands/orquestrador.md`
3. Compactação (C) — independente das outras duas, pode vir em paralelo com A:
   1. Checagem de tamanho em `commands/orquestrador.md`
   2. Subagente de compactação + regra do `.bak`
4. Atualização de documentação (`README.md`, `AGENTS.md`, `PIPELINE.md`)
   cobrindo as 3 novidades.
