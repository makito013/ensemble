# Pipeline de Desenvolvimento (ciclo completo)

O Orquestrador gerencia um pipeline configurável. Você escolhe quais etapas ativar por sessão.

```
[1] ANALISTA → [2] PO → [3] ARQUITETO → [4] BDD → [5] DESIGNER
                                                          ↓
                                                      [6] TL
                                                          ↓
                                                      [7] DEV
                                                          ↓
                                                      [8] QA ─── falhou ──→ volta ao DEV
                                                          ↓
                                                     [9] REVISOR ── reprovado ──→ volta ao DEV
                                                          ↓
                                                   [10] SEGURANÇA ── bloqueado ──→ volta ao DEV
                                                          ↓
                                                     ✅ FEITO
```

## Todos os Agentes

| # | Etapa | Agente | Arquivo | Obrigatório? |
|---|-------|--------|---------|--------------|
| 1 | Análise da solicitação | Analista | `.agents/ANALISTA.md` | Sempre |
| 2 | Clarificação de requisitos | PO | `.agents/PO.md` | Recomendado |
| 3 | Planejamento de arquitetura | Arquiteto | `.agents/ARQUITETO.md` | Recomendado |
| 4 | Cenários de comportamento | BDD | `.agents/BDD.md` | Opcional |
| 5 | Design de interface | Designer | `.agents/DESIGNER.md` | Opcional |
| 6 | Plano técnico + estratégia de testes | TL | `.agents/TL.md` | Recomendado |
| 7 | Implementação do código | Dev | `.agents/DEV.md` | Sempre |
| 8 | Testes unitários e integração | QA | `.agents/QA.md` | Opcional |
| 9 | Revisão: pedido vs. entregado | Revisor | `.agents/REVISOR.md` | Recomendado |
| 10 | Auditoria de segurança | Segurança | `.agents/SEGURANCA.md` | Opcional |
| — | Orquestração do pipeline | Orquestrador | `.agents/ORQUESTRADOR.md` | Sempre ativo |

## Perfis rápidos de pipeline

| Perfil | Etapas ativas |
|--------|--------------|
| 🏃 Projeto pessoal/protótipo | 1 → 7 → 9 |
| 🔧 Feature simples | 1 → 2 → 6 → 7 → 9 |
| 🏗️ Feature com UI | 1 → 2 → 3 → 5 → 6 → 7 → 9 |
| 🧪 Produção com testes | 1 → 2 → 3 → 4 → 6 → 7 → 8 → 9 |
| 🔒 Produção completa | todas (1 ao 10) |
| 🐛 Bug simples | 1 → 7 → 9 |
| 🔍 Bug complexo | 1 → 6 → 7 → 8 → 9 |
| 🔐 Bug de segurança | 1 → 6 → 7 → 8 → 9 → 10 |

## Tier da demanda

Eixo independente do perfil — perfil escolhe **quais etapas rodam**, tier
escolhe **quanto rigor/processo** a demanda merece dentro das etapas que
rodam. O Orquestrador sugere um tier no menu (leitura rápida da solicitação
bruta) e o Analista, depois de rodar, faz uma leitura mais informada e
sinaliza divergência em vez de sobrescrever — ver `.agents/ANALISTA.md`,
"Tier da demanda".

- **spike** — validação descartável, não vai pra produção. Só fluxo feliz,
  zero decisão de arquitetura/infra.
- **feature** — código de produção. Fluxos de sucesso e erro, BDD quando a
  etapa estiver ativa, gates de build/test.
- **critical** — pagamento, autenticação, dados sensíveis ou ação
  irreversível. Tudo do `feature` **+** recomendação forte da etapa 10
  (Segurança), mesmo que o perfil escolhido não inclua essa etapa.

O tier não força automaticamente um perfil — são escolhas independentes do
Bruno. Na prática, perfis como `[P]`/`[B1]` tendem a ser `spike`, e `[S]`/
`[B3]` tendem a ser `critical`, mas qualquer combinação é válida.

## Template de TEAM.md

Se `.agents/TEAM.md` existir no projeto, ele define a pré-seleção do menu de
`/orquestrador` (o Bruno ainda pode ajustar por sessão). Formato:

```
# Time padrão — <projeto>

Define a pré-seleção do menu quando /orquestrador rodar aqui.
O Bruno ainda pode ajustar por sessão — isto só muda o ponto de partida.

[x] 1. ANÁLISE — Analista
[ ] 2. CLARIFICAÇÃO — PO
[x] 3. ARQUITETURA — Arquiteto
[ ] 4. BDD
[ ] 5. UX/UI — Designer
[x] 6. TECH LEAD — TL
[x] 7. DESENVOLVIMENTO — Dev (sempre ativo, não editável)
[ ] 8. TESTES UNITÁRIOS — QA
[x] 9. REVISÃO — Revisor
[ ] 10. SEGURANÇA
```

A etapa 7 (Desenvolvimento) nunca pode ficar desmarcada — `/orquestrador-team`
recusa a edição se o Bruno tentar desativá-la.

## Template de CONTEXTO.md

`.agents/CONTEXTO.md` é a memória persistente de um projeto. Gerado/atualizado
por `/orquestrador-init` e realimentado durante o uso normal do pipeline
(ver "Como disparar cada etapa" em `ORQUESTRADOR.md`). Sempre com estas 7
seções, nesta ordem:

1. **Visão geral do projeto** — propósito, domínio, stack.
2. **Arquitetura** — camadas, padrões, decisões estruturais.
3. **Convenções de código** — estilo, nomenclatura, padrões observados no repo.
4. **Decisões importantes e histórico** — por que certas escolhas foram feitas.
5. **Integrações externas / dependências entre projetos** — ex: "consome os
   endpoints X e Y do serviço `ymci-backend`; contrato em `docs/api/...`".
   Existe para o caso de monorepo onde um projeto secundário depende de 1-2
   endpoints do produto principal, sem precisar importar o contexto inteiro
   do outro projeto.
6. **Áreas sensíveis / gotchas conhecidos** — coisas que quebram fácil, dívida
   técnica.
7. **Log de atualizações** — data, o que mudou, origem (`init` ou `pipeline`).

Ao fundir com um `CONTEXTO.md` já existente: preserva o que ainda é válido,
atualiza o que mudou, sempre registra uma linha nova na seção 7.

## Convenção: seção `## Aprendizados` nas personas

Mecanismo de aprendizado por feedback (ver "Aprendizado por feedback" em
`ORQUESTRADOR.md`): quando o Bruno corrige o comportamento de um agente
durante uma sessão e decide gravar a regra, ela vira um bullet datado numa
seção fixa:

```markdown
## Aprendizados
- <data>: <regra em forma imperativa>
```

- **Local** (só este projeto): a seção vive em `.agents/<PERSONA>.md`
  (instalado) e, se existir, `.agents/skills/<persona>/SKILL.md`.
- **Global** (repo-fonte, vale pra todo projeto futuro): a regra é
  adicionada à mesma seção em `agentes/<PERSONA>.md` (fonte) e em
  `gemini/skills/<persona>/SKILL.md`, via `/aprendizados-sync`, depois de
  aprovada.
- **Posicionamento** (lado Claude, instalado ou fonte): sempre imediatamente
  antes do bloco final (`---` + nota de ativação + linha-ponteiro `` Ver
  "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`. ``) — nunca
  depois desse bloco. Se a seção ainda não existir no arquivo, é criada
  nesse ponto; se já existir, a regra nova é só mais um bullet.
- **Fila de pendências globais** (`.agents/.aprendizados-globais-pendentes.md`,
  só existe quando pelo menos uma regra "global" foi decidida numa sessão
  fora do repo-fonte): dado de projeto, nunca tocado pelo instalador —
  agrupado por persona-alvo, processado por `/aprendizados-sync
  <caminho-do-projeto>` rodado no repo-fonte. Formato:

  ```markdown
  ## <PERSONA>.md
  - <data> (projeto: <nome-do-projeto>): <regra em forma imperativa>
  ```
- **Sob `/init-project --update`**: um arquivo de persona-fonte que carrega
  uma seção `## Aprendizados` local é uma customização como qualquer outra
  — o `init-manifest-diff.sh` vai classificá-lo como `PRESERVE` (arquivo não
  recebe mais atualizações de template automaticamente) ou `CONFLICT`
  (gera um `.new` pra merge manual), igual a qualquer outro arquivo de
  persona modificado localmente. Isso é comportamento documentado, não uma
  surpresa silenciosa.

## Fases de execução e estado do pipeline (PIPELINE-STATE.md)

"Fase" é diferente de "Etapa": etapa é uma das 10 etapas da tabela acima.
Fase é uma subdivisão que só existe dentro da execução (etapas 7-9:
Dev/QA/Revisor), usada quando uma feature é grande demais pra caber num
ciclo único.

### Quando dividir em fases

O Arquiteto (etapa 3) e/ou o TL (etapa 6) decidem, durante o próprio
planejamento, se a feature precisa ser dividida. Se sim, o plano entregue já
vem com fases nomeadas, cada uma com um objetivo próprio (ex: "Fase 1 —
Backend do carrinho", "Fase 2 — Integração com pagamento"). Feature simples
não tem fase nenhuma — pipeline linear, sem mudança de comportamento.

### Ciclo por fase

Cada fase roda seu próprio Dev → QA → Revisor (cada etapa só se estiver
ativa no perfil da sessão). O loop de retrabalho (QA/Revisor reprova → volta
pro Dev) fica contido dentro da fase — não afeta as demais. Uma fase só é
concluída quando o Revisor (se ativo; senão QA; senão o próprio Dev) aprova a
entrega dela. Segurança (etapa 10) roda uma vez só, no final, depois de
todas as fases — audita a feature inteira, não fase a fase. O loop tem um
teto de 2 voltas por fase, com escalonamento ao Bruno na 3ª tentativa e
regra anti-oscilação — ver "Teto de convergência" em `ORQUESTRADOR.md`.

### Formato de `.agents/PIPELINE-STATE.md`

```markdown
# Estado do Pipeline — <resumo curto da tarefa original>

Iniciado em: <data>
Perfil ativo: <perfil> (<lista de etapas ativas>)
Tier: <tier>

## Planejamento
- [x] 1. Analista — <resumo condensado, 2-3 linhas>
- [x] 2. PO — <resumo>
- [x] 3. Arquiteto — <resumo, inclui divisão em fases quando houver>
- [x] 6. TL — <resumo, plano por fase>

## Fases
- [x] Fase 1 — <nome> — concluída (Dev → QA → Revisor aprovado)
      Resumo do que foi entregue: <2-4 linhas>
      Voltas: <N> (gate que reprovou em cada uma: QA/Revisor)
- [ ] Fase 2 — <nome> — EM ANDAMENTO (próxima ação: <ação concreta>)
      Voltas: <N> (gate que reprovou em cada uma: QA/Revisor)
- [ ] Fase 3 — <nome> — pendente

## Próxima ação concreta
<frase única, acionável — ex: "Rodar QA da Fase 2">
```

Quando não há fases, a seção "Fases" não aparece — a "Próxima ação concreta"
aponta direto pra etapa 7/8/9 linear.

### Regras de escrita e ciclo de vida

- O Orquestrador grava/atualiza este arquivo automaticamente — sem comando
  manual — depois de cada etapa de planejamento concluída, e depois de cada
  Dev/QA/Revisor dentro de uma fase.
- Os resumos são condensados (poucas linhas cada), não o relatório completo
  do subagente — isso reduz o que o Orquestrador precisa manter na própria
  janela de contexto.
- Existe um `PIPELINE-STATE.md` em aberto por vez, por projeto.
- Quando o pipeline inteiro termina, o Orquestrador arquiva o arquivo em
  `.agents/.pipeline-history/<slug-da-tarefa>-<data>.md` — nunca apaga — e o
  slot fica livre pro próximo `/orquestrador`.
- Se `/orquestrador` for chamado com um estado já aberto de uma tarefa
  diferente, avisa e pergunta: continuar o que está aberto, ou arquivar e
  começar do zero? Nunca decide sozinho, nunca sobrescreve silenciosamente.
- Se o arquivo existir malformado ou incompleto, o Orquestrador não trava a
  sessão: avisa, renomeia para `PIPELINE-STATE.md.corrompido-<data>`
  (preserva o bruto) e oferece começar do zero.
- `.agents/PIPELINE-STATE.md` e `.agents/.pipeline-history/` são dado de
  projeto, igual `CONTEXTO.md`/`TEAM.md` — nunca tocados pelo instalador.
- O comando `/orquestrador-status` (só leitura) mostra este arquivo de forma
  resumida a qualquer momento, sem alterar nada.

Ver "Como você inicia uma sessão", "Como disparar cada etapa" e "Estado do
pipeline" em `ORQUESTRADOR.md` para a mecânica de leitura/escrita.

## Como usar

**Inicie sempre pelo Orquestrador (Claude Code):**
> `/orquestrador quero adicionar login com Google ao projeto`

O Orquestrador vai:
1. Confirmar o que entendeu
2. Apresentar o menu de etapas
3. Você marca quais quer ativar
4. Ele dispara os agentes na ordem e traz os resultados

## Convenção universal: idioma do código

Independente do idioma da conversa com o Bruno (português), todo artefato de
código produzido pelo pipeline é sempre em inglês: nomes de variáveis, funções,
classes, arquivos e pastas; comentários no código; tabelas/colunas/schemas de
banco de dados; chaves de configuração, rotas/endpoints e nomes de eventos;
mensagens de commit e nomes de branch; nomes de teste (`describe`/`it`/`test`).

Fica em português apenas: a comunicação com o Bruno (relatórios `[DEV]`,
`[QA]`, etc.) e strings visíveis ao usuário final (UI, mensagens de erro
exibidas) quando o produto for para público brasileiro — isso é decisão de
produto/i18n, não convenção de código.

Ao editar um arquivo legado que já está em português: mantém consistência
local e sinaliza a inconsistência ao Bruno em vez de migrar em massa por
conta própria (isso é refactor, fora do escopo da tarefa a menos que peçam).

Esta regra está repetida de forma autocontida em cada persona que produz ou
revisa código (`ARQUITETO.md`, `TL.md`, `DEV.md`, `QA.md`, `REVISOR.md`) porque
cada subagente recebe apenas o conteúdo do próprio arquivo de persona, não este
documento — ver "Como disparar cada etapa" em `ORQUESTRADOR.md`.

Pelo mesmo motivo, a regra de **"bug fora do escopo encontrado no meio do
trabalho"** (para, reporta, apresenta opções, espera decisão, nunca corrige
silenciosamente) está repetida de forma autocontida em `BDD.md`, `DEV.md` e
`QA.md` — as três personas mais prováveis de topar com algo assim.

Além disso, `/init-project` instala a skill `coding-standards`
(`.claude/skills/coding-standards/`, fonte em `skills/coding-standards/SKILL.md`
deste repo) — uma skill de verdade, auto-descoberta pelo Claude Code, que cobre
o caso em que código é escrito fora do pipeline (sem `/orquestrador`). Ela é
redundante de propósito com as regras acima, não uma substituição.

## Subagentes e escolha de modelo

Qualquer agente deste pipeline (inclusive o Orquestrador) pode disparar
subagentes próprios para paralelizar partes independentes do seu próprio
trabalho.

- Modelo padrão: Sonnet. Escale para Opus quando perceber complexidade real
  (refatoração ampla, lógica ambígua exigindo raciocínio profundo, código
  security-sensitive, ou quando um subagente Sonnet já não deu conta).
- **Ressalva:** o override de modelo não funciona ao disparar um *fork* — só
  ao disparar um subagente novo (`subagent_type` diferente de fork). Um fork
  sempre roda no modelo de quem o disparou. A escalação pra Opus só vale para
  subagentes "frescos".
