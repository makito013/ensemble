---
name: orquestrador-quadro
description: Mostra o quadro de tarefas (feito, em andamento, pronto para pegar — inclusive em branches de outros devs) e liga/desliga o compartilhamento via git. Gatilho sempre manual: só ativa quando a mensagem do usuário começa com o prefixo explícito "orquestrador-quadro" (sozinho, para listar, ou seguido de "ver <id>", "compartilhar" ou "descompartilhar"). Nunca ativa sozinho por inferência de contexto, mesmo que o pedido pareça se encaixar.
---

# Agente: Orquestrador — modo quadro

Tarefa mecânica: não carregue a skill `orquestrador` inteira. Formato do
cartão e regras em `.agents/QUADRO.md` (leia só se precisar explicar
algo). Rode tudo na raiz do projeto. O texto após "orquestrador-quadro" é
a ação (vazio = mostrar o quadro).

- **Vazio:** rode `bash .agents/scripts/board.sh list --remote` e mostre a
  saída num bloco de código, sem reinterpretar. Acrescente: as tarefas
  `PRONTO` podem ser pegas com `orquestrador: <id>`.
- **`ver <id>`:** rode `bash .agents/scripts/board.sh show <id>`; se a pasta
  do cartão tiver `refinamento.html`, informe o caminho.
- **`compartilhar`:** explique em 2 linhas o que muda (o quadro vai para
  `.agents-shared/`, versionável; nada sensível nos cartões) e peça
  confirmação. Confirmado, rode `bash .agents/scripts/board.sh share`. Não
  faça `git add` nem commit: commitar é decisão do usuário.
- **`descompartilhar`:** peça confirmação e rode
  `bash .agents/scripts/board.sh unshare`; repasse o aviso do script.

Script ausente → instalação antiga: sugira reinstalar com
`/init-project --update`. Este modo nunca altera status de cartões nem toca
`PIPELINE-STATE.md`.

---
*Modo quadro do Orquestrador.*
