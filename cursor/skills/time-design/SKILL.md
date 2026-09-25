---
name: time-design
description: Inicia uma sessão standalone do Time de Design (UX/UI), fora de qualquer pipeline principal em andamento. Gatilho sempre manual, nunca automático.
disable-model-invocation: true
---

# time-design

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
`.claude/commands/time-design.md`, na raiz deste projeto — instalado pelo
`init-project` para qualquer IA e fonte única, compartilhada por todas.

`disable-model-invocation: true` no frontmatter é intencional: esta skill nunca
dispara sozinha por relevância de contexto. Ela aparece na lista de `/` e só
roda quando o usuário a chama pelo nome (`/time-design`).

## O que fazer

1. Leia integralmente `.claude/commands/time-design.md`. Ignore o frontmatter YAML
   (`description`, `argument-hint`, `model`): é metadado do Claude Code.
2. Siga as instruções do corpo desse arquivo, tratando cada `$ARGUMENTS`
   como o texto que o usuário passou junto com o comando (vazio se ele não
   passou nada).
3. Onde o arquivo citar outro comando (`/orquestrador`, `/init-project` …),
   o equivalente aqui é a skill de mesmo nome na lista de `/`.

Se `.claude/commands/time-design.md` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode `init-project`
antes).
