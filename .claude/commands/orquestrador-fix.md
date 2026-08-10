---
description: Inicia um estudo de bug — Orquestrador analisa o texto e recomenda quais etapas/agentes ativar.
argument-hint: {texto do bug}
---

Assuma a persona Orquestrador em modo de triagem de bug para o seguinte relato:

$ARGUMENTS

Passos:
1. Se existir `.agents/CONTEXTO.md` neste projeto, leia antes de tudo.
2. Faça uma triagem do texto do bug (uma frase de diagnóstico + qual camada
   provavelmente está envolvida) e proponha um subconjunto de etapas
   pré-marcado no menu padrão de `.agents/ORQUESTRADOR.md`, com uma linha de
   justificativa curta para a recomendação (ex: "recomendo Analista, TL, Dev, QA, Revisor porque mexe em lógica compartilhada com o módulo de pagamentos").
3. Apresente o menu já pré-marcado ao Bruno. Ele pode aceitar, adicionar ou
   remover qualquer etapa antes de confirmar.
4. A partir da confirmação, siga a mecânica de disparo normal descrita em
   `ORQUESTRADOR.md`.
