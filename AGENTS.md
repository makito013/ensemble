# Contexto para IA

Leia isto se você foi aberto neste repositório, ou dentro de um projeto que tem uma
pasta `./.agents/` instalada a partir daqui, e não tem histórico de conversa prévio.

## O que é isto

Um conjunto de 11 "personas" (documentos de instrução em texto, não subagentes
pré-configurados via YAML) mais um documento de pipeline, usados para estruturar
tarefas de desenvolvimento em etapas: Analista → PO → Arquiteto → BDD → Designer →
TL → Dev → QA → Revisor → Segurança, coordenadas por um Orquestrador.

O gatilho é sempre manual. No Claude Code, via comando:

> `/orquestrador quero adicionar login com Google ao projeto`

No Antigravity/Gemini CLI, continua por prefixo de texto (skill discovery):

> "orquestrador: quero adicionar login com Google ao projeto"

Fora desse gatilho, não ative o pipeline; siga o fluxo normal do projeto onde
`./.agents/` está instalado.

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

1. Ponto de entrada padrão: `.agents/ORQUESTRADOR.md`. Só ative o pipeline via `/orquestrador` (Claude) ou dizendo "orquestrador: ..." (Antigravity). Sem esse gatilho, mesmo que
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
   no projeto (faz backup do `./.agents/` atual antes de sobrescrever).
6. `/aprendizados-sync` (ver "Aprendizado por feedback" no README) vive em
   `.claude/commands/aprendizados-sync.md`, não em `commands/`: comandos em
   `commands/` são copiados por `/init-project` para dentro de qualquer
   projeto instalado, mas este comando só faz sentido rodando aqui, no
   repo-fonte — ele escreve diretamente em `agentes/*.md` e
   `gemini/skills/*/SKILL.md`.
