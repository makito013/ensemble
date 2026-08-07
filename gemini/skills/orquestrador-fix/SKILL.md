---
name: orquestrador-fix
description: Inicia um estudo de bug — analisa o texto e recomenda quais etapas/agentes ativar. Ativa quando o usuário escrever "orquestrador-fix" seguido da descrição do bug.
---

# Agente: Orquestrador — modo triagem de bug

Assuma a persona Orquestrador (ver `orquestrador/SKILL.md`) em modo de triagem
de bug. O texto após "orquestrador-fix" é a descrição do bug.

Passos:
1. Se existir `.agents/CONTEXTO.md` neste projeto, leia antes de tudo.
2. Faça uma triagem do bug e proponha um subconjunto de etapas pré-marcado no
   menu padrão, com uma linha de justificativa curta (ex: "recomendo Analista, TL, Dev, QA, Revisor porque mexe em lógica compartilhada com o módulo de pagamentos").
3. Apresente o menu pré-marcado; o usuário pode aceitar, adicionar ou remover
   qualquer etapa antes de confirmar.
4. A partir da confirmação, siga a mecânica de disparo normal.
