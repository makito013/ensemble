---
name: orquestrador-refinar
description: Roda só o Time de Refinamento — planeja uma demanda, antecipa os problemas do desenvolvimento (pre-mortem) e entrega o documento de refinamento (HTML com o quê, onde, por quê, dúvidas respondidas e decisões pré-autorizadas), deixando a tarefa pronta no quadro para qualquer dev desenvolver depois sem voltar a perguntar. Gatilho sempre manual, nunca automático.
---

# orquestrador-refinar

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
`.claude/commands/orquestrador-refinar.md`, na raiz deste projeto — instalado pelo
`init-project` para qualquer IA e fonte única, compartilhada por todas.

Invocação explícita apenas: `agents/openai.yaml` desta skill declara
`policy.allow_implicit_invocation: false`, então ela nunca é injetada no
contexto por relevância. Só roda quando chamada por `$orquestrador-refinar`.

## O que fazer

1. Leia integralmente `.claude/commands/orquestrador-refinar.md`. Ignore o frontmatter YAML
   (`description`, `argument-hint`, `model`): é metadado do Claude Code.
2. Siga as instruções do corpo desse arquivo, tratando cada `$ARGUMENTS`
   como o texto que o usuário passou junto com a invocação (vazio se ele não
   passou nada).
3. Onde o arquivo citar um comando do Claude Code (`/orquestrador`,
   `/init-project`, `/orquestrador-refinar` …), o equivalente aqui é a skill de mesmo nome
   invocada com `$` (`$orquestrador`, `$init-project`, `$orquestrador-refinar` …).

Se `.claude/commands/orquestrador-refinar.md` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode `$init-project`
antes).
