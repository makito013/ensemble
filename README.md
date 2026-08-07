# Ensemble

> Nome interno do projeto / pasta local esperada pelos scripts de instalação:
> `agentes-pipeline` (não precisa bater com o nome do repositório no GitHub —
> veja o passo de clone abaixo).

Fonte-da-verdade portátil do pipeline de desenvolvimento multi-agente com **11 agentes**:
Orquestrador, Analista, PO, Arquiteto, BDD, Designer, TL, Dev, QA, Revisor e Segurança.

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

# 2. Rode o instalador da sua plataforma. Ele linka o repo em
#    ~/agentes-pipeline (se você clonou em outro lugar), linka o skill
#    de instalação em ~/.claude/skills/init-project, e deixa pronto o
#    plugin Superpowers-Antigravity (útil se você também usar
#    Antigravity/Gemini CLI).
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

Pronto — o projeto agora tem `./.agents/` (as 11 personas, oculta — o
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
│   ├── ARQUITETO.md
│   ├── BDD.md
│   ├── DESIGNER.md
│   ├── DEV.md
│   ├── ORQUESTRADOR.md
│   ├── PIPELINE.md
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
└── gemini/                 ← formato Antigravity / Gemini CLI
    ├── README.md           ← instruções específicas do Antigravity
    └── skills/
        ├── orquestrador/SKILL.md
        ├── analista/SKILL.md
        ├── po/SKILL.md
        ├── arquiteto/SKILL.md
        ├── bdd/SKILL.md
        ├── designer/SKILL.md
        ├── tl/SKILL.md
        ├── dev/SKILL.md
        ├── qa/SKILL.md
        ├── revisor/SKILL.md
        └── seguranca/SKILL.md
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

### Perfis rápidos

| Código | Perfil | Etapas |
|--------|--------|--------|
| `[P]` | Projeto pessoal/protótipo | 1, 7, 9 |
| `[F]` | Feature simples | 1, 2, 6, 7, 9 |
| `[U]` | Feature com UI | 1, 2, 3, 5, 6, 7, 9 |
| `[T]` | Produção com testes | 1, 2, 3, 4, 6, 7, 8, 9 |
| `[S]` | Produção completa | todas (1 ao 10) |
| `[B1]` | Bug simples | 1, 7, 9 |
| `[B2]` | Bug complexo | 1, 6, 7, 8, 9 |
| `[B3]` | Bug de segurança | 1, 6, 7, 8, 9, 10 |

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

# Antigravity (sobrescreve):
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/
```

## Aprendizado por feedback

Durante uma sessão de `/orquestrador`, se o Bruno corrigir o comportamento
de um agente ("sempre faça X", "nunca faça Y"), o Orquestrador identifica
isso como candidata a regra de aprendizado e, no resumo final, pergunta se
deve gravar como regra **local** (só este projeto, seção `## Aprendizados`
em `.agents/<PERSONA>.md`) ou **global** (fica pendente em
`.agents/.aprendizados-globais-pendentes.md` até ser sincronizada com o
repo-fonte). Esse mecanismo de detecção/decisão funciona igual nas duas
ferramentas — Claude Code e Antigravity —, mas o comando `/aprendizados-sync`
descrito abaixo (o que de fato aplica as pendências globais nas
personas-fonte) só existe no lado Claude Code, rodando aqui neste repo.

Também vale notar: os loops de retrabalho (QA/Revisor reprova → volta pro
Dev) têm um teto de 2 voltas por fase — se a 2ª tentativa também falhar, o
Orquestrador não dispara uma 3ª automaticamente, escala a decisão ao Bruno
(e escala imediatamente, sem esperar a 2ª volta, se a reprovação repetir o
mesmo motivo da 1ª).

Para aplicar as pendências globais de um projeto às personas-fonte deste
repo, rode (aqui no repo-fonte):

```bash
/aprendizados-sync /caminho/do/projeto
```

Ele apresenta cada regra pendente para aprovação antes de gravar em
`agentes/<PERSONA>.md` e `gemini/skills/<persona>/SKILL.md`.
