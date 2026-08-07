# Onboarding de usuário novo — só pelo README

Data: 2026-07-07
Repositório: `agentes-pipeline`

## Problema

O README descreve `/init-project` como o caminho recomendado de instalação,
mas esse skill não faz parte do repositório — hoje ele só existe como um
arquivo solto em `~/.claude/skills/init-project/SKILL.md` no ambiente do
Bruno, criado manualmente fora do controle de versão. Alguém que clone o
repositório do zero e siga só o README não tem como obter esse skill: o
passo a passo atual tem um elo faltando.

Além disso as instruções de instalação hoje estão espalhadas em três seções
parcialmente redundantes ("Pré-requisitos por ferramenta", "Como instalar
num projeto", "Sincronizar em outra máquina"), sem um único lugar linear que
alguém possa seguir de cima a baixo sem pular entre seções.

## Mudança

**1. `claude/skills/init-project/SKILL.md`** (arquivo novo, copiado sem
alterações do conteúdo atual de `~/.claude/skills/init-project/SKILL.md` —
ele já referencia `~/agentes-pipeline` de forma genérica, sem nada pessoal
hardcoded). Espelha o padrão que o repo já usa para o lado Antigravity
(`gemini/skills/<nome>/SKILL.md`).

**2. `README.md`** ganha uma seção nova "Setup — usuário novo" logo no topo
(antes de "Estrutura"), com um passo a passo único, sequencial, para o lado
Claude:

1. Clonar o repositório **exatamente** em `~/agentes-pipeline` (caminho fixo
   — o skill resolve `TEMPLATE_DIR` como `~/agentes-pipeline/agentes/`, não
   funciona em outro caminho).
2. Instalar o plugin Superpowers: `/plugin install superpowers@claude-plugins-official`.
3. Symlink do skill: `ln -s ~/agentes-pipeline/claude/skills/init-project ~/.claude/skills/init-project`.
4. `cd` no projeto alvo e rodar `/init-project`.
5. Usar: `/orquestrador <descrição da tarefa>`.

O symlink (em vez de cópia) é a escolha porque `git pull` no repo passa a
manter o skill sempre atualizado sem passo manual extra — trade-off já
validado com o Bruno.

As seções "Pré-requisitos por ferramenta", "Como instalar num projeto" e
"Sincronizar em outra máquina" continuam existindo, mas viram referência
para casos secundários (reinstalar `/init-project` numa terceira máquina,
lado Antigravity, `--update`) em vez de serem o caminho principal — a nova
seção do topo passa a ser o único lugar que alguém precisa ler para sair do
zero funcionando. O diagrama de árvore de arquivos na seção "Estrutura"
ganha a entrada `claude/skills/init-project/SKILL.md`.

**Fora de escopo:** lado Gemini/Antigravity do README (pergunta original foi
especificamente sobre `.claude`); transformar `init-project` num plugin de
verdade (`plugin.json`/marketplace) — cogitado e descartado a favor de
symlink simples, por ser desproporcional ao problema atual.

## Teste manual

Depois de aplicado: simular um usuário novo rodando exatamente os 5 comandos
da nova seção do README, numa pasta de projeto de teste, e confirmar que
`/init-project` cria `./agentes/` e `./.claude/commands/orquestrador*.md`
corretamente.
