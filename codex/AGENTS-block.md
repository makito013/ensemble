## Pipeline multi-agente (`.agents/`)

Este projeto tem o pipeline multi-agente instalado em `./.agents/` (Analista →
PO → Arquiteto → BDD → Designer → TL → Dev → QA → Revisor → Segurança,
coordenados por um Orquestrador).

**O gatilho é sempre manual.** Sem ele, ignore o pipeline e siga o fluxo normal
do projeto — mesmo quando o pedido for de feature, bug fix ou refatoração.

No Codex, acione por invocação explícita da skill:

> `$orquestrador quero adicionar login com Google ao projeto`

As skills de projeto ficam em `./.codex/skills/` — `orquestrador`,
`init-project` e uma por comando auxiliar (`orquestrador-fix`,
`orquestrador-init`, `orquestrador-plan`, `orquestrador-pr`,
`orquestrador-status`, `orquestrador-team`, `time-design`) — e todas declaram
`policy.allow_implicit_invocation: false` em `agents/openai.yaml`: nunca entram
no contexto sozinhas, só quando chamadas por `$<nome>` (ex.: `$orquestrador`,
`$orquestrador-status`). Se `./.codex/skills/` não existir aqui, leia
`./.agents/ORQUESTRADOR.md` direto e assuma a persona a partir dele.

Documentos de referência (leia sob demanda, não de antemão):

- `./.agents/ORQUESTRADOR.md` — ponto de entrada, menu de etapas e mecânica de
  disparo de subagentes
- `./.agents/PIPELINE.md` — diagrama, tabela de etapas e perfis rápidos
- `./.agents/<PERSONA>.md` — instruções de cada etapa individual

## Padrão de código (sempre ativo, com ou sem o pipeline)

Diferente do pipeline acima, esta regra não depende de gatilho: vale para
qualquer código escrito neste projeto. Mesma regra da skill `coding-standards`
instalada para o Claude Code (`.claude/skills/coding-standards/`).

All code artifacts are always written in English, regardless of the
conversation language:

- Variable, function, class, method, file, and folder names
- Code comments
- Database tables, columns, indexes, and schema names
- Config keys, API routes/endpoints, event names
- Commit messages and branch names
- Test names (`describe`/`it`/`test`, fixtures, mocks)

**Stays in the user's language:** communication with the user (chat replies,
PR/report summaries) and end-user-facing strings (UI copy, displayed error
messages) when the product targets a non-English-speaking audience — that's a
product/i18n decision, not a coding convention.

**Legacy code already in Portuguese:** keep local consistency and flag the
inconsistency to the user instead of mass-migrating it on your own
initiative — that's a refactor outside the scope of most tasks unless asked
for explicitly.
