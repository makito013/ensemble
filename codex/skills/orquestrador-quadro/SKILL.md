---
name: orquestrador-quadro
description: Mostra o quadro de tarefas (o que foi feito, o que está em andamento e o que está pronto para pegar, inclusive em branches de outros devs) e liga/desliga o compartilhamento via git. Gatilho sempre manual, nunca automático.
---

# orquestrador-quadro

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
`.claude/commands/orquestrador-quadro.md`, na raiz deste projeto — instalado pelo
`init-project` para qualquer IA e fonte única, compartilhada por todas.

Invocação explícita apenas: `agents/openai.yaml` desta skill declara
`policy.allow_implicit_invocation: false`, então ela nunca é injetada no
contexto por relevância. Só roda quando chamada por `$orquestrador-quadro`.

## O que fazer

1. Leia integralmente `.claude/commands/orquestrador-quadro.md`. Ignore o frontmatter YAML
   (`description`, `argument-hint`, `model`): é metadado do Claude Code.
2. Siga as instruções do corpo desse arquivo, tratando cada `$ARGUMENTS`
   como o texto que o usuário passou junto com a invocação (vazio se ele não
   passou nada).
3. Onde o arquivo citar um comando do Claude Code (`/orquestrador`,
   `/init-project`, `/orquestrador-quadro` …), o equivalente aqui é a skill de mesmo nome
   invocada com `$` (`$orquestrador`, `$init-project`, `$orquestrador-quadro` …).

Se `.claude/commands/orquestrador-quadro.md` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode `$init-project`
antes).
