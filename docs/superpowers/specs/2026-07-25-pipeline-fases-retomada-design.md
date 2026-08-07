# Fases de execução + estado persistido do pipeline (retomada após /clear)

Data: 2026-07-25
Repositório: `agentes-pipeline` (fonte dos templates `agentes/`, `commands/` e `gemini/skills/`)

## Objetivo

O Orquestrador acumula, ao longo de um pipeline longo, o relatório completo de
cada etapa (Analista, PO, Arquiteto, TL, Dev, QA, Revisor...) só na conversa —
o "log do contexto acumulado" descrito em `ORQUESTRADOR.md`. Em features
grandes isso deixa o contexto pesado demais, e hoje não existe forma de
`/clear` no meio de um pipeline sem perder a posição: quais etapas já
rodaram, o que falta, e o que fazer a seguir.

Este spec traz, inspirado no framework GSD (Get Shit Done, para Claude Code —
que externaliza estado em arquivos e usa um comando de progresso pra dizer
exatamente onde parou e o que fazer a seguir) adaptado ao vocabulário deste
pipeline:

1. **Fases** — subdivisão de uma feature grande em entregas independentes,
   cada uma com seu próprio ciclo Dev → QA → Revisor.
2. **Estado persistido em disco** (`agentes/PIPELINE-STATE.md`) — atualizado
   automaticamente a cada etapa/fase concluída, permitindo `/clear` a
   qualquer momento sem perder a posição.
3. **`/orquestrador-status`** — comando de leitura que mostra o que já foi
   feito, o que está em aberto, e a próxima ação concreta.
4. **Retomada pelo próprio `/orquestrador`** — ao detectar um estado aberto,
   pergunta se continua de onde parou ou arquiva e começa do zero.

**Fora de escopo:** granularidade de tarefa individual dentro de uma fase
(ex: checkpoint a cada item da lista de tarefas do TL dentro do Dev) — o
Bruno confirmou que o corte relevante é a fase, não a tarefa; dentro de uma
fase, quantos disparos de Dev forem necessários acontecem em um único fôlego,
sem checkpoint intermediário. Também fora de escopo: squads alternativos e
compactação de `CONTEXTO.md` (spec separado, `2026-07-15-scan-squads-compactacao-design.md`,
ainda não implementado) — são mecanismos distintos, um é sobre memória de
projeto de longo prazo, este é sobre o estado de UM pipeline em execução.

---

## A. Terminologia: "fase" ≠ "etapa"

"Etapa" já é o nome das 10 etapas do pipeline (Analista=etapa 1, PO=etapa 2,
..., Segurança=etapa 10 — tabela em `PIPELINE.md`/`ORQUESTRADOR.md`). Para não
colidir, a subdivisão nova dentro da execução se chama **fase**.

- Fases só existem dentro da etapa de execução (etapas 7-9: Dev/QA/Revisor).
  As etapas de planejamento (1-6: Analista/PO/Arquiteto/BDD/Designer/TL) rodam
  **uma vez só**, cobrindo a feature inteira — são elas que decidem se cabe
  dividir em fases.
- **Gatilho:** o Arquiteto (etapa 3) e/ou o TL (etapa 6) decidem, durante o
  próprio planejamento, se a feature é grande/complexa o suficiente para não
  caber num ciclo único de Dev→QA→Revisor. Se sim, o plano entregue já vem
  dividido em fases nomeadas, cada uma com um objetivo próprio (ex: "Fase 1 —
  Backend do carrinho", "Fase 2 — Integração com pagamento", "Fase 3 — UI de
  checkout"). Feature simples continua sem fase nenhuma — pipeline linear de
  hoje, sem mudança de comportamento.
- **Ciclo por fase:** cada fase roda seu próprio Dev → QA → Revisor
  (cada etapa só se estiver ativa no perfil da sessão, igual hoje). O loop de
  retrabalho (QA/Revisor reprova → volta pro Dev) fica contido dentro da
  fase — não afeta as demais.
- Uma fase só é marcada como concluída quando o Revisor (se ativo; senão, o
  QA; senão, o próprio Dev) aprova a entrega daquela fase.
- **Segurança (etapa 10) roda uma vez só, no final**, depois de todas as
  fases entregues — audita a feature inteira de uma vez, não fase a fase.

Dev, QA e Revisor recebem, quando há fases definidas, o escopo de **uma única
fase** por disparo — não a feature inteira. Isso já é natural na forma como
são disparados hoje (cada disparo é uma chamada isolada de subagente); a
mudança é só sobre qual fatia do trabalho cada disparo cobre.

---

## B. Estado persistido: `agentes/PIPELINE-STATE.md`

### Formato

```markdown
# Estado do Pipeline — <resumo curto da tarefa original>

Iniciado em: <data>
Perfil ativo: <perfil> (<lista de etapas ativas>)

## Planejamento
- [x] 1. Analista — <resumo condensado, 2-3 linhas>
- [x] 2. PO — <resumo>
- [x] 3. Arquiteto — <resumo, inclui a divisão em fases quando houver>
- [x] 6. TL — <resumo, plano por fase>

## Fases
- [x] Fase 1 — <nome> — concluída (Dev → QA → Revisor aprovado)
      Resumo do que foi entregue: <2-4 linhas>
- [ ] Fase 2 — <nome> — EM ANDAMENTO (próxima ação: <ação concreta>)
- [ ] Fase 3 — <nome> — pendente

## Próxima ação concreta
<frase única, acionável — ex: "Rodar QA da Fase 2">
```

Quando a feature não foi dividida em fases, a seção "Fases" não aparece — o
arquivo só tem "Planejamento" e a "Próxima ação concreta" aponta direto pra
etapa 7/8/9 linear.

### Regras de escrita

- O Orquestrador grava/atualiza este arquivo **automaticamente** — sem
  comando manual — depois de cada etapa de planejamento concluída, e depois
  de cada Dev/QA/Revisor dentro de uma fase (nos pontos de aprovação ou
  reprovação).
- Os resumos são condensados (poucas linhas cada), não o relatório completo
  do subagente — é a mesma função do "log do contexto acumulado" de hoje, só
  que persistida em disco em vez de só viver na conversa. É isso que reduz o
  que o Orquestrador precisa carregar ao vivo: ele lê o `PIPELINE-STATE.md`
  em vez de reter cada relatório inteiro na própria janela de contexto.
- Existe **um** `PIPELINE-STATE.md` em aberto por vez, por projeto (sem
  suporte a múltiplos pipelines paralelos nesta versão — confirmado com o
  Bruno).

### Ciclo de vida

- Quando o pipeline inteiro termina (todas as fases concluídas + Segurança,
  se ativa, ou a etapa final do fluxo linear sem fases), o Orquestrador
  **arquiva** o arquivo em `agentes/.pipeline-history/<slug-da-tarefa>-<data>.md`
  — nunca apaga — e o "slot" fica livre para o próximo `/orquestrador`.
- Se `/orquestrador` for chamado com um `PIPELINE-STATE.md` já aberto (de uma
  tarefa diferente da que está sendo pedida agora), o Orquestrador avisa e
  pergunta: continuar o que está em aberto, ou arquivar e começar um pipeline
  novo? Nunca decide sozinho, nunca sobrescreve silenciosamente.
- Se o arquivo existir mas estiver malformado ou incompleto (editado à mão,
  versão antiga, seções faltando), o Orquestrador não trava a sessão: avisa
  que não conseguiu interpretar o estado, preserva o arquivo bruto (renomeia
  para `.corrompido-<data>` em vez de sobrescrever) e oferece começar do
  zero.
- `agentes/PIPELINE-STATE.md` e `agentes/.pipeline-history/` são dado de
  projeto, igual `CONTEXTO.md`/`TEAM.md` — nunca tocados pelo instalador
  (`/init-project`), nem no fluxo normal nem no `--update`.

---

## C. Comandos e retomada

### `/orquestrador-status` (novo, só leitura)

Lê `agentes/PIPELINE-STATE.md` e mostra:
- Etapas de planejamento concluídas (resumo de cada uma)
- Fases: quais concluídas, qual está em andamento, quais pendentes
- A próxima ação concreta

Se não existir nenhum `PIPELINE-STATE.md`, informa que não há pipeline em
aberto no projeto atual. Não altera nada — pode ser chamado a qualquer
momento, inclusive logo após um `/clear`, só para lembrar onde parou antes de
decidir continuar.

### Retomada via `/orquestrador` (sem comando novo dedicado)

Ao ser chamado, `/orquestrador` passa a checar `agentes/PIPELINE-STATE.md`
**antes** de montar o menu de etapas:

- **Não existe:** fluxo de hoje, sem mudança — apresenta o menu de etapas do
  zero.
- **Existe:** mostra o mesmo resumo do `/orquestrador-status` e pergunta:
  *"Continuar de onde parei (<próxima ação concreta>) ou arquivar e começar
  um pipeline novo?"*
  - Se continuar: pula direto para a próxima ação concreta (ex: disparar o
    QA da Fase 2), reconstruindo o contexto necessário a partir dos resumos
    já salvos no `PIPELINE-STATE.md` — não do histórico da conversa, que pode
    nem existir mais depois de um `/clear`.
  - Se começar do zero: arquiva o estado atual (mesma regra da seção B) antes
    de seguir com o menu normal.

Fluxo resultante para o Bruno: termina a Fase 1 → `/clear` → `/orquestrador`
→ o Orquestrador já retoma direto na Fase 2, sem precisar reexplicar nada.

### Paridade Antigravity/Gemini

O repo já mantém os comandos do Orquestrador espelhados nos dois formatos
(`orquestrador-init`, `orquestrador-fix`, `orquestrador-team` têm equivalente
em `gemini/skills/`, com teste de paridade dedicado —
`tests/gemini-orquestrador-paridade.test.sh`). `/orquestrador-status` recebe o
mesmo tratamento: novo `gemini/skills/orquestrador-status/SKILL.md`.

---

## D. Arquivos alterados

**Novos:**
- `commands/orquestrador-status.md`
- `gemini/skills/orquestrador-status/SKILL.md`

**Alterados:**
- `agentes/ORQUESTRADOR.md` — detecção de estado aberto no início da sessão;
  gravação/atualização automática do `PIPELINE-STATE.md` a cada
  etapa/fase concluída; arquivamento ao final do pipeline.
- `agentes/PIPELINE.md` — documenta o conceito de "Fase" (distinção de
  "Etapa"), o formato e ciclo de vida do `PIPELINE-STATE.md`.
- `agentes/ARQUITETO.md` — instrução para propor divisão em fases quando a
  feature for grande o suficiente.
- `agentes/TL.md` — instrução para entregar o plano de implementação
  organizado por fase quando o Arquiteto (ou o próprio TL) identificar a
  necessidade.
- `agentes/DEV.md`, `agentes/QA.md`, `agentes/REVISOR.md` — nota curta:
  quando há fases definidas, cada disparo trabalha só na fase indicada.
- Espelhos correspondentes em `gemini/skills/{orquestrador,arquiteto,tl,dev,qa,revisor}/SKILL.md`.
- `README.md` — documenta `/orquestrador-status` e o conceito de fases.
- `claude/skills/init-project/SKILL.md` — adiciona `PIPELINE-STATE.md` e
  `.pipeline-history/` à frase que já lista `CONTEXTO.md`/`TEAM.md` como
  dado de projeto nunca tocado pelo instalador (frase adicional, não muda a
  mecânica de instalação).

**Sem mudança necessária:**
- `scripts/init-manifest-diff.sh` — `commands/orquestrador-status.md` cai
  automaticamente dentro do que `/init-project` já copia de `COMMANDS_DIR`
  (glob `*.md`, sem lista fixa de nomes) e dentro do que `tracked_files()` já
  rastreia para `.claude/commands/*`. Nenhuma mudança de script necessária.

---

## E. Testes

Seguindo o padrão já existente (`tests/*.test.sh`, scripts bash com checagens
`grep`-based de conteúdo, sem framework de teste dedicado):

- Novo `tests/pipeline-state.test.sh` verificando:
  - `ORQUESTRADOR.md` documenta a checagem de `PIPELINE-STATE.md` no início
    da sessão e a pergunta continuar/arquivar.
  - `PIPELINE.md` documenta o formato do `PIPELINE-STATE.md` e a distinção
    fase/etapa.
  - `commands/orquestrador-status.md` e seu espelho
    `gemini/skills/orquestrador-status/SKILL.md` existem com o conteúdo
    esperado (nome do comando, menção a "só leitura").
  - `ARQUITETO.md` e `TL.md` mencionam a divisão em fases.
- Reaproveitar o padrão de `tests/gemini-orquestrador-paridade.test.sh` para
  garantir que o novo comando também tem paridade entre os dois lados.

---

## Ordem de implementação

1. `agentes/PIPELINE.md` — documentar terminologia (fase/etapa), formato do
   `PIPELINE-STATE.md` e seu ciclo de vida (base para todo o resto).
2. `agentes/ARQUITETO.md` e `agentes/TL.md` — instrução de dividir em fases
   quando aplicável.
3. `agentes/ORQUESTRADOR.md` — detecção de estado aberto, gravação
   automática por etapa/fase, arquivamento ao final.
4. `agentes/DEV.md`, `QA.md`, `REVISOR.md` — nota de escopo por fase.
5. `commands/orquestrador-status.md` (novo comando).
6. Espelhos Gemini de todos os itens acima (`gemini/skills/...`).
7. `README.md` — documentação do comando novo e do conceito de fases.
8. `tests/pipeline-state.test.sh` (novo) + rodar toda a suíte existente.
