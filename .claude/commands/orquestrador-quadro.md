---
description: Mostra o quadro de tarefas (o que foi feito, o que está em andamento e o que está pronto para pegar, inclusive em branches de outros devs) e liga/desliga o compartilhamento via git.
argument-hint: [vazio | ver <id> | compartilhar | descompartilhar]
model: claude-haiku-4-5-20251001
---

Tarefa mecânica: não carregue `.agents/ORQUESTRADOR.md` nem
`.agents/PIPELINE.md`. Formato do cartão e regras em `.agents/QUADRO.md`
(leia só se precisar explicar algo). Rode tudo na raiz do projeto.

Ação solicitada (vazio = mostrar o quadro):

$ARGUMENTS

- **Vazio:** rode `bash .agents/scripts/board.sh list --remote` e mostre a
  saída num bloco de código, sem reinterpretar. Acrescente uma linha: as
  tarefas `PRONTO` podem ser pegas com `/orquestrador <id>`.
- **`ver <id>`:** rode `bash .agents/scripts/board.sh show <id>` e mostre o
  cartão. Se a pasta do cartão tiver `refinamento.html`, informe o caminho
  para abrir no navegador.
- **`compartilhar`:** explique em 2 linhas o que muda (o quadro vai para
  `.agents-shared/`, que passa a ser versionável; nada sensível pode estar
  nos cartões) e peça confirmação. Confirmado, rode
  `bash .agents/scripts/board.sh share` e mostre a saída. Não faça
  `git add` nem commit: commitar é decisão do usuário.
- **`descompartilhar`:** peça confirmação e rode
  `bash .agents/scripts/board.sh unshare`; repasse o aviso do script se a
  pasta já estava commitada.

Script ausente → instalação antiga: sugira `/init-project --update`. Este
comando nunca altera o status de cartões nem toca `PIPELINE-STATE.md`.
