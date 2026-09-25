---
description: Mostra o pipeline em aberto (só leitura) — demanda, perfil, tier, fase atual, etapas concluídas/pendentes, voltas e saídas em .agents/.pipeline-run/.
argument-hint: (sem argumentos)
model: haiku
---

Tarefa só de leitura: não carregue `.agents/ORQUESTRADOR.md` nem
`.agents/PIPELINE.md` e não altere nenhum arquivo.

1. Rode `bash .agents/scripts/pipeline-status.sh` na raiz do projeto.
2. Mostre a saída ao Bruno como está, num bloco de código, sem reinterpretar.
3. Conforme o resultado:
   - `nenhum pipeline em aberto` → diga isso numa linha.
   - Resumo impresso → acrescente só: "Para continuar, rode `/orquestrador`
     (ele oferece continuar de onde parou ou arquivar)."
   - Saída 2 (`PIPELINE-STATE.md malformado`) → mostre a mensagem e sugira
     `/orquestrador`, que renomeia o arquivo para
     `.agents/PIPELINE-STATE.md.corrompido-<data>` e recomeça.
   - Script ausente → instalação antiga: sugira `/init-project --update`.
