# Quadro de tarefas (contexto descentralizado)

Carregado sob demanda: pelo Orquestrador nos marcos do pipeline (tabela
abaixo) e pelo `/orquestrador-quadro`. Script: `.agents/scripts/board.sh`
(determinístico; rode sempre na raiz do projeto).

## O que é e por quê

Cada tarefa vira uma pasta com um `CARTAO.md` — status, responsável,
branch, onde mexe, critérios, decisões e um log curto — ao lado do
documento de refinamento e do planejamento integral. **Não existe arquivo
central**: o quadro é calculado lendo os cartões. Assim dois devs em
tarefas diferentes nunca editam o mesmo arquivo (sem conflito de merge),
e o contexto de cada tarefa viaja com ela: quem chega depois lê o cartão
e sabe o que foi decidido, onde, por quê e o que falta.

`PIPELINE-STATE.md` continua sendo o estado detalhado e local da execução
(voltas, snapshots, lentes); o cartão é o resumo que outra pessoa precisa.

## Local ou compartilhado (commit só se o usuário quiser)

| Modo | Pasta | Git |
|------|-------|-----|
| local (padrão) | `.agents/quadro/` | fora do git (`.agents/` é ignorada) |
| compartilhado | `.agents-shared/` | versionável — o time vê ao dar pull |

- `bash .agents/scripts/board.sh where` → `local|shared <pasta>`.
- `board.sh share` move o quadro para `.agents-shared/` (com um
  `README.md` para quem não usa o pipeline); `board.sh unshare` traz de
  volta. **Nunca** compartilhe por conta própria: só com pedido explícito
  do usuário (assistente, passo "Quadro", ou `/orquestrador-quadro
  compartilhar`). Commitar continua sendo decisão do usuário — você nunca
  faz `git add`/`commit` da pasta sem ele pedir.
- `board.sh list --remote` também lê cartões que outros devs já subiram
  em branches ainda não mergeadas: é assim que se vê o que está **em
  andamento** antes do merge.

## Formato do CARTAO.md

Criado por `board.sh new <slug> <título>` (id `AAAAMMDD-<slug>`, sem
contador central). Campos do cabeçalho só via `board.sh set` (atualiza
`Atualizado:` e o log); as seções você edita com Write/Edit:

```markdown
# <título>

ID: 20261023-login-google
Status: refinando | pronto | em-andamento | em-revisao | bloqueada | concluida | cancelada
Responsável: <git user.name>
Branch: <branch>
Criado: <data hora>
Atualizado: <data hora>
Tier: <spike|feature|critical>
Perfil: <perfil>
Refinamento: refinamento.html

## Resumo
## Onde
- `src/auth/providers/google.ts` — criar
## Critérios de aceitação
- [ ] CA01 ...
## Progresso
- [x] Refinamento aprovado
- [ ] Fase 1 — Backend
## Decisões
- D1: pedir a senha antes de vincular (respondida por <autor>, <data>)
## Log
- <data hora> — <autor> — <evento>
```

Pasta do cartão: `CARTAO.md`, `refinamento.json`, `refinamento.html` e
`planejamento/` (cópia das saídas `01`..`06`, por `board.sh attach`).
Relatórios de Dev/QA/Revisor/Segurança ficam locais em `.pipeline-run/`;
no cartão vai só o resumo de 1 linha no log.

## Marcos em que você atualiza o quadro

| Marco | Comando / edição |
|-------|------------------|
| Assistente confirmado | `board.sh new <slug> <título>`; `set Tier`, `set Perfil`; id no `PIPELINE-STATE.md` (`Tarefa do quadro:`) |
| Refinamento aprovado | ver `.agents/REFINAMENTO-FLOW.md`, "Depois de aprovado" |
| Primeiro disparo do Dev | `set Status em-andamento`, `set Branch <branch atual>` |
| Fase concluída / volta de retrabalho | `board.sh log <id> "<1 linha>"` + marcar em "Progresso" |
| Revisão/Segurança rodando | `set Status em-revisao` |
| Bloqueio que depende de terceiro | `set Status bloqueada` + motivo no log |
| Pipeline concluído | `set Status concluida`; decisões duráveis em "Decisões"; ressalvas como dívida no log |
| Pipeline arquivado sem concluir | pergunte: `cancelada` ou deixar `em-andamento` para retomar |

## Regras

- **Nada sensível no cartão:** ele pode ir para o repositório. Nunca grave
  segredo, token, senha, dado pessoal, cliente real ou URL interna — nome
  da variável sim, valor nunca.
- Cartão é resumo: no máximo ~60 linhas; nunca cole relatório integral.
- Cartão de outro responsável: só leia. Mudar status/responsável dele só
  com pedido explícito do usuário.
- Fato que vale para o projeto inteiro (não só a tarefa) continua indo
  para `CONTEXTO.md`, com a confirmação de sempre.
