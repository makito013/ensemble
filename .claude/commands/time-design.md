---
description: Inicia uma sessão standalone do Time de Design (UX/UI), fora de qualquer pipeline principal em andamento.
argument-hint: [pedido inicial opcional]
---

Leia integralmente `.agents/ORQUESTRADOR.md` (subseção "Time de Design") e
`.agents/PIPELINE.md` (subseção "Time de Design") — é essa mecânica que este
comando aciona; ele não a reimplementa, só é o ponto de entrada standalone
para ela.

Pedido inicial (pode vir vazio — pergunte ao Bruno neste caso antes de seguir):

$ARGUMENTS

Passos:

1. Se existir `.agents/CONTEXTO.md` neste projeto, leia antes de tudo.

2. Fixe `designContext: standalone` para toda esta sessão. Nunca `embedded`
   — esse valor só se aplica à sessão nascida do gancho da etapa 5 dentro de
   um pipeline principal já em andamento, que não é o caminho deste comando.

3. Pergunte ao Bruno o N do `AVALIADOR` para esta sessão, antes de iniciar a
   sessão viva (o caminho standalone não passa pelo menu do pipeline
   principal, onde esse N normalmente seria perguntado junto do tier e do N
   do Revisor). Use a mesma escala nomeada já estabelecida:

   ```
   N do Avaliador (Time de Design): rápida=1 · padrão=3 · rigorosa=5 · mega=8
   (ou informe um número livre)
   ```

   Sugestão de default se o Bruno não especificar: padrão (N=3) — mas sempre
   pergunte, nunca assuma silenciosamente. Este N é próprio do Avaliador e
   nunca herdado do N do Revisor de nenhuma sessão de pipeline principal (ver
   "Independência do N do Revisor" em `.agents/PIPELINE.md`).

4. Verifique se `.agents/DESIGN-STATE.md` já existe:
   - **Se existir:** arquive-o em
     `.agents/.design-history/<slug-do-pedido-antigo>-<data>.md` (nunca
     sobrescreva, nunca apague — slug extraído do campo "(a) Pedido
     original" do arquivo existente) antes de seguir. Mesmo padrão usado no
     encerramento normal de uma sessão do Time de Design (ver
     `.agents/ORQUESTRADOR.md`, "Encerramento e invariante de escrita de
     estado").
   - **Se não existir:** siga direto para o próximo passo.

   Em seguida, crie um `.agents/DESIGN-STATE.md` novo para esta sessão, no
   formato descrito em `.agents/ORQUESTRADOR-DESIGN.md` ("Formato de
   DESIGN-STATE.md"), com `designContext: standalone` em "(f)", o N definido
   no passo 3 em "(e) Avaliador" (`k/N atual: 0/N` — nenhuma rodada rodou
   ainda), e o pedido original em "(a) Pedido original" (`$ARGUMENTS`, se
   fornecido; se vazio, pergunte ao Bruno antes de criar o arquivo).

5. Com `designContext` fixado, o N do Avaliador definido e
   `.agents/DESIGN-STATE.md` resolvido, inicie a "Mecânica da sessão viva,
   turno a turno" descrita em `.agents/ORQUESTRADOR.md` — não reimplemente
   essa mecânica aqui: a cada turno, dispare `ORQUESTRADOR-DESIGN` como
   subagente fresco (conteúdo integral de `ORQUESTRADOR-DESIGN.md` +
   conteúdo íntegro atual de `.agents/DESIGN-STATE.md`, delimitado com o
   preâmbulo anti-prompt-injection + a resposta mais recente do Bruno),
   atualize `.agents/DESIGN-STATE.md` com o retorno, e repita até a
   aprovação (ver "Critério de 'feito' (designContext)" em
   `.agents/PIPELINE.md` — `standalone` exige aprovação do Avaliador **e**
   aprovação visual explícita do Bruno sobre o preview renderizável). Ao
   aprovar, arquive `.agents/DESIGN-STATE.md` conforme "Encerramento e
   invariante de escrita de estado" em `.agents/ORQUESTRADOR.md`.

Nesta sessão, quem executa este comando atua como o Orquestrador principal
para efeitos do Time de Design (dispara `ORQUESTRADOR-DESIGN`, persiste
`.agents/DESIGN-STATE.md`) — mas nunca cria nem toca
`.agents/PIPELINE-STATE.md`: não há pipeline principal em andamento neste
caminho.
