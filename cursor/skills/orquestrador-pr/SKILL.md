---
name: orquestrador-pr
description: Revisa um PR local (branch vs. base) sem depender do MCP do GitHub, usando Revisor e Segurança como subagentes, e consolida um veredito único de merge. Gatilho sempre manual, nunca automático.
disable-model-invocation: true
---

# orquestrador-pr

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
`.claude/commands/orquestrador-pr.md`, na raiz deste projeto — instalado pelo
`init-project` para qualquer IA e fonte única, compartilhada por todas.

`disable-model-invocation: true` no frontmatter é intencional: esta skill nunca
dispara sozinha por relevância de contexto. Ela aparece na lista de `/` e só
roda quando o usuário a chama pelo nome (`/orquestrador-pr`).

## O que fazer

1. Leia integralmente `.claude/commands/orquestrador-pr.md`. Ignore o frontmatter YAML
   (`description`, `argument-hint`, `model`): é metadado do Claude Code.
2. Siga as instruções do corpo desse arquivo, tratando cada `$ARGUMENTS`
   como o texto que o usuário passou junto com o comando (vazio se ele não
   passou nada).
3. Onde o arquivo citar outro comando (`/orquestrador`, `/init-project` …),
   o equivalente aqui é a skill de mesmo nome na lista de `/`.

Se `.claude/commands/orquestrador-pr.md` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode `init-project`
antes).
