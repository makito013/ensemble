---
name: orquestrador-team
description: Consulta ou edita .agents/TEAM.md — quais das 10 etapas do pipeline ficam ativas por padrão neste projeto. Gatilho sempre manual, nunca automático.
---

# orquestrador-team

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
`.claude/commands/orquestrador-team.md`, na raiz deste projeto — instalado pelo
`init-project` para qualquer IA e fonte única, compartilhada por todas.

Invocação explícita apenas: `agents/openai.yaml` desta skill declara
`policy.allow_implicit_invocation: false`, então ela nunca é injetada no
contexto por relevância. Só roda quando chamada por `$orquestrador-team`.

## O que fazer

1. Leia integralmente `.claude/commands/orquestrador-team.md`. Ignore o frontmatter YAML
   (`description`, `argument-hint`, `model`): é metadado do Claude Code.
2. Siga as instruções do corpo desse arquivo, tratando cada `$ARGUMENTS`
   como o texto que o usuário passou junto com a invocação (vazio se ele não
   passou nada).
3. Onde o arquivo citar um comando do Claude Code (`/orquestrador`,
   `/init-project`, `/orquestrador-team` …), o equivalente aqui é a skill de mesmo nome
   invocada com `$` (`$orquestrador`, `$init-project`, `$orquestrador-team` …).

Se `.claude/commands/orquestrador-team.md` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode `$init-project`
antes).
