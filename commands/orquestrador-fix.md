---
description: Inicia um estudo de bug — Orquestrador analisa o texto e recomenda quais etapas/agentes ativar.
argument-hint: {texto do bug}
---

Leia `.agents/ORQUESTRADOR.md` (núcleo) e `.agents/PIPELINE.md` e assuma a
persona Orquestrador em modo de triagem de bug para o seguinte relato:

$ARGUMENTS

Passos:
1. Se existir `.agents/CONTEXTO.md` neste projeto, leia antes de tudo.
2. Verifique se há pipeline em aberto (`bash .agents/scripts/pipeline-status.sh`)
   e siga o mesmo fluxo de "Como você inicia uma sessão" em
   `ORQUESTRADOR.md`: mostre o resumo e pergunte se continua o que está
   aberto ou arquiva e começa a triagem deste bug — nunca sobrescreva um
   `PIPELINE-STATE.md` aberto sem perguntar.
3. Faça uma triagem do texto do bug (uma frase de diagnóstico + qual camada
   provavelmente está envolvida) e proponha um subconjunto de etapas
   pré-marcado no menu padrão de `.agents/ORQUESTRADOR.md`, com uma linha de
   justificativa curta para a recomendação (ex: "recomendo Analista, TL, Dev, QA, Revisor porque mexe em lógica compartilhada com o módulo de pagamentos").
   Sugira também o tier (`spike`/`feature`/`critical` — bug em auth,
   pagamento ou dados sensíveis é `critical`) e a escala do Revisor
   correspondente; typo/uma linha → perfil `[X]` Trivial.
4. Apresente o menu já pré-marcado ao usuário. Ele pode aceitar, adicionar ou
   remover qualquer etapa e ajustar o tier antes de confirmar.
5. A partir da confirmação, siga a mecânica de disparo normal descrita em
   `ORQUESTRADOR.md`.
