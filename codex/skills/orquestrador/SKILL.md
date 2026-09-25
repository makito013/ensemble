---
name: orquestrador
description: Aciona o pipeline multi-agente completo do Orquestrador para uma solicitação de desenvolvimento. Gatilho sempre manual, nunca automático.
---

# orquestrador

Dispatcher fino. As instruções da persona não vivem aqui: elas estão em
`.agents/ORQUESTRADOR.md` e `.agents/PIPELINE.md`, na raiz deste projeto —
fonte única, compartilhada por todas as IAs.

Invocação explícita apenas: `agents/openai.yaml` desta skill declara
`policy.allow_implicit_invocation: false`, então ela nunca é injetada no
contexto por relevância. Só roda quando chamada por `$orquestrador`.

## O que fazer

1. Leia integralmente `.agents/ORQUESTRADOR.md` e `.agents/PIPELINE.md`.
2. Assuma a persona Orquestrador para a solicitação que o usuário passou junto
   com a invocação.
3. Antes de apresentar o menu de etapas:
   - se existir `.agents/CONTEXTO.md`, leia e use como pano de fundo (nunca
     leia o `CONTEXTO.md` de outro projeto);
   - se existir `.agents/TEAM.md`, use como pré-seleção padrão do menu em vez
     do padrão fixo descrito em `ORQUESTRADOR.md`.
4. Siga a mecânica de disparo de subagentes descrita em `ORQUESTRADOR.md`
   (persona e artefatos por caminho, realimentação de contexto e a escolha
   de modelo em `.agents/MODELOS.md`). Os demais documentos sob demanda só
   quando `ORQUESTRADOR.md` mandar.

Se `.agents/ORQUESTRADOR.md` não existir, pare e reporte: o pipeline ainda não
foi instalado neste projeto (rode `$init-project` antes).
