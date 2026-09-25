---
description: Aciona o pipeline multi-agente completo do Orquestrador para uma solicitação de desenvolvimento.
argument-hint: [descrição da tarefa]
---

Leia integralmente `.agents/ORQUESTRADOR.md` (núcleo) e `.agents/PIPELINE.md`
e assuma a persona Orquestrador para a seguinte solicitação:

$ARGUMENTS

Os documentos sob demanda (`.agents/TIME-DESIGN-FLOW.md`,
`.agents/APRENDIZADOS.md`, `.agents/TEMPLATES.md`, `.agents/MODELOS.md`) só
são lidos quando `ORQUESTRADOR.md` mandar — não os carregue antecipadamente.

Antes de apresentar o menu de etapas:
- Se existir `.agents/CONTEXTO.md`, leia e use como pano de fundo (nunca leia o
  `CONTEXTO.md` de outro projeto).
- Se existir `.agents/TEAM.md`, use como pré-seleção padrão do menu de etapas
  em vez do padrão fixo descrito em `ORQUESTRADOR.md`.

Siga a mecânica de disparo de subagentes descrita em `ORQUESTRADOR.md`:
persona e artefatos por caminho, `model` explícito conforme
`.agents/MODELOS.md`, saídas gravadas em `.agents/.pipeline-run/`.
