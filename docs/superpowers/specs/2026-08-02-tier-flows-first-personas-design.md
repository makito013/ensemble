# Tier explícito + disciplina flows-first nas personas

Data: 2026-08-02
Repositório: `agentes-pipeline` (fonte dos templates `agentes/`, `commands/` e `gemini/skills/`)

## Objetivo

Um colega do Bruno usa um setup de "tech lead autônomo" pro Claude Code
(`.escritorio/attachments/1785870756-0f8fdc06/agente-tech-lead-setup.md`)
com dois conceitos de processo interessantes pro nosso pipeline multi-agente:

1. **Tier** (`spike`/`feature`/`critical`) — classifica quanto rigor/cerimônia
   uma demanda merece, ortogonal à escolha de quais etapas rodar.
2. **Flows-first** — antes de qualquer BDD/TDD, mapeia os fluxos de
   sucesso/erro **um a um**, com aprovação a cada fluxo, em vez de assumir o
   conjunto inteiro de uma vez.

Este spec adapta esses dois conceitos pras personas Analista, BDD, Dev, QA e
Orquestrador do `agentes-pipeline` — tanto no formato Claude (`agentes/*.md`,
`commands/orquestrador.md`) quanto no formato Gemini/Antigravity
(`gemini/skills/{analista,bdd,dev,qa,orquestrador}/SKILL.md`), que hoje
mantêm paridade de conteúdo (checada por
`tests/gemini-orquestrador-paridade.test.sh` e `tests/gemini-skills.test.sh`).

O documento do colega também descreve uma camada de segurança separada
(hook `guard.sh` + `settings.json` com sandbox/allow-deny list) para uso como
"agente tech lead" autônomo de sessão inteira — **isso é um sub-projeto
independente, fora do escopo deste spec**, tratado depois numa spec própria
(decisão do Bruno: personas primeiro, segurança depois).

**Fora de escopo:**
- O **modo** `discuss`/`execute` e o STOP-gate formal de fork de arquitetura
  no Arquiteto — avaliado como Abordagem 3 e descartado pelo Bruno em favor
  da Abordagem 2 (tier + flows-first, sem modo sticky). Pode ser revisitado
  depois como spec própria se fizer falta na prática.
- Qualquer mudança na camada de segurança (`guard.sh`, `settings.json`,
  sandbox) — sub-projeto separado.
- A pasta-fonte deste repo (`agentes/`) e a estrutura instalada (`.agents/`)
  — inalteradas por este spec; é só conteúdo de persona.

---

## Peça 1 — Tier explícito no Analista

`agentes/ANALISTA.md` e `gemini/skills/analista/SKILL.md` ganham um novo
campo no "Output padrão", **ao lado** (não em substituição) da já existente
"Estimativa de complexidade" — são eixos diferentes: complexidade mede
dificuldade, tier mede quanto processo/cerimônia a demanda merece.

```markdown
### Tier da demanda
**Tier:** [spike / feature / critical]
**Justificativa:** ...
```

Critério de classificação (mesmo do documento original, adaptado):
- **spike** — validação descartável, não vai pra produção. Só fluxo feliz,
  zero decisão de infra/arquitetura.
- **feature** — código de produção. Fluxos sucesso+erro, BDD quando ativo,
  gates de build/test.
- **critical** — pagamento, autenticação, dados sensíveis ou ação
  irreversível. Tudo do `feature` **+** recomendação forte da etapa 10
  (Segurança), mesmo que o perfil escolhido não seja `B3`/`S`.

**Ordem real do pipeline:** o Orquestrador apresenta e confirma o menu de
perfil **antes** de despachar qualquer etapa — inclusive a etapa 1
(Analista), que só roda depois do menu confirmado (ver
`agentes/ORQUESTRADOR.md`, "Como você inicia uma sessão"). Ou seja, o
Analista não pode ser quem sugere o tier no momento do menu, porque ainda
não rodou.

Por isso o tier tem **dois momentos**:
1. **No menu (novo):** o próprio Orquestrador, ao ler a solicitação bruta do
   Bruno pra montar o menu, já faz uma leitura rápida de tier (mesma lógica
   dos critérios abaixo, só que num primeiro olhar) e mostra essa sugestão
   **junto** do menu de perfis rápidos (P/F/U/T/S/B1/B2/B3) — Bruno confirma
   ou ajusta os dois juntos, mesma interação que já existe hoje só pra
   perfil.
2. **Na etapa 1 (Analista), depois de rodar:** o Analista faz sua própria
   leitura, mais informada, e registra no "Tier da demanda" do output
   padrão. Se divergir do tier confirmado no menu, sinaliza a divergência ao
   Orquestrador (mesmo padrão que já usa pra ambiguidades) em vez de
   sobrescrever silenciosamente — o Orquestrador decide se vale reabrir a
   conversa com o Bruno ou seguir.

O tier confirmado (e qualquer divergência sinalizada pelo Analista) entra no
"log de contexto acumulado" que já é passado a cada etapa (mecânica
existente, sem mudança de transporte).

O tier **não força automaticamente** um perfil — a relação entre os dois é
só documentada em `agentes/PIPELINE.md` (compartilhado com o lado Gemini, já
que o Orquestrador Gemini referencia esse mesmo arquivo desde a unificação
de `.agents/`): perfis como `[P]`/`[B1]` já tendem a ser `spike`, `[S]`/`[B3]`
já tendem a ser `critical`, mas o Bruno pode escolher qualquer combinação.

## Peça 2 — Flows-first no BDD

`agentes/BDD.md` e `gemini/skills/bdd/SKILL.md` mudam de "gera todos os
cenários Gherkin de uma vez" para um protocolo em duas fases:

**Fase 1 — alinhamento de fluxos (novo).** Propõe **um fluxo por vez**, na
ordem sucesso → alternativos → erro, no formato:
- **Nome:** "X faz Y"
- **Ator:** quem inicia
- **Pré-condição:** estado do sistema antes
- **Passos:** sequência observável
- **Resultado esperado:** pós-estado + resposta visível
- **Efeitos colaterais:** banco, filas, e-mails, logs, chamadas externas

Espera aprovação do Bruno a cada fluxo antes de propor o próximo — não
avança sem aprovação explícita.

**Regra de granularidade:** 1 fluxo = 1 caso ponta-a-ponta do usuário, não 1
endpoint/função (ex.: "usuário completa cadastro" — cadastro → confirmação →
login —, não "POST /signup" isolado, que não exercita a cadeia inteira).

**Fase 2 — conversão pra Gherkin (existente, sem mudança).** Só depois de
todos os fluxos relevantes aprovados, cada um vira cenário(s) Gherkin no
formato que o BDD já usa hoje (`Feature`/`Scenario`/`Given`/`When`/`Then`,
priorizado P0/P1/P2) — a saída final não muda, só ganha essa etapa de
alinhamento antes.

Em tier `spike`, a etapa BDD normalmente nem roda (perfis que a excluem já
cobrem isso); se ativada mesmo assim, aplica a fase 1 de forma leve (só o
fluxo feliz, sem alternativos/erro).

## Peça 3 — Sucesso antes de erro em Dev e QA

`agentes/DEV.md`/`gemini/skills/dev/SKILL.md` e
`agentes/QA.md`/`gemini/skills/qa/SKILL.md` ganham uma regra: quando há
cenários BDD disponíveis (fluxos de sucesso e de erro), implementa/testa os
de **sucesso primeiro, por completo, antes de começar os de erro** — em vez
de misturar sucesso e erro na mesma leva. Sem cenários BDD (etapa não
ativada), a ordem já natural do Dev (implementar o pedido, tratar erros
previsíveis) continua igual — a regra só se aplica quando há fluxos
explícitos pra ordenar.

## Peça 4 — Bug fora do escopo encontrado no meio do trabalho

Regra nova, ausente hoje em qualquer persona: se BDD, Dev ou QA encontrar um
bug, inconsistência ou código quebrado que **não é o alvo da tarefa atual**,
o protocolo é:

1. **Para** a implementação da parte afetada
2. **Reporta** o achado claramente ao Orquestrador
3. **Apresenta 2-3 opções**: corrigir agora (dentro desta tarefa) / abrir
   tarefa separada / pular
4. **Espera** a decisão do Bruno
5. **Nunca corrige silenciosamente**

Repetida de forma autocontida em `agentes/BDD.md`, `agentes/DEV.md`,
`agentes/QA.md` e seus equivalentes Gemini — mesmo padrão já usado pra
regra de nomenclatura em inglês (cada subagente só recebe o conteúdo do
próprio arquivo de persona, então a regra precisa estar em cada um, não só
central). `agentes/PIPELINE.md` ganha uma nota citando onde ela está
repetida, no mesmo estilo da nota que já existe pra convenção de idioma do
código.

Esta regra é distinta da seção "Quando o plano está errado" que o `DEV.md`
já tem — aquela é sobre o **plano do TL** estar inviável; esta é sobre
encontrar algo **fora do escopo da tarefa** que não tem relação com o plano
em si.

---

## Testes

Este repo testa personas/skills por `grep` de padrões esperados no texto
(sem framework — ver `tests/team-md.test.sh`, `tests/subagentes-modelo.test.sh`,
`tests/gemini-orquestrador-paridade.test.sh`, `tests/gemini-skills.test.sh`
como referência de estilo). Este spec segue o mesmo padrão:

- **Novo teste** `tests/tier-flows-first.test.sh`: verifica que
  `agentes/ANALISTA.md` tem o campo "Tier da demanda" com as 3 opções;
  que `agentes/BDD.md` tem a disciplina de propor um fluxo por vez com
  aprovação e a regra de granularidade; que `agentes/DEV.md` e
  `agentes/QA.md` têm a regra de sucesso-antes-erro; que os quatro têm a
  regra de "bug fora do escopo" (ou uma referência textual equivalente); e
  que `agentes/ORQUESTRADOR.md` exibe o tier junto do menu de perfil.
- **Extensão** de `tests/gemini-orquestrador-paridade.test.sh` e/ou um novo
  `tests/gemini-tier-flows-first-paridade.test.sh`: mesmas checagens nos 5
  arquivos `gemini/skills/{analista,bdd,dev,qa,orquestrador}/SKILL.md`,
  garantindo que a paridade Claude/Gemini não quebra (mesmo risco que já
  causou uma extensão de escopo não-planejada na branch anterior de
  `.agents/`).
- Rodar a suíte ampla existente (`tests/*.test.sh`, `commands/commands.test.sh`,
  `scripts/*.test.sh`) ao final, pra garantir que nada foi quebrado.

## Documentação

`README.md`/`AGENTS.md` não precisam de menção — tier/flows-first são
detalhe de processo interno das personas, não afetam a instalação ou a
estrutura de pastas. Se o Bruno quiser uma nota rápida no README sobre a
existência do tier, isso é opcional e pode ser decidido no plano.
