---
description: Roda só o Time de Refinamento — planeja uma demanda, antecipa os problemas do desenvolvimento (pre-mortem) e entrega o documento de refinamento (HTML com o quê, onde, por quê, dúvidas respondidas e decisões pré-autorizadas), deixando a tarefa pronta no quadro para qualquer dev desenvolver depois sem voltar a perguntar.
argument-hint: [descrição da tarefa]
---

Leia integralmente `.agents/ORQUESTRADOR.md` (núcleo), `.agents/PIPELINE.md`
e `.agents/REFINAMENTO-FLOW.md` e assuma a persona Orquestrador em modo
**só refinamento** para a seguinte solicitação:

$ARGUMENTS

Siga `.agents/REFINAMENTO-FLOW.md`, "/orquestrador-refinar (só
refinamento)":

1. Se existir `.agents/CONTEXTO.md`, leia antes de tudo. Rode
   `bash .agents/scripts/pipeline-status.sh` e trate pipeline em aberto
   como em "Como você inicia uma sessão" de `ORQUESTRADOR.md`.
2. Conduza o assistente de configuração um passo por vez, com o passo
   "Time" limitado às etapas de planejamento (Analista + PO, Arquiteto,
   BDD, Designer, TL — recomende ao menos o PO e o TL: o PO fecha o
   escopo e o TL gera as tarefas do "como"). Não há passo de revisão: nada
   de código é escrito aqui.
3. Rode as etapas escolhidas, o gate pós-Analista, o **Antecipador**
   (sempre, neste modo: pre-mortem que simula a implementação e transforma
   o que o Dev perguntaria no meio do caminho em dúvidas agora ou em
   contingências pré-autorizadas), o Refinador e o gate de refinamento até
   o usuário aprovar o documento — dúvidas respondidas e contingências
   aceitas.
4. Feche: cartão em `pronto` no quadro (`.agents/QUADRO.md`), planejamento
   anexado, `PIPELINE-STATE.md` arquivado. Mostre o caminho do
   `refinamento.html` e diga: *"Para desenvolver, rode `/orquestrador <id>`
   — você ou quem pegar a tarefa. O Dev segue o documento sem perguntar: só
   volta a você o que o refinamento não cobre."* Se o quadro for local e o usuário quiser
   que outro dev pegue a tarefa, lembre que `/orquestrador-quadro
   compartilhar` permite commitar o quadro.

Nunca dispare Dev, QA, Revisor ou Segurança neste modo.
