# Contexto para IA

Leia isto se você foi aberto neste repositório, ou dentro de um projeto que tem uma
pasta `./.agents/` instalada a partir daqui, e não tem histórico de conversa prévio.

## O que é isto

Um conjunto de 11 "personas" (documentos de instrução em texto, não subagentes
pré-configurados via YAML) mais um documento de pipeline, usados para estruturar
tarefas de desenvolvimento em etapas: Analista → PO → Arquiteto → BDD → Designer →
TL → Dev → QA → Revisor → Segurança, coordenadas por um Orquestrador.

O gatilho é sempre manual, em toda engine. Fora desse gatilho, não ative o
pipeline; siga o fluxo normal do projeto onde `./.agents/` está instalado.

| Engine | Gatilho | Mecanismo |
|--------|---------|-----------|
| Claude / Claude Code | `/orquestrador quero adicionar login com Google ao projeto` | Comando (`.claude/commands/orquestrador.md`) |
| Antigravity / Gemini CLI | `orquestrador: quero adicionar login com Google ao projeto` | Prefixo de texto (skill discovery, `.agents/skills/`) |
| Codex CLI (OpenAI) | `$orquestrador quero adicionar login com Google ao projeto` | Invocação explícita de skill de projeto (`.codex/skills/`), com `agents/openai.yaml` declarando `policy.allow_implicit_invocation: false` — a skill nunca dispara sozinha, só quando chamada por `$orquestrador`/`$init-project` |
| Cursor | `/orquestrador quero adicionar login com Google ao projeto` | Skill de projeto (`.cursor/skills/`) com `disable-model-invocation: true` no frontmatter — aparece na lista `/`, mas só roda quando chamada explicitamente |

O mesmo vale para `init-project`/`$init-project` em cada engine.

## Quais IAs estão configuradas nesta máquina (`ai-targets`)

O instalador (`install.sh` / `install.ps1`) pergunta quais IAs você usa e grava
a resposta em `~/.config/agentes-pipeline/ai-targets.json`. `claude` está
sempre na lista. Essa config é de **máquina**, não de projeto.

Ela existe porque o conjunto base de personas é o mesmo para toda IA, mas cada
engine precisa dos arquivos no seu próprio formato e lugar. `/init-project` lê
a config no início da execução (via
`bash ~/agentes-pipeline/scripts/read-ai-targets.sh`, que nunca falha e devolve
`claude` quando não há config) e materializa só os adapters das IAs
selecionadas. Adapters implementados hoje: Antigravity (copiar `gemini/skills/`
para `./.agents/skills/`), Codex (bloco delimitado em `AGENTS.md` da raiz do
projeto + copiar `codex/skills/` para `./.codex/skills/`) e Cursor (copiar
`cursor/skills/` para `./.cursor/skills/`). Detalhes por engine na tabela de
gatilhos acima.

Para mudar a seleção: rode o instalador de novo com `--ai`/`-Ai`, ou defina
`AGENTES_PIPELINE_AI_TARGETS`. Detalhes no README.

Cada etapa ativada roda como um **subagente isolado** (ferramenta `Agent`/`Task`,
`subagent_type: general-purpose`), não como você mesmo assumindo a persona inline
na conversa principal. O subagente não tem memória da conversa nem das etapas
anteriores, então o prompt de cada disparo precisa levar: (1) o conteúdo integral
do arquivo de persona da etapa (ex: `.agents/DEV.md`), (2) o contexto acumulado
das etapas já executadas, e (3) a demanda original do usuário. Detalhes da mecânica
de disparo e do log de contexto acumulado estão em `.agents/ORQUESTRADOR.md`.

## Se você está neste repositório (`agentes-pipeline`)

Este repo é **só a fonte dos templates** — não é um projeto onde o pipeline "roda".
Não invoque personas aqui. Se pedido para editar/melhorar uma persona, edite o
arquivo correspondente em `agentes/*.md` normalmente.

## Se você está num projeto com `./.agents/` instalado a partir daqui

1. Ponto de entrada padrão: `.agents/ORQUESTRADOR.md`. Só ative o pipeline via o gatilho da sua engine — ver tabela acima ("O que é isto"). Sem esse gatilho, mesmo que
   seja um pedido de feature/bug fix/refatoração, siga o fluxo normal do projeto.
2. Diagrama completo do pipeline, tabela de etapas e perfis rápidos (quais etapas
   ativar por tipo de tarefa) estão em `.agents/PIPELINE.md`.
3. Cada etapa individual tem seu próprio arquivo de instruções em `.agents/*.md`
   (ex: `.agents/DEV.md` para a etapa de implementação).
3b. `./.claude/skills/coding-standards/` (instalada pelo `/init-project` a
    partir de `skills/coding-standards/SKILL.md` deste repo) é uma skill de
    verdade — auto-descoberta pelo Claude Code, não texto injetado no prompt
    do subagente. Ela impõe código sempre em inglês em qualquer sessão do
    projeto, com ou sem o pipeline ativo. É complementar, não substitui, as
    regras de idioma já embutidas em `DEV.md`/`QA.md`/`TL.md`/`ARQUITETO.md`/
    `REVISOR.md` (essas garantem a regra especificamente quando o Orquestrador
    dispara aquele subagente, já que o subagente só recebe o conteúdo do
    próprio arquivo de persona).
4. Etapas "Sempre" obrigatórias: Analista e Dev. As demais são recomendadas ou
   opcionais dependendo do perfil escolhido — não pule etapas marcadas como
   ativas sem confirmação do usuário.
5. Este conjunto de arquivos pode ser atualizado rodando `/init-project` de novo
   no projeto (faz backup completo do `./.agents/` atual em
   `./.agents-backups/<timestamp>/` e sobrescreve só os arquivos de template,
   mantendo os dados do projeto no lugar).
6. `/aprendizados-sync` (ver "Aprendizado por feedback" no README) vive em
   `.claude/commands/aprendizados-sync.md`, não em `commands/`: comandos em
   `commands/` são copiados por `/init-project` para dentro de qualquer
   projeto instalado, mas este comando só faz sentido rodando aqui, no
   repo-fonte — ele escreve diretamente em `agentes/*.md` e
   `gemini/skills/*/SKILL.md`.
