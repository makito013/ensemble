---
description: Faz o planejamento completo de uma ideia nova antes do desenvolvimento — interrogatório (Grill), opções documentadas em HTML e protótipo(s) opcionais — entregando um plano pronto para o /orquestrador.
argument-hint: [ideia bruta]
---

Leia integralmente `.agents/PLAN-FLOW.md` — é essa mecânica que este
comando aciona; ele não a reimplementa, só é o ponto de entrada. Não
carregue `.agents/ORQUESTRADOR.md` nem `.agents/PIPELINE.md`: este fluxo é
independente do pipeline principal. Os subagentes leem as próprias personas
(`.agents/GRILL.md`, `.agents/ARQUITETO.md`, `.agents/DEV-DESIGN.md`,
`.agents/DEV.md`) por caminho, com `model` explícito (`.agents/MODELOS.md`).

Ideia bruta (pode vir vazia — pergunte ao Bruno neste caso antes de seguir):

$ARGUMENTS

Passos:

1. Se existir `.agents/CONTEXTO.md` neste projeto, leia antes de tudo.

2. Derive um slug curto (kebab-case) a partir do resumo da ideia e verifique
   `.agents/planos/<slug>/ESTADO.md`:
   - **Não existe:** crie a pasta `.agents/planos/<slug>/` e o `ESTADO.md`
     inicial (formato em `PLAN-FLOW.md`, "Formato de ESTADO.md"), com "(a)
     Ideia original" = `$ARGUMENTS`.
   - **Existe e já está fechado** (REVISÃO FINAL concluída com `[GRILL]
     Plano aprovado`): avise o Bruno e pergunte se quer reabrir (nova rodada
     de GRILL a partir do estado salvo) ou começar um plano novo (slug novo).
   - **Existe e está em andamento:** ofereça continuar de onde parou, a
     partir do `ESTADO.md` salvo — não do histórico da conversa, que pode
     não existir mais depois de um `/clear`.

3. Apresente o menu de etapas do planejamento (`PLAN-FLOW.md`, "Menu de
   etapas") com a pré-seleção padrão (1, 2 e 4 marcadas; 3 desmarcada) e
   aguarde o Bruno confirmar ou ajustar. A etapa 1 (GRILL) nunca pode ser
   desmarcada.

4. Rode as etapas ativas conforme `PLAN-FLOW.md`: GRILL em sessão viva até a
   primeira linha da resposta ser exatamente `[GRILL] Pronto`; OPÇÕES em
   `.agents/planos/<slug>/opcoes.html`; PROTÓTIPO (N perguntado ao Bruno,
   tipo pela heurística de UI) em `.agents/planos/<slug>/prototipos/`;
   REVISÃO FINAL até `[GRILL] Plano aprovado`.

5. Consolide `.agents/planos/<slug>/plano-final.html` (autocontido, linka os
   demais artefatos da pasta) e `.agents/planos/<slug>/PLANO.md` (resumo em
   texto puro). Oriente o Bruno: *"Plano pronto em
   `.agents/planos/<slug>/PLANO.md` — quando for desenvolver, rode
   `/orquestrador` e cole esse conteúdo como a descrição da tarefa."*

Este comando nunca cria nem toca `.agents/PIPELINE-STATE.md` — é um fluxo
independente do pipeline principal. O handoff para `/orquestrador` é sempre
manual, nunca automático.
