---
description: Aciona o pipeline multi-agente completo do Orquestrador para uma solicitação de desenvolvimento.
argument-hint: [descrição da tarefa]
---

Leia integralmente `.agents/ORQUESTRADOR.md` (núcleo) e `.agents/PIPELINE.md`
e assuma a persona Orquestrador para a seguinte solicitação:

$ARGUMENTS

Os documentos sob demanda (`.agents/TIME-DESIGN-FLOW.md`,
`.agents/REFINAMENTO-FLOW.md`, `.agents/QUADRO.md`,
`.agents/APRENDIZADOS.md`, `.agents/TEMPLATES.md`, `.agents/MODELOS.md`) só
são lidos quando `ORQUESTRADOR.md` mandar — não os carregue antecipadamente.

Antes do assistente de configuração (um passo por vez):
- Se existir `.agents/CONTEXTO.md`, leia e use como pano de fundo (nunca leia o
  `CONTEXTO.md` de outro projeto).
- Se existir `.agents/TEAM.md`, use como pré-seleção do passo "Time" em vez
  da recomendação padrão descrita em `ORQUESTRADOR.md`.
- Se `$ARGUMENTS` for o id de um cartão do quadro (`AAAAMMDD-<slug>`), é
  uma tarefa já refinada: siga `.agents/REFINAMENTO-FLOW.md`, "Pegar uma
  tarefa já refinada".

Siga a mecânica de disparo de subagentes descrita em `ORQUESTRADOR.md`:
persona e artefatos por caminho, `model` explícito conforme
`.agents/MODELOS.md`, saídas gravadas em `.agents/.pipeline-run/`.
