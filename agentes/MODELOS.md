# Modelos e subagentes

Carregado sob demanda: o Orquestrador consulta esta tabela ao montar cada
disparo; uma persona só precisa abrir este arquivo se for disparar
subagentes próprios.

## Regra

**Só no Claude Code.** `haiku`, `sonnet` e `opus` (e qualquer `claude-*`
num frontmatter `model:`) são nomes de modelos Claude. Fora do Claude Code
eles não valem — ver "Fora do Claude Code" abaixo.

**Sempre passe `model` explicitamente** em todo disparo de subagente no
Claude Code (`"haiku"`, `"sonnet"`, `"opus"` ou `"fable"`) — nunca dependa
do default da ferramenta, que herda o modelo da sessão principal e não é
garantido.

**A escolha do usuário vem antes da tabela** — ver "Escolha do usuário
(passo Modelos)" abaixo.

## Fora do Claude Code (Codex, Cursor, Gemini/Antigravity)

**Nunca passe nome de modelo Claude** (`haiku`, `sonnet`, `opus`, `fable`,
`claude-*`) nem troque de provedor por conta própria: numa engine que também acessa modelos
Claude (Cursor, ou Codex com outro provedor configurado), isso faz a etapa
rodar em Claude sem o usuário ter escolhido. Omita o parâmetro de modelo:
o subagente usa o modelo desta sessão, que é o que o usuário escolheu.

Leia a tabela abaixo só como **nível de esforço**: `haiku` = leve,
`sonnet` = padrão, `opus` = forte. Se a ferramenta de subagente da engine
tiver um ajuste de esforço/raciocínio (não de modelo), use-o conforme o
nível. Trocar o modelo, mesmo dentro do mesmo provedor, só pela escolha do
usuário (abaixo).

## Escolha do usuário (passo Modelos)

O passo "Modelos" do assistente (`ORQUESTRADOR.md`) — ou um pedido escrito
na demanda ou no meio do pipeline ("use opus no TL") — define o modelo por
etapa. Grave a escolha no `PIPELINE-STATE.md` (linha `Modelos:`) e aplique
em todo disparo, inclusive retrabalho e retomada depois de um `/clear`.

Precedência, por etapa:

1. **Modelo nomeado pelo usuário** ("sonnet no Dev, opus no Arquiteto",
   "fable no TL") → passe esse modelo, em qualquer engine — é o único caso
   em que fora do Claude Code um modelo Claude pode ser pedido. Se a
   ferramenta de subagente não aceitar escolher modelo ou não tiver esse,
   avise em 1 linha e rode no padrão; nunca troque em silêncio por outro.
2. **"Superior"** (nesta etapa ou em todas) → o modelo um degrau acima do
   modelo desta sessão (do Orquestrador), **na mesma família/provedor**,
   nunca abaixo do padrão da etapa:
   - **Claude Code** — escada `haiku` < `sonnet` < `opus` < `fable`:
     sessão `sonnet` → `opus`; sessão `opus` → `fable`; sessão `fable` →
     `fable` (já é o topo).
   - **Outras engines** — o modelo mais capaz da mesma família do modelo
     da sessão que a ferramenta de subagente aceita (ex.: no Cursor, com
     a sessão num modelo Grok, o Grok mais forte da lista do Cursor).
     Superior nunca vira outro provedor por inferência. Se não der para
     saber o modelo da sessão, ou a ferramenta não deixar escolher, diga
     isso no passo e pergunte qual modelo usar.
   - No passo, diga em 1 linha qual modelo "superior" vai ser nesta
     engine antes de o usuário confirmar.
3. **Padrão** → a tabela abaixo no Claude Code; o modelo da sessão nas
   outras engines.

| Modelo | Quem roda nele |
|--------|----------------|
| `haiku` | Triagem mecânica, `/orquestrador-team`, `/orquestrador-status`, `/orquestrador-quadro`, varredura por projeto do `/orquestrador-init` |
| `sonnet` | Analista, PO, BDD, Designer, TL, Refinador, Dev, QA, Revisor rápido (completo), lentes do Revisor, verificador do Revisor fora de `critical`, Segurança fora de `critical`, turnos do Grill e do Orquestrador-Design, especialistas de design (UX, Brand, Copywriter, Acessibilidade, Dev-Design), Avaliador no modo padrão, protótipos do `/orquestrador-plan` |
| `opus` | Arquiteto (inclusive OPÇÕES do `/orquestrador-plan`), Antecipador (pre-mortem: uma chamada que poupa voltas do Dev), verificador do Revisor em tier `critical`, Segurança em tier `critical`, `DESAFIANTE` e `AVALIADOR` em modo duelo (modo "Me Surpreenda") |

- **Escalonamento:** subir um degrau (sonnet → opus) só com motivo
  registrado — ex.: a mesma etapa não convergiu na 2ª volta por limitação
  de raciocínio, ou o usuário pediu. Avise o usuário ao escalar.
- **Ressalva de fork:** o override de modelo não funciona ao disparar um
  *fork* — um fork sempre roda no modelo de quem o disparou. Etapas do
  pipeline são sempre subagentes novos (`subagent_type: general-purpose`),
  nunca fork.
- No modo "Me Surpreenda" do Time de Design, `DESAFIANTE` e `AVALIADOR` em
  modo duelo sempre rodam em Opus — passe `model` explicitamente no disparo.

## Subagentes próprios

Qualquer agente deste pipeline pode disparar subagentes próprios para
paralelizar partes independentes do seu trabalho, seguindo a mesma tabela
(na dúvida, `sonnet`) e passando `model` explicitamente.
