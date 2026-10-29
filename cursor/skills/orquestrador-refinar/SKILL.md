---
name: orquestrador-refinar
description: Roda só o Time de Refinamento — planeja uma demanda, antecipa os problemas do desenvolvimento (pre-mortem) e entrega o documento de refinamento (HTML com o quê, onde, por quê, dúvidas respondidas e decisões pré-autorizadas), deixando a tarefa pronta no quadro para qualquer dev desenvolver depois sem voltar a perguntar. Gatilho sempre manual, nunca automático.
disable-model-invocation: true
---

# orquestrador-refinar

Dispatcher fino. As instruções deste comando não vivem aqui: elas estão em
`.claude/commands/orquestrador-refinar.md`, na raiz deste projeto — instalado pelo
`init-project` para qualquer IA e fonte única, compartilhada por todas.

`disable-model-invocation: true` no frontmatter é intencional: esta skill nunca
dispara sozinha por relevância de contexto. Ela aparece na lista de `/` e só
roda quando o usuário a chama pelo nome (`/orquestrador-refinar`).

## O que fazer

1. Leia integralmente `.claude/commands/orquestrador-refinar.md`. Ignore o frontmatter YAML
   (`description`, `argument-hint`, `model`): é metadado do Claude Code.
   Pelo mesmo motivo, onde o corpo mandar passar `model: "haiku"`,
   `"sonnet"`, `"opus"` ou `claude-*` a um subagente, não passe: leia
   como nível de esforço e deixe o subagente no modelo desta sessão
   (`.agents/MODELOS.md`, "Fora do Claude Code"). Nunca troque de provedor.
2. Siga as instruções do corpo desse arquivo, tratando cada `$ARGUMENTS`
   como o texto que o usuário passou junto com o comando (vazio se ele não
   passou nada).
3. Onde o arquivo citar outro comando (`/orquestrador`, `/init-project` …),
   o equivalente aqui é a skill de mesmo nome na lista de `/`.

Se `.claude/commands/orquestrador-refinar.md` não existir, pare e reporte: o pipeline ainda
não foi instalado (ou está desatualizado) neste projeto (rode `init-project`
antes).
