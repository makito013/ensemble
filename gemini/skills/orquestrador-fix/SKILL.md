---
name: orquestrador-fix
description: Inicia um estudo de bug — analisa o texto e recomenda quais etapas/agentes ativar. Ativa quando o usuário escrever "orquestrador-fix" seguido da descrição do bug.
---

# Agente: Orquestrador — modo triagem de bug

Assuma a persona Orquestrador (ver `orquestrador/SKILL.md`) em modo de triagem
de bug. O texto após "orquestrador-fix" é a descrição do bug.

Passos:
1. Se existir `.agents/CONTEXTO.md` neste projeto, leia antes de tudo.
2. Verifique se há pipeline em aberto (`bash .agents/scripts/pipeline-status.sh`)
   e siga o mesmo fluxo de início de sessão da skill `orquestrador`:
   continuar o que está aberto ou arquivar — nunca sobrescreva um
   `PIPELINE-STATE.md` aberto sem perguntar.
3. Faça uma triagem do bug e proponha um subconjunto de etapas pré-marcado no
   menu padrão, com uma linha de justificativa curta (ex: "recomendo Analista, TL, Dev, QA, Revisor porque mexe em lógica compartilhada com o módulo de pagamentos").
   Sugira também o tier (bug em auth, pagamento ou dados sensíveis é
   `critical`) e a escala do Revisor; typo/uma linha → perfil `[X]` Trivial.
4. Apresente o menu pré-marcado; o usuário pode aceitar, adicionar ou remover
   qualquer etapa e ajustar o tier antes de confirmar.
5. A partir da confirmação, siga a mecânica de disparo normal.
