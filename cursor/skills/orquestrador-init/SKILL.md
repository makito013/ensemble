---
name: orquestrador-init
description: Varre o(s) projeto(s) e gera/atualiza .agents/CONTEXTO.md com o máximo de contexto útil. Gatilho sempre manual, nunca automático.
disable-model-invocation: true
---

# orquestrador-init

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
`.claude/commands/orquestrador-init.md`, na raiz deste projeto — instalado pelo
`init-project` para qualquer IA e fonte única, compartilhada por todas.

`disable-model-invocation: true` no frontmatter é intencional: esta skill nunca
dispara sozinha por relevância de contexto. Ela aparece na lista de `/` e só
roda quando o usuário a chama pelo nome (`/orquestrador-init`).

## O que fazer

1. Leia integralmente `.claude/commands/orquestrador-init.md`. Ignore o frontmatter YAML
   (`description`, `argument-hint`, `model`): é metadado do Claude Code.
2. Siga as instruções do corpo desse arquivo, tratando cada `$ARGUMENTS`
   como o texto que o usuário passou junto com o comando (vazio se ele não
   passou nada).
3. Onde o arquivo citar outro comando (`/orquestrador`, `/init-project` …),
   o equivalente aqui é a skill de mesmo nome na lista de `/`.

Se `.claude/commands/orquestrador-init.md` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode `init-project`
antes).
