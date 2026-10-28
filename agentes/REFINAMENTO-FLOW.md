# Time de Refinamento

Carregado sob demanda: pelo Orquestrador quando alguma etapa de
planejamento (2-6) está ativa, e pelo `/orquestrador-refinar`. Modelos:
`.agents/MODELOS.md`. Quadro de tarefas: `.agents/QUADRO.md`.

## O que é e por quê

O Time de Refinamento são as etapas de planejamento que rodaram (Analista,
PO, Arquiteto, BDD, Designer, TL), o **Antecipador** (pre-mortem do plano,
quando roda) **e o Refinador**, que fecha o time
consolidando tudo num documento único, com layout fixo, que o dev lê antes
de começar: **o quê, onde, por quê, como, e as dúvidas que precisam de
resposta antes**. O Dev só começa com o refinamento aprovado e sem dúvida
bloqueante aberta — a pergunta cara ("era pra vincular a conta ou pedir
senha?") acontece antes do código, não na revisão.

O documento tem duas formas, sempre na pasta do cartão no quadro
(`<quadro>/tarefas/<id>/`):

- `refinamento.json` — os dados (formato em `.agents/REFINADOR.md`). É o
  que se edita.
- `refinamento.html` — gerado pelo script a partir do JSON e do template
  fixo `.agents/scripts/refinement-template.html`. Nunca é escrito à mão,
  nem por LLM: o layout é sempre o mesmo, só os dados mudam.

## Sequência

0. **Antecipador** (`.agents/ANTECIPADOR.md`, `model: "opus"`), depois da
   última etapa de planejamento ativa. Roda sempre no
   `/orquestrador-refinar`; no `/orquestrador`, em tier `critical` com o
   TL ativo ou quando o usuário pede ("pre-mortem", "antecipar
   problemas"). Recebe demanda,
   decisões, `01`..`06` e `CONTEXTO.md`; grava `06b-antecipador.md`. Faz o
   pre-mortem: simula a implementação contra o código real e transforma o
   que o Dev perguntaria no meio do caminho em dúvidas agora ou em
   contingências pré-autorizadas. Decisões pendentes dele seguem o
   contrato de sempre (pergunte, grave em `00-decisoes.md`, redispare).
1. Depois da última etapa de planejamento ativa (e do Antecipador, se
   rodou), dispare o **Refinador**
   (`.agents/REFINADOR.md`, `model: "sonnet"`) com os caminhos de sempre
   (demanda, decisões, `01`..`06` e `06b-antecipador` que existirem,
   `CONTEXTO.md`) + o
   caminho de saída `<quadro>/tarefas/<id>/refinamento.json`.
2. Renderize (determinístico):
   `node .agents/scripts/render-refinement.mjs <dir>/refinamento.json <dir>/refinamento.html`
   - `0` → pronto para desenvolvimento;
   - `3` → renderizado, com dúvidas bloqueantes sem resposta (o script
     lista quais);
   - `1` → JSON inválido: redispare o Refinador **uma vez** com os erros
     impressos pelo script; persistindo, escale ao usuário.
   - Sem `node` no ambiente: avise, mantenha o JSON e apresente as dúvidas
     em texto — o gate vale do mesmo jeito.
3. Rode `bash .agents/scripts/board.sh related --except <id> <caminhos do "where">`.
   `CONFLITO` = outra tarefa em andamento mexe nos mesmos arquivos: entra
   no gate como aviso. Cartões `RELACIONADA` concluídos entram no handoff do
   Dev como contexto (decisões já tomadas naquela área).

## Gate de refinamento (antes do Dev, obrigatório)

Pare e mostre ao usuário, numa mensagem: o caminho do `refinamento.html`
(sugira abrir no navegador), o resumo, a contagem do "onde" (criar /
alterar / remover), os conflitos do quadro, as **contingências** (o que o
Dev vai decidir sozinho — aprovar o documento aprova essas decisões; o
usuário pode trocar ou remover qualquer uma antes) e as **dúvidas
bloqueantes**, cada uma com opções e recomendação. Com ferramenta de pergunta com opções
(no Claude Code, `AskUserQuestion`), pergunte as dúvidas por ela — até 4
por chamada, recomendação primeiro.

Com as respostas:
1. Grave-as em `00-decisoes.md` e no `refinamento.json` (`answer` +
   `answeredBy`: `<autor> <data>`) — edição direta do JSON, sem subagente.
2. Renderize de novo. Saída `0` → peça a aprovação final: *"Refinamento
   aprovado — seguir para o desenvolvimento?"*
3. Resposta que contraria o que o plano assumiu (o usuário escolheu a
   opção que o TL/Arquiteto não usou) → redispare a etapa afetada com a
   decisão e depois o Refinador. Teto: 2 voltas de refinamento; na 3ª,
   apresente o que não fecha e deixe o usuário decidir.

Exceção: tier `spike` com saída `0` pode pular a aprovação final.

## Depois de aprovado

- `bash .agents/scripts/board.sh attach <id> .agents/.pipeline-run/0[1-6]*.md`
  — o planejamento integral vai para `<dir>/planejamento/`, ao lado do
  documento, para qualquer dev (ou outra máquina) retomar dali.
- `board.sh set <id> Refinamento refinamento.html` e preencha no
  `CARTAO.md` as seções "Resumo", "Onde" e "Critérios de aceitação" a
  partir do JSON (resumo, não cópia).
- Status: `pronto` se o fluxo termina aqui (`/orquestrador-refinar`);
  `em-andamento` se o Dev vem em seguida.
- **Handoff do Dev:** além do que a matriz de handoff manda, o Dev recebe
  `refinamento.json` — as respostas das dúvidas são decisões fechadas, as
  contingências são decisões pré-autorizadas e o "where" é o escopo
  esperado de arquivos (ver "Desenvolvimento sem perguntas"). O Revisor recebe o mesmo
  arquivo (arquivo alterado fora do "where" sem justificativa do Dev é
  ressalva de escopo).

## Desenvolvimento sem perguntas

O refinamento aprovado é o contrato do desenvolvimento, por mais que ele
demore ou mude de mãos. Quando o Dev devolve uma decisão pendente numa
tarefa com `refinamento.json`, o Orquestrador **consulta o documento antes
de consultar o usuário**:

1. A dúvida já tem resposta (`questions[].answer`) ou casa com o gatilho
   de uma contingência (`contingencies[].when`) → redispare o Dev citando o
   item (`D2`, `C1`), sem perguntar ao usuário. Registre no log do cartão.
2. A contingência manda parar (`escalateIf` atingido) ou nada no documento
   cobre a dúvida → aí sim pergunte ao usuário. Grave a resposta em
   `00-decisoes.md` **e** no `refinamento.json` (como dúvida nova, já
   respondida) e renderize de novo: a próxima pessoa a pegar a tarefa não
   repete a pergunta.

Uma dúvida que chega ao usuário durante o desenvolvimento é uma lacuna do
refinamento: registre-a como regra de aprendizado candidata (persona:
`ANTECIPADOR.md`, ver `.agents/APRENDIZADOS.md`) para o pre-mortem cobrir
esse tipo de problema na próxima.

## /orquestrador-refinar (só refinamento)

Mesmo assistente do `/orquestrador`, com o passo "Time" limitado às
etapas de planejamento (Analista + 2-6; o passo de revisão não aparece) e
o Antecipador sempre ativo — o objetivo do modo é deixar a tarefa pronta
para alguém desenvolver depois sem voltar a perguntar. O
pipeline termina no gate aprovado: cartão em `pronto`, `PIPELINE-STATE.md`
arquivado como em qualquer fim de pipeline. Serve para refinar várias
tarefas antes (inclusive para outro dev desenvolver) e para o time revisar
o `refinamento.html` antes de alguém pegar a tarefa.

## Pegar uma tarefa já refinada

`/orquestrador <id>` (ou "pegar a tarefa <id>"), com o cartão em `pronto`:
o assistente pula o planejamento — o passo "Time" oferece só as etapas
7-10 — e o Dev recebe `<dir>/planejamento/*.md` + `refinamento.json` no
lugar das saídas `01`..`06`. Antes, rode o renderizador: saída `3`
(alguém reabriu uma dúvida) volta ao gate. Cartão `em-andamento` com outro
responsável → avise quem está com ele e pergunte se assume mesmo assim. Ao
assumir: `board.sh set <id> Responsável <você>`, `Branch <branch atual>` e
`Status em-andamento`.
