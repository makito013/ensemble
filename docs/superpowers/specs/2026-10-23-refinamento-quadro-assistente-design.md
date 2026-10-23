# Time de Refinamento, quadro descentralizado e assistente por etapas

## Pedido

1. Orquestrador e Dev melhores, com as ideias atuais de *harness
   engineering* (estado em arquivo, retomada sem histórico de conversa,
   avaliador independente do construtor).
2. Contexto descentralizado que, **só se o usuário quiser**, pode ser
   commitado: outros devs do mesmo repo sabem o que foi feito, o que não
   foi e o que está em andamento.
3. Um time de refinamento que documenta, antes do Dev, o quê, onde, por quê
   e as dúvidas a responder — num template HTML fixo, preenchido.
4. A verificação múltipla já existente continua, mas apresentada passo a
   passo (escolha o time → se tem Revisor, escolha quantos → lembrete de
   que cada revisor é novo e isolado → …).

## Análise e decisões

**Refinamento não é mais uma persona que "pensa".** As etapas 1-6 já
planejam; faltava (a) consolidar num artefato único que o dev lê, e (b)
impedir o Dev de começar com dúvida bloqueante aberta. Daí:

- `REFINADOR` só consolida e confere caminhos no repo (sem inventar); a
  saída é **dado** (`refinamento.json`), não HTML.
- O HTML vem de um **template fixo** + `render-refinement.mjs`
  (determinístico, sem dependência, escapa tudo). LLM escrevendo HTML a
  cada tarefa geraria layout diferente, HTML quebrado e custo à toa.
- O renderizador é o **gate**: sai `3` enquanto houver dúvida bloqueante
  sem resposta. A decisão não depende de interpretar prosa — mesmo padrão
  dos marcadores de 1ª linha do Revisor/Grill.
- `/orquestrador-refinar` separa refinar de desenvolver: o cartão fica
  `pronto` e qualquer dev pega com `/orquestrador <id>`. Para isso o
  planejamento integral é anexado ao cartão (o `.pipeline-run/` é local e
  é arquivado).

**Contexto descentralizado = um cartão por tarefa, sem índice central.**
Um arquivo de quadro central conflitaria em todo merge com dois devs.
Com uma pasta por tarefa (`id = AAAAMMDD-slug`, sem contador), o quadro é
calculado lendo os cartões, e `list --remote` lê também cartões em
branches não mergeadas — o "em andamento" de outra pessoa aparece antes do
merge. A seção "Onde" de cada cartão funciona como índice: `related`
acusa conflito quando outra tarefa em andamento mexe nos mesmos arquivos.

**Opt-in de verdade.** Local por padrão em `.agents/quadro/` (já
ignorado). Compartilhar é uma ação explícita (`board.sh share`) que move o
quadro para `.agents-shared/`; o pipeline nunca faz `git add`/commit.
Refinador e cartões proíbem segredo/PII, porque o conteúdo pode ir para o
repositório.

**Assistente por etapas.** O menu de 10 checkboxes + 9 perfis + escala do
Revisor numa mensagem só foi trocado por um passo por vez (Time → Rigor →
Revisão → Design → Quadro → Resumo), com passos condicionais e
`AskUserQuestion` quando disponível. A escala do Revisor é apresentada
como "quantos revisores independentes" (1/3/5/7), com o lembrete de que
cada um é um subagente novo, sem a conversa e sem a saída dos outros; o
mecanismo (lentes + verificador, 2ª volta em modo verificação) não mudou.

**Harness no Dev e no Revisor.**
- Dev: **linha de base** antes de mexer (distingue "quebrei" de "já estava
  quebrado") e tarefas uma por vez, verificando cada uma.
- Revisor: declara o isolamento; com refinamento, decisão respondida
  ignorada é defeito e arquivo fora do "onde" sem justificativa é ressalva.

## Fora de escopo

- Sincronizar `CONTEXTO.md` entre devs (continua local; fato de projeto
  inteiro passa pela confirmação de sempre).
- Commit/push automático do quadro.
- Board com UI própria: o quadro é texto + `board.sh`.
