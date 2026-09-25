---
name: orquestrador-status
description: Mostra o pipeline em aberto (só leitura) — demanda, perfil, tier, fase atual, etapas concluídas/pendentes, voltas e saídas em .agents/.pipeline-run/. Ativa quando o usuário escrever "orquestrador-status".
---

# Agente: Orquestrador — modo status

Tarefa só de leitura: não carregue a skill `orquestrador` inteira e não
altere nenhum arquivo.

1. Rode `bash .agents/scripts/pipeline-status.sh` na raiz do projeto.
2. Mostre a saída ao usuário como está, num bloco de código, sem
   reinterpretar.
3. Conforme o resultado:
   - `nenhum pipeline em aberto` → diga isso numa linha.
   - Resumo impresso → acrescente só: "Para continuar, use `orquestrador:`
     (ele oferece continuar de onde parou ou arquivar)."
   - Saída 2 (`PIPELINE-STATE.md malformado`) → mostre a mensagem e sugira
     `orquestrador:`, que renomeia o arquivo para
     `.agents/PIPELINE-STATE.md.corrompido-<data>` e recomeça.
   - Script ausente → instalação antiga: sugira reinstalar com
     `/init-project --update`.

---
*Modo só leitura do Orquestrador.*
