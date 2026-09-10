---
name: init-project
description: Instala ou atualiza o pipeline multi-agente (personas, comandos e adapters por IA) no projeto aberto. Use quando o usuário pedir init-project.
---

# init-project

Dispatcher fino. O procedimento completo de instalação vive num único lugar —
`~/agentes-pipeline/claude/skills/init-project/SKILL.md` — e é o mesmo para
qualquer IA. Esta skill existe só para que o Codex consiga acioná-lo.

Invocação explícita apenas: `agents/openai.yaml` desta skill declara
`policy.allow_implicit_invocation: false`. Instalar arquivos no projeto nunca
pode acontecer por inferência de contexto, só via `$init-project`.

## O que fazer

1. Leia integralmente `~/agentes-pipeline/claude/skills/init-project/SKILL.md`.
2. Execute os passos descritos lá, no diretório de trabalho atual, repassando
   os argumentos que o usuário informou (`--update`, `--ai <lista>`).
3. Reporte o resumo final pedido no último passo daquele arquivo — incluindo,
   quando houver, o caminho do `AGENTS.md` criado ou alterado.

Se `~/agentes-pipeline/` não existir, pare e reporte: o instalador de máquina
(`install.sh` / `install.ps1`) ainda não rodou nesta máquina.
