---
description: Faz o planejamento completo de uma ideia nova antes do desenvolvimento — interrogatório (Grill), opções documentadas em HTML e protótipo(s) opcionais — entregando um plano pronto para o /orquestrador.
argument-hint: [ideia bruta]
---

Leia integralmente `.agents/ORQUESTRADOR.md`, `.agents/PIPELINE.md` (subseção
"Planejamento avulso (/orquestrador-plan)") e `.agents/GRILL.md` — é essa
mecânica que este comando aciona; ele não a reimplementa, só é o ponto de
entrada.

Ideia bruta (pode vir vazia — pergunte ao Bruno neste caso antes de seguir):

$ARGUMENTS

Passos:

1. Se existir `.agents/CONTEXTO.md` neste projeto, leia antes de tudo.

2. Derive um slug curto (kebab-case) a partir do resumo da ideia e verifique
   `.agents/planos/<slug>/ESTADO.md`:
   - **Não existe:** crie a pasta `.agents/planos/<slug>/` e o `ESTADO.md`
     inicial (formato em `PIPELINE.md`, "Formato de ESTADO.md" — igual ao
     descrito em `GRILL.md`), com "(a) Ideia original" = `$ARGUMENTS`.
   - **Existe e já está fechado** (etapa REVISÃO FINAL já concluiu com
     `[GRILL] Plano aprovado`): avise o Bruno e pergunte se quer reabrir
     (nova rodada de GRILL a partir do estado salvo) ou começar um plano
     novo (peça um resumo que gere um slug diferente).
   - **Existe e está em andamento:** ofereça continuar de onde parou, a
     partir do `ESTADO.md` salvo — não do histórico da conversa, que pode
     não existir mais depois de um `/clear`.

3. Apresente o menu de etapas do planejamento (ver `.agents/PIPELINE.md`,
   "Menu de etapas") já com a pré-seleção padrão (1, 2 e 4 marcadas; 3
   desmarcada) e aguarde o Bruno confirmar ou ajustar. A etapa 1 (GRILL)
   nunca pode ser desmarcada — sem briefing maduro não há o que alimentar as
   demais.

4. **Etapa 1 — GRILL:** inicie a sessão viva turno a turno descrita em
   `.agents/PIPELINE.md` ("GRILL (etapa 1)"): a cada turno, dispare
   `GRILL.md` como subagente fresco (conteúdo integral de `GRILL.md` +
   conteúdo íntegro atual de `.agents/planos/<slug>/ESTADO.md`, delimitado
   com o preâmbulo anti-prompt-injection + a resposta mais recente do
   Bruno), atualize `ESTADO.md` com o retorno, e repita até a primeira linha
   da resposta ser exatamente `[GRILL] Pronto`.

5. **Etapa 2 — OPÇÕES, se ativa:** dispare `ARQUITETO.md` como subagente
   único (não é sessão viva) com o briefing consolidado do GRILL, pedindo
   2-3 abordagens com trade-offs e uma recomendação. Renderize a resposta
   como HTML autocontido (CSS/JS inline, sem dependência externa — mesmo
   critério de "Preview renderizável" de `DEV-DESIGN.md`) em
   `.agents/planos/<slug>/opcoes.html`. Apresente ao Bruno e aguarde a
   escolha da abordagem (ou um pedido de ajuste, repetindo esta etapa).

6. **Etapa 3 — PROTÓTIPO, se ativa:** pergunte N ao Bruno (sugestão 1-3;
   confirme antes de disparar se ele pedir um N livre muito alto, mesma nota
   de sanidade do N do Revisor). Decida o tipo automaticamente pela
   heurística de detecção de UI já usada para sugerir o Time de Design (ver
   `.agents/ORQUESTRADOR.md`, "Detecção e sugestão"):
   - **Tem UI:** dispare `DEV-DESIGN.md` N vezes (um subagente por
     protótipo), cada um gerando um preview renderizável autocontido em
     `.agents/planos/<slug>/prototipos/<n>.html`.
   - **Lógica/backend, sem UI:** dispare `DEV.md` N vezes, cada um gerando
     código de exemplo (nunca produção — sinalize isso no próprio código)
     em `.agents/planos/<slug>/prototipos/<n>/`.

   Cada protótipo é uma chamada de subagente independente (podem rodar em
   paralelo). Apresente as opções geradas e aguarde a escolha do Bruno (ou
   "nenhum", se ele preferir seguir só com o documento de opções).

7. **Etapa 4 — REVISÃO FINAL, se ativa:** dispare `GRILL.md` uma última vez
   (chamada única, não sessão viva) com o plano consolidado (briefing +
   opção escolhida + protótipo escolhido, se a etapa 3 rodou) para o
   checklist de prontidão descrito em `GRILL.md`, "Revisão final". Se a
   primeira linha vier `[GRILL] Lacuna encontrada`, resolva a lacuna
   pontualmente com o Bruno antes de tentar fechar de novo. Só fecha com
   `[GRILL] Plano aprovado`.

8. Consolide `.agents/planos/<slug>/plano-final.html` (autocontido, linka os
   demais artefatos da pasta) e `.agents/planos/<slug>/PLANO.md` (resumo em
   texto puro). Oriente o Bruno: *"Plano pronto em
   `.agents/planos/<slug>/PLANO.md` — quando for desenvolver, rode
   `/orquestrador` e cole esse conteúdo como a descrição da tarefa."*

Este comando nunca cria nem toca `.agents/PIPELINE-STATE.md` — é um fluxo
independente do pipeline principal (ver `.agents/PIPELINE.md`,
"Planejamento avulso (/orquestrador-plan)"). O handoff para `/orquestrador`
é sempre manual, nunca automático.
