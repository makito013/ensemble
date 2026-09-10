## Pipeline multi-agente (`.agents/`)

Este projeto tem o pipeline multi-agente instalado em `./.agents/` (Analista →
PO → Arquiteto → BDD → Designer → TL → Dev → QA → Revisor → Segurança,
coordenados por um Orquestrador).

**O gatilho é sempre manual.** Sem ele, ignore o pipeline e siga o fluxo normal
do projeto — mesmo quando o pedido for de feature, bug fix ou refatoração.

No Codex, acione por invocação explícita da skill:

> `$orquestrador quero adicionar login com Google ao projeto`

As skills de projeto `orquestrador` e `init-project` ficam em `./.codex/skills/`
e declaram `policy.allow_implicit_invocation: false` em `agents/openai.yaml`:
nunca entram no contexto sozinhas, só quando chamadas por `$orquestrador` /
`$init-project`. Se `./.codex/skills/` não existir aqui, leia
`./.agents/ORQUESTRADOR.md` direto e assuma a persona a partir dele.

Documentos de referência (leia sob demanda, não de antemão):

- `./.agents/ORQUESTRADOR.md` — ponto de entrada, menu de etapas e mecânica de
  disparo de subagentes
- `./.agents/PIPELINE.md` — diagrama, tabela de etapas e perfis rápidos
- `./.agents/<PERSONA>.md` — instruções de cada etapa individual
