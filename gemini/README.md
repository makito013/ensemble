# Pipeline de Agentes — Antigravity / Gemini CLI

Este diretório contém os **skills** do pipeline de desenvolvimento multi-agente
para o **Antigravity (Google Gemini CLI)**. É a versão paralela à pasta `agentes/`
(que é para Claude/Claude Code), mas no formato nativo do Antigravity.

> **Pré-requisito:** Antes de instalar os skills do pipeline, certifique-se de ter
> o Antigravity CLI e o plugin **Superpowers** instalados na sua máquina.
> Veja a seção [Pré-requisitos](#pré-requisitos) abaixo.

## Estrutura

```
gemini/
└── skills/
    ├── orquestrador/   → etapa 0 — ponto de entrada de toda solicitação
    │   └── SKILL.md
    ├── analista/       → etapa 1 — interpreta e estrutura o que foi pedido
    │   └── SKILL.md
    ├── po/             → etapa 2 — refina requisitos como Product Owner
    │   └── SKILL.md
    ├── arquiteto/      → etapa 3 — planeja arquitetura do sistema
    │   └── SKILL.md
    ├── bdd/            → etapa 4 — escreve cenários Gherkin
    │   └── SKILL.md
    ├── designer/       → etapa 5 — propõe UX/UI (só se houver interface)
    │   └── SKILL.md
    ├── tl/             → etapa 6 — planeja implementação técnica
    │   └── SKILL.md
    ├── dev/            → etapa 7 — implementa o código
    │   └── SKILL.md
    ├── qa/             → etapa 8 — cria e executa testes
    │   └── SKILL.md
    ├── revisor/        → etapa 9 — revisa o que foi pedido vs. entregue
    │   └── SKILL.md
    └── seguranca/      → etapa 10 — auditoria de segurança (OWASP)
        └── SKILL.md
```

## Pré-requisitos

Antes de usar os skills deste pipeline, você precisa ter instalado:

### 1. Antigravity CLI (`agy`)

O Antigravity é o CLI oficial do Google para desenvolvimento com IA (sucessor do Gemini CLI).
Instale via npm:

```bash
npm install -g @google/antigravity
```

Verifique a instalação:

```bash
agy --version
```

> ⚠️ O Gemini CLI foi descontinuado em junho/2026. Use sempre o `agy` (Antigravity CLI).

### 2. Plugin Superpowers para Antigravity

O **Superpowers** é um plugin que adiciona capacidades avançadas ao Antigravity:
- ✅ Execução paralela de sub-agentes
- ✅ Fluxo estruturado de brainstorming → planejamento → execução
- ✅ Guardrails que impedem o agente de pular etapas
- ✅ Coordenação entre múltiplos agentes simultâneos

Instale via Git na pasta de config global do Antigravity:

```bash
git clone https://github.com/roundpilot/superpowers-antigravity \
  ~/.gemini/config/plugins/superpowers
```

Ou, se houver um gerenciador de plugins do `agy`:

```bash
agy plugin install superpowers
```

Após instalar, verifique se o plugin está ativo:

```bash
agy plugins list
```

> 💡 **Por que o Superpowers é importante?**  
> Os skills deste pipeline (Orquestrador, Dev, TL, etc.) se beneficiam diretamente  
> da capacidade de sub-agentes paralelos do Superpowers. Sem ele, o pipeline funciona  
> em modo sequencial — com ele, etapas independentes rodam em paralelo automaticamente.

---

## Como instalar num projeto novo

### Opção 1 — Copiar manualmente

```bash
# Na raiz do projeto destino:
mkdir -p .agents
cp -R ~/agentes-pipeline/gemini/skills .agents/
```

O Antigravity descobre skills automaticamente em `.agents/skills/` na raiz do projeto.

### Opção 2 — Via comando /init-project (lado Claude, se instalado no mesmo repositório)

Se este mesmo repositório também usa o pipeline no formato Claude, rodar
`/init-project` lá também deixa os skills Gemini disponíveis em
`.agents/skills/` (ver Opção 1 acima para instalação direta).

### Opção 3 — Symlink (para quem quer sempre a versão mais atual)

```bash
ln -s ~/agentes-pipeline/gemini/skills .agents/skills
```

> 💡 Se o projeto já tiver um `.gitignore`, considere adicionar uma
> entrada `.agents/` nele — a pasta guarda dados/skills locais da
> ferramenta, não costuma fazer sentido versionar. Diferente do lado
> Claude (`/init-project`), não há automação aqui: é uma sugestão manual.

## Como usar

Após instalar os skills no projeto, acione o Orquestrador com qualquer tarefa:

```
Orquestrador: quero adicionar autenticação JWT ao projeto
```

ou com perfil rápido já definido:

```
Orquestrador: [F] refatorar o módulo de pagamentos
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

## Diferença entre `gemini/` e `agentes/`

| | `agentes/` | `gemini/skills/` |
|-|------------|-----------------|
| **Para** | Claude / Claude Code | Antigravity (Gemini CLI) |
| **Formato** | `.md` planos por agente | `SKILL.md` com frontmatter YAML |
| **Ativação** | Prefixo manual (`Orquestrador: ...`) | Auto-descoberta pelo Antigravity |
| **Gatilho** | `name:` no frontmatter YAML |
| **Localização no projeto** | `.agents/` (raiz) | `.agents/skills/` |

> As personas Claude e os skills Gemini/Antigravity compartilham a mesma
> pasta oculta `.agents/` no projeto instalado — as personas ficam na raiz
> (`.agents/PIPELINE.md`, `.agents/DEV.md`, etc.) e os skills Gemini em
> `.agents/skills/`.

## Sincronizar em outra máquina

Ordem de setup completo numa máquina nova:

```bash
# 1. Instalar o Antigravity CLI
npm install -g @google/antigravity

# 2. Instalar o plugin Superpowers
git clone https://github.com/roundpilot/superpowers-antigravity \
  ~/.gemini/config/plugins/superpowers

# 3. Clonar este repositório de agentes
git clone <url-deste-repo> ~/agentes-pipeline

# 4. Instalar os skills num projeto
mkdir -p /caminho/do/projeto/.agents
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/
```

Pronto — abra o `agy` na pasta do projeto e acione o Orquestrador.
