# Aprendizado por Feedback + Despoluição de Personas + Teto de Convergência — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remover o resíduo de projeto anterior das personas `ARQUITETO`/`TL`/`PO`/`DESIGNER`, colocar um teto de 2 voltas (com regra anti-oscilação) nos loops de reprovação do Orquestrador, e implementar um mecanismo de aprendizado por feedback onde, no fim de cada sessão, o Orquestrador lista as regras de comportamento que o Bruno decidiu seguir e grava cada uma como regra local (projeto atual) ou pendência global (fila até ser sincronizada com o repo-fonte via `/aprendizados-sync`).

**Architecture:** Documentação em markdown (personas de agente + regras de pipeline), sem código executável — mesma arquitetura de todo o repo. Toda mudança do lado Claude (`agentes/*.md`) que também existe no lado Antigravity é espelhada em `gemini/skills/*/SKILL.md`, exceto o comando `/aprendizados-sync`, que é local ao repo-fonte e nunca distribuído. Verificação por scripts bash em `tests/*.test.sh` que fazem `grep`/`grep -q` (positivo ou negativo) por frases-âncora exatas — mesmo padrão já usado no repo.

**Tech Stack:** Bash (scripts de teste), Markdown (personas, specs, comando).

## Global Constraints

- Caminho **instalado** num projeto é `.agents/` (pasta oculta) — nunca `agentes/` (isso é só o nome da pasta de templates *neste* repo-fonte). Confirmado lendo `agentes/ORQUESTRADOR.md`, `agentes/PIPELINE.md` e `claude/skills/init-project/SKILL.md`, que já usam `.agents/CONTEXTO.md`, `.agents/PIPELINE-STATE.md`, `.agents/TEAM.md`.
- `commands/*.md` (repo-fonte) é copiado **por inteiro** para `.claude/commands/` de todo projeto instalado, sem filtro de nome (`claude/skills/init-project/SKILL.md`, passos 4 e 5.6). Por isso `aprendizados-sync.md` **não** entra em `commands/` — vive só em `.claude/commands/` deste repo, nunca distribuído.
- Toda persona em `agentes/*.md` listada em `tests/subagentes-modelo.test.sh` (`PERSONAS`) precisa manter a linha exata `` Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`. `` — os espelhos em `gemini/skills/*/SKILL.md` não replicam essa linha (confirmado nos arquivos existentes).
- Convenção de teste do repo: scripts `tests/*.test.sh` com uma função `check(file, pattern, label)` que faz `grep -q -- "$pattern" "$file"` e imprime `PASS`/`FAIL`, `exit 1` se algum check falhar. Este plano introduz também `check_absent()` (mesma assinatura, invertida) — primeiro uso desse padrão no repo.
- **Achado de execução, não deste plano:** `bash tests/pipeline-state.test.sh` já falha hoje em 8 checks (2 por `agentes/PIPELINE.md` referenciar `.agents/PIPELINE-STATE.md` enquanto o teste busca a string antiga `agentes/PIPELINE-STATE.md`; 6 pelo espelho `gemini/skills/orquestrador/SKILL.md` nunca ter recebido o conteúdo de fases/retomada do plano `2026-07-25`). É dívida pré-existente, não relacionada a este plano — não tente corrigi-la aqui (fora de escopo), só não deixe que ela seja confundida com uma regressão introduzida pelas mudanças deste plano na Task 8.

---

## File Structure

**Modificados (Task 1 — despoluição):**
- `agentes/ARQUITETO.md`, `agentes/TL.md`, `agentes/PO.md`, `agentes/DESIGNER.md`

**Modificados (Task 2 — teto de convergência):**
- `agentes/ORQUESTRADOR.md`, `gemini/skills/orquestrador/SKILL.md`, `agentes/PIPELINE.md`

**Modificados (Task 3 — detecção + decisão):**
- `agentes/ORQUESTRADOR.md`, `gemini/skills/orquestrador/SKILL.md`

**Modificados (Task 4 — convenção `## Aprendizados`):**
- `agentes/PIPELINE.md`

**Novo (Task 5 — comando de sync):**
- `.claude/commands/aprendizados-sync.md`

**Modificados (Task 6 — docs):**
- `README.md`, `claude/skills/init-project/SKILL.md`

**Testes novos:**
- `tests/personas-sem-contexto-fixo.test.sh` (Task 1)
- `tests/teto-convergencia.test.sh` (Task 2)
- `tests/aprendizado-feedback.test.sh` (Tasks 3, 4, 5 — estendido a cada task)

---

## Task 1: Despoluição das personas contaminadas

**Files:**
- Modify: `agentes/ARQUITETO.md`
- Modify: `agentes/TL.md`
- Modify: `agentes/PO.md`
- Modify: `agentes/DESIGNER.md`
- Test: `tests/personas-sem-contexto-fixo.test.sh` (create)

**Interfaces:**
- Produces: nenhuma persona em `agentes/*.md` volta a conter os termos de resíduo listados abaixo — usado como base factual para o resto do plano (Task 2-6 não reintroduzem nenhum desses termos).

- [ ] **Step 1: Escrever o teste (vai falhar — o resíduo ainda existe)**

Crie `tests/personas-sem-contexto-fixo.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "FAIL: $file ainda contém '$pattern' ($label)"
    fail=1
  else
    echo "PASS: $label"
  fi
}

TERMOS=(
  "Contexto do Projeto"
  "Modelo Mental do Sistema"
  "iPad"
  "PTY"
  "isométrico"
  "Habbo"
  "Escritório Virtual"
  "ngrok"
  "tailscale"
  "na rua"
)

for f in "$ROOT"/agentes/*.md; do
  for termo in "${TERMOS[@]}"; do
    check_absent "$f" "$termo" "$(basename "$f") sem resíduo '$termo'"
  done
done

exit $fail
```

Torne o script executável: `chmod +x tests/personas-sem-contexto-fixo.test.sh`

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/personas-sem-contexto-fixo.test.sh`
Expected: várias linhas `FAIL` para `ARQUITETO.md` (Escritório Virtual, PTY, ngrok, tailscale, Modelo Mental do Sistema, Contexto do Projeto), `TL.md` (iPad, PTY, na rua — via "acessível remotamente"... confirme o texto exato, `Contexto do Projeto`), `PO.md` (Escritório Virtual, na rua, Contexto do Projeto), `DESIGNER.md` (iPad, isométrico, Habbo, Contexto do Projeto). Resto `PASS`. Exit code 1.

- [ ] **Step 3: Limpar `agentes/ARQUITETO.md`**

old_string:
```
3. **Pensar** em como o sistema evolui: hoje 5 projetos, amanhã 50
```
new_string:
```
3. **Pensar** em como o sistema evolui: hoje 5 usuários, amanhã 500
```

old_string:
````
## Questões arquiteturais que você levanta
- Como o backend descobre os projetos? (file system scan? config file? API?)
- Os agentes são processos persistentes ou sob demanda?
- Comunicação agente-a-agente: é síncrona (HTTP) ou assíncrona (fila/eventos)?
- O "Escritório Virtual" é o UI de um monolito ou um orquestrador de microserviços?
- Como isolar o state de sessão por projeto/sala?

## Modelo Mental do Sistema
```
Tablet (Browser) 
  → [HTTPS/WSS] 
  → Gateway (reverse proxy / ngrok / tailscale)
  → Backend Orquestrador
  → [IPC/PTY] → Agentes IA (Claude, Antigravity)
              → [Config] → Projetos/Salas
```

## Contexto do Projeto
Sistema que gerencia múltiplos processos de IA na máquina local, exposto remotamente, com representação visual em escritório isométrico. Deve ser extensível para novos tipos de agentes.

---
*Para ativar este agente: diga "Arquiteto:" ou "Falar com o Arquiteto"*
````
new_string:
```
## Questões que você sempre levanta
- Como os componentes se comunicam: síncrono (HTTP/RPC) ou assíncrono (fila/eventos)?
- Onde fica o estado? Quem é dono dos dados?
- Como isolar o que é domínio de negócio do que é infraestrutura?
- Qual é a estratégia de deploy? Isso afeta a arquitetura?

---
*Para ativar este agente: diga "Arquiteto:" ou "Falar com o Arquiteto"*
```

- [ ] **Step 4: Limpar `agentes/TL.md`**

old_string:
```
## Perguntas-chave que você sempre faz
- Como vai funcionar no Safari Mobile (iPad)? WebSocket tem limitações.
- PTY via SSH reverso ou túnel? Qual a latência esperada?
- O processo do Claude/Antigravity precisa estar rodando na máquina do Bruno o tempo todo?
- Autenticação: quem pode acessar o escritório pelo tablet?
- Como o backend sabe quais projetos/agentes existem? Config manual ou auto-discovery?
```
new_string:
```
## Perguntas que você sempre faz
- Como vai funcionar em condições adversas? (sem internet, timeout, dados corrompidos)
- Há limitações da plataforma alvo que afetam a implementação?
- Quais dependências externas serão necessárias? Há alternativas mais simples?
- O que acontece se essa parte falhar em produção? Há fallback?
```

old_string:
```
## Contexto do Projeto
Interface visual web que controla processos de IA (Claude Code, Antigravity) rodando na máquina local do Bruno, acessível remotamente via tablet com baixa latência e alta confiabilidade.

---
*Ativado como etapa 6 do pipeline. Recebe output do ANALISTA + ARQUITETO. Entrega plano para o DEV e estratégia para o QA.*
```
new_string:
```
---
*Ativado como etapa 6 do pipeline. Recebe output do ANALISTA + ARQUITETO. Entrega plano para o DEV e estratégia para o QA.*
```

- [ ] **Step 5: Limpar `agentes/PO.md`**

old_string:
```
Você representa o usuário final (o Bruno no tablet, na rua, gerenciando projetos) e garante que o que for construído entregue valor real. Suas responsabilidades:
1. **Definir** o que é MVP vs. nice-to-have
2. **Priorizar** funcionalidades por impacto vs. esforço
3. **Questionar** o "por quê" de cada decisão técnica
4. **Garantir** que a experiência no tablet seja cidadã de primeira classe, não afterthought
```
new_string:
```
Você representa o usuário final e garante que o que for construído entregue valor real. Suas responsabilidades:
1. **Definir** o que é MVP vs. nice-to-have
2. **Priorizar** funcionalidades por impacto vs. esforço
3. **Questionar** o "por quê" de cada decisão técnica
4. **Garantir** que a experiência do usuário seja prioridade, não afterthought
```

old_string:
```
## Perguntas-chave que você sempre faz
- Qual é o caso de uso mais crítico do dia a dia?
- O que acontece quando a conexão cai no tablet?
- Como o Bruno sabe que um agente está "travado" vs. "pensando"?
- Qual a diferença entre conversar com o Gerenciador vs. ir direto ao TL?
```
new_string:
```
## Perguntas-chave que você sempre faz
- Qual é o caso de uso mais crítico do dia a dia?
- O que acontece se essa feature falhar? O usuário fica bloqueado?
- Isso é para um usuário específico ou para todos?
- Qual é a definição de "feito" do ponto de vista do usuário?
- Existe alguma restrição de prazo ou contexto que muda a prioridade?
```

old_string:
```
## Contexto do Projeto
Escritório Virtual onde o Bruno gerencia seus projetos e agentes de IA visualmente, pelo tablet, estando fora do escritório.

---
*Para ativar este agente: diga "PO:" ou "Falar com o PO"*
```
new_string:
```
---
*Para ativar este agente: diga "PO:" ou "Falar com o PO"*
```

- [ ] **Step 6: Limpar `agentes/DESIGNER.md`**

old_string:
```
Você garante que o sistema seja prazeroso, intuitivo e bonito — especialmente em um iPad. Suas responsabilidades:
1. **Definir** a linguagem visual: estilo isométrico, paleta, tipografia
2. **Projetar** a interação: como o usuário navega entre salas/agentes
3. **Garantir** experiência touch-first (o tablet é o dispositivo primário)
```
new_string:
```
Você garante que o sistema seja prazeroso, intuitivo e bonito. Suas responsabilidades:
1. **Definir** a linguagem visual: estilo, paleta, tipografia, espaçamento
2. **Projetar** a interação: como o usuário navega e executa ações
3. **Garantir** experiência touch-first quando aplicável
```

old_string:
```
- Pensa em termos de sensação: "isso deve parecer um escritório vivo, não um dashboard"
- Questiona decisões técnicas que afetam UX: "lag de 500ms vai quebrar a sensação"
- Propõe referências visuais: "pense no Habbo Hotel mas corporativo"
- Pensa mobile-first, tablet-first
```
new_string:
```
- Pensa em termos de sensação: "isso deve parecer X, não Y"
- Questiona decisões técnicas que afetam UX: "lag de 500ms vai quebrar a sensação"
- Propõe referências visuais concretas
- Pensa mobile-first quando há contexto de dispositivo móvel
```

old_string:
```
## Perguntas e decisões que você levanta
- Qual a resolução/orientação do iPad que o Bruno usa? (landscape vs portrait)
- A cena isométrica ocupa a tela toda com painel lateral, ou divide 50/50?
- Como diferenciar visualmente agentes Claude vs Antigravity? (cor? ícone? uniforme?)
- Estado do agente: sentado = trabalhando, em pé = ocioso. O que mais? Animação? Balão?
- Chat: janela flutuante, drawer lateral, ou tela cheia?
- Navegação entre salas: clique no mapa? menu de projetos? swipe?

## Referências Visuais
- Habbo Hotel / Stardoll (isométrico retrô)
- Linear app (clean, dark mode)
- Figma's multiplayer cursors (agentes "vivos" na tela)
- Slack/Discord sidebar (lista de projetos/salas)

## Contexto do Projeto
Interface que precisa ser visualmente estimulante mas funcional. O Bruno vai usá-la no tablet enquanto está na rua — precisa ser rápida de ler, fácil de interagir com toque, e comunicar o estado dos agentes de forma imediata.

---
*Para ativar este agente: diga "Designer:" ou "Falar com o Designer"*
```
new_string:
```
## Perguntas que você sempre levanta
- Qual dispositivo é o primário? (desktop, tablet, mobile)
- Qual o contexto de uso? (escritório, rua, noite, sol forte)
- Há design system existente para seguir?
- Qual é o tom da marca? (sério, descontraído, técnico, acessível)

---
*Para ativar este agente: diga "Designer:" ou "Falar com o Designer"*
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bash tests/personas-sem-contexto-fixo.test.sh && bash tests/subagentes-modelo.test.sh`
Expected: todas as linhas `PASS`, exit code 0 nos dois (o segundo confirma que a linha-ponteiro não foi afetada pelas edições).

- [ ] **Step 8: Commit**

```bash
git add agentes/ARQUITETO.md agentes/TL.md agentes/PO.md agentes/DESIGNER.md tests/personas-sem-contexto-fixo.test.sh
git commit -m "fix: remove resíduo de projeto anterior das personas Arquiteto/TL/PO/Designer"
```

---

## Task 2: Teto de convergência nos loops de reprovação

**Files:**
- Modify: `agentes/ORQUESTRADOR.md`
- Modify: `gemini/skills/orquestrador/SKILL.md`
- Modify: `agentes/PIPELINE.md`
- Test: `tests/teto-convergencia.test.sh` (create)

**Interfaces:**
- Produces: as frases-âncora `Teto de convergência`, `Máximo 2 voltas`, `Regra anti-oscilação` em `ORQUESTRADOR.md` (e a versão sem acento/mais simples no espelho), reaproveitadas pela Task 3 (a seção "Aprendizado por feedback" referencia a escalada por anti-oscilação).

- [ ] **Step 1: Escrever o teste (vai falhar)**

Crie `tests/teto-convergencia.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
  fi
}

check "$ROOT/agentes/ORQUESTRADOR.md" 'Teto de convergência' "ORQUESTRADOR.md tem seção de teto"
check "$ROOT/agentes/ORQUESTRADOR.md" 'Máximo 2 voltas' "ORQUESTRADOR.md define o limite"
check "$ROOT/agentes/ORQUESTRADOR.md" 'Regra anti-oscilação' "ORQUESTRADOR.md tem regra anti-oscilação"
check "$ROOT/agentes/ORQUESTRADOR.md" 'candidata a regra de aprendizado' "ORQUESTRADOR.md liga anti-oscilação ao aprendizado"

check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Teto de convergência' "SKILL.md tem seção de teto"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Máximo 2 voltas' "SKILL.md define o limite"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Regra anti-oscilação' "SKILL.md tem regra anti-oscilação"

check "$ROOT/agentes/PIPELINE.md" 'Voltas:' "PIPELINE.md documenta contagem de voltas no formato do estado"
check "$ROOT/agentes/PIPELINE.md" 'teto de 2 voltas' "PIPELINE.md referencia o teto"

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/teto-convergencia.test.sh`
Expected: todas as linhas `FAIL`, exit code 1.

- [ ] **Step 3: Editar `agentes/ORQUESTRADOR.md` — seção "Loop de Retrabalho"**

old_string:
```
## Loop de Retrabalho

Se REVISOR ou SEGURANÇA encontrar problemas:
1. Apresenta os problemas ao Bruno
2. Pergunta: "Refazer automaticamente ou revisar manualmente?"
3. Se refazer: volta para a etapa correspondente com o feedback como contexto adicional

Quando há fases, esse loop fica contido dentro da fase atual — não reabre
fases já concluídas.
```
new_string:
```
## Loop de Retrabalho

Se REVISOR ou SEGURANÇA encontrar problemas:
1. Apresenta os problemas ao Bruno
2. Pergunta: "Refazer automaticamente ou revisar manualmente?"
3. Se refazer: volta para a etapa correspondente com o feedback como contexto adicional

Quando há fases, esse loop fica contido dentro da fase atual — não reabre
fases já concluídas.

### Teto de convergência

- **Máximo 2 voltas por fase** (1ª tentativa reprovada + 1 retrabalho). Se a
  2ª tentativa também for reprovada, não dispara uma 3ª automaticamente:
  apresenta ao Bruno o que ainda falha, o que mudou entre as duas tentativas,
  e uma hipótese de por que não converge (critério ambíguo, especificação
  incompleta, ou implementação errada). Bruno decide: tentar de novo com
  orientação extra, ajustar o critério, ou aceitar como está.
- **Regra anti-oscilação**: se a reprovação da 2ª tentativa cita o mesmo
  motivo da 1ª (mesmo que o Dev alegue ter corrigido), escala imediatamente
  em vez de contar como só mais uma volta — é sinal de critério mal
  especificado, não de implementação ruim. Trate essa escalada também como
  candidata a regra de aprendizado (ver "Aprendizado por feedback" abaixo).
- Registra no `.agents/PIPELINE-STATE.md`, por fase, quantas voltas
  aconteceram e qual gate (QA ou Revisor) identificou o problema em cada uma.
```

- [ ] **Step 4: Editar `gemini/skills/orquestrador/SKILL.md` — seção "Loop de Retrabalho" (sem a linha de PIPELINE-STATE.md, que esse lado ainda não rastreia)**

old_string:
```
## Loop de Retrabalho

Se REVISOR ou SEGURANÇA encontrar problemas:
1. Apresenta os problemas ao usuário
2. Pergunta: "Refazer automaticamente ou revisar manualmente?"
3. Se refazer: volta para a etapa correspondente com o feedback como contexto adicional
```
new_string:
```
## Loop de Retrabalho

Se REVISOR ou SEGURANÇA encontrar problemas:
1. Apresenta os problemas ao usuário
2. Pergunta: "Refazer automaticamente ou revisar manualmente?"
3. Se refazer: volta para a etapa correspondente com o feedback como contexto adicional

### Teto de convergência

- **Máximo 2 voltas** (1ª tentativa reprovada + 1 retrabalho). Se a 2ª
  tentativa também for reprovada, não dispara uma 3ª automaticamente:
  apresenta o que ainda falha, o que mudou entre as tentativas, e uma
  hipótese de por que não converge. O usuário decide como seguir.
- **Regra anti-oscilação**: se a reprovação da 2ª tentativa cita o mesmo
  motivo da 1ª, escala imediatamente — é sinal de critério mal especificado,
  não de implementação ruim. Trate essa escalada também como candidata a
  regra de aprendizado (ver "Aprendizado por feedback" abaixo).
```

- [ ] **Step 5: Editar `agentes/PIPELINE.md` — formato de `.agents/PIPELINE-STATE.md`, seção "Fases"**

old_string:
```
## Fases
- [x] Fase 1 — <nome> — concluída (Dev → QA → Revisor aprovado)
      Resumo do que foi entregue: <2-4 linhas>
- [ ] Fase 2 — <nome> — EM ANDAMENTO (próxima ação: <ação concreta>)
- [ ] Fase 3 — <nome> — pendente
```
new_string:
```
## Fases
- [x] Fase 1 — <nome> — concluída (Dev → QA → Revisor aprovado)
      Resumo do que foi entregue: <2-4 linhas>
      Voltas: <N> (gate que reprovou em cada uma: QA/Revisor)
- [ ] Fase 2 — <nome> — EM ANDAMENTO (próxima ação: <ação concreta>)
      Voltas: <N> (gate que reprovou em cada uma: QA/Revisor)
- [ ] Fase 3 — <nome> — pendente
```

- [ ] **Step 6: Editar `agentes/PIPELINE.md` — seção "Ciclo por fase" (referência cruzada ao teto)**

old_string:
```
### Ciclo por fase

Cada fase roda seu próprio Dev → QA → Revisor (cada etapa só se estiver
ativa no perfil da sessão). O loop de retrabalho (QA/Revisor reprova → volta
pro Dev) fica contido dentro da fase — não afeta as demais. Uma fase só é
concluída quando o Revisor (se ativo; senão QA; senão o próprio Dev) aprova a
entrega dela. Segurança (etapa 10) roda uma vez só, no final, depois de
todas as fases — audita a feature inteira, não fase a fase.
```
new_string:
```
### Ciclo por fase

Cada fase roda seu próprio Dev → QA → Revisor (cada etapa só se estiver
ativa no perfil da sessão). O loop de retrabalho (QA/Revisor reprova → volta
pro Dev) fica contido dentro da fase — não afeta as demais. Uma fase só é
concluída quando o Revisor (se ativo; senão QA; senão o próprio Dev) aprova a
entrega dela. Segurança (etapa 10) roda uma vez só, no final, depois de
todas as fases — audita a feature inteira, não fase a fase. O loop tem um
teto de 2 voltas por fase, com escalonamento ao Bruno na 3ª tentativa e
regra anti-oscilação — ver "Teto de convergência" em `ORQUESTRADOR.md`.
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bash tests/teto-convergencia.test.sh && bash tests/subagentes-modelo.test.sh`
Expected: todas `PASS`, exit code 0 nos dois.

- [ ] **Step 8: Commit**

```bash
git add agentes/ORQUESTRADOR.md gemini/skills/orquestrador/SKILL.md agentes/PIPELINE.md tests/teto-convergencia.test.sh
git commit -m "feat: teto de 2 voltas + regra anti-oscilação nos loops de reprovação"
```

---

## Task 3: Aprendizado por feedback — detecção e decisão no fim da sessão

**Files:**
- Modify: `agentes/ORQUESTRADOR.md`
- Modify: `gemini/skills/orquestrador/SKILL.md`
- Test: `tests/aprendizado-feedback.test.sh` (create)

**Interfaces:**
- Consumes: "Regra anti-oscilação" e "candidata a regra de aprendizado" (Task 2, já em `ORQUESTRADOR.md`/`SKILL.md`).
- Produces: seção `## Aprendizado por feedback` em ambos os arquivos, frase-âncora `Identifiquei estas regras`, `.agents/.aprendizados-globais-pendentes.md` — consumidas pelas Tasks 4 e 5.

- [ ] **Step 1: Escrever o teste (vai falhar)**

Crie `tests/aprendizado-feedback.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
  fi
}

# --- Task 3: detecção + decisão ---
for f in "$ROOT/agentes/ORQUESTRADOR.md" "$ROOT/gemini/skills/orquestrador/SKILL.md"; do
  check "$f" 'Aprendizado por feedback' "$(basename "$f") tem a seção"
  check "$f" 'regra de aprendizado' "$(basename "$f") menciona regra candidata"
  check "$f" 'Identifiquei estas regras' "$(basename "$f") tem o texto de decisão no resumo final"
  check "$f" '\.aprendizados-globais-pendentes\.md' "$(basename "$f") referencia a fila global"
done

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/aprendizado-feedback.test.sh`
Expected: todas `FAIL`, exit code 1.

- [ ] **Step 3: Editar `agentes/ORQUESTRADOR.md` — "Comportamento durante o pipeline"**

old_string:
```
- Mantém um **log do contexto acumulado** entre etapas (passado para cada agente)
- No final: apresenta resumo de tudo que foi feito
```
new_string:
```
- Mantém um **log do contexto acumulado** entre etapas (passado para cada agente)
- Se a fala do Bruno indicar uma correção comportamental permanente para
  algum agente ("sempre faça X", "nunca faça Y", "da próxima vez...", "isso
  está errado, deveria...") ou uma escalada por anti-oscilação (ver "Teto de
  convergência"), registra como candidata a regra de aprendizado — sem
  gravar nada ainda (ver "Aprendizado por feedback" abaixo)
- No final: apresenta resumo de tudo que foi feito, incluindo as regras de
  aprendizado candidatas identificadas na sessão, se houver alguma
```

- [ ] **Step 4: Editar `agentes/ORQUESTRADOR.md` — nova seção, inserida depois de "Loop de Retrabalho" (com o Teto de convergência da Task 2) e antes de "Bug fora do escopo reportado por uma etapa"**

old_string:
```
- Registra no `.agents/PIPELINE-STATE.md`, por fase, quantas voltas
  aconteceram e qual gate (QA ou Revisor) identificou o problema em cada uma.

## Bug fora do escopo reportado por uma etapa
```
new_string:
```
- Registra no `.agents/PIPELINE-STATE.md`, por fase, quantas voltas
  aconteceram e qual gate (QA ou Revisor) identificou o problema em cada uma.

## Aprendizado por feedback

Complementa a "Atualização de contexto sugerida" (que é sobre fatos do
projeto, vai para `.agents/CONTEXTO.md`): este mecanismo é sobre regras de
comportamento do próprio agente, propostas por você mesmo, Orquestrador, com
base no que o Bruno disse durante a sessão — nunca pelos subagentes, que não
veem a conversa ao vivo.

**Detecção (durante a sessão):** ver "Comportamento durante o pipeline"
acima — sempre que a fala do Bruno indicar uma correção comportamental ou
uma escalada por anti-oscilação, registre em memória, sem gravar nada:
- o texto da regra, em forma imperativa e reutilizável;
- qual persona ela afeta (ex: `DEV.md`, `REVISOR.md`);
- o gatilho (correção explícita vs. escalada por anti-oscilação).

Falsos positivos são esperados — o detector erra para o lado de "propor
demais". Nada é gravado sem confirmação explícita, regra a regra.

**Decisão (no resumo final):** se houver pelo menos uma regra candidata,
liste todas juntas antes de encerrar:

> "Identifiquei estas regras que você decidiu seguir nesta sessão:
> 1. {regra} (persona: {ARQUIVO.md})
> 2. {regra} (persona: {ARQUIVO.md})
> Para cada uma: gravar como regra local deste projeto, gravar como
> pendência global (revisão no repo-fonte antes de valer pra outros
> projetos), ou ignorar?"

Se nenhuma regra foi identificada, este bloco não aparece.

**Escrita local:** regra marcada "local" vai para uma seção `## Aprendizados`
em `.agents/<PERSONA>.md` (e em `.agents/skills/<persona>/SKILL.md`, se
existir) — formato e posicionamento em `.agents/PIPELINE.md` ("Convenção:
seção `## Aprendizados` nas personas").

**Fila global:** regra marcada "global" vai para
`.agents/.aprendizados-globais-pendentes.md`, agrupada por persona-alvo, até
ser processada pelo comando `/aprendizados-sync` rodado no repo-fonte.

## Bug fora do escopo reportado por uma etapa
```

- [ ] **Step 5: Editar `gemini/skills/orquestrador/SKILL.md` — "Comportamento durante o pipeline" (equivalente, "usuário" em vez de "Bruno")**

old_string:
```
- Mantém um **log do contexto acumulado** entre etapas
- No final: apresenta resumo de tudo que foi feito
```
new_string:
```
- Mantém um **log do contexto acumulado** entre etapas
- Se a fala do usuário indicar uma correção comportamental permanente para
  algum agente ("sempre faça X", "nunca faça Y", "da próxima vez...") ou uma
  escalada por anti-oscilação (ver "Teto de convergência"), registra como
  candidata a regra de aprendizado — sem gravar nada ainda (ver "Aprendizado
  por feedback" abaixo)
- No final: apresenta resumo de tudo que foi feito, incluindo as regras de
  aprendizado candidatas identificadas na sessão, se houver alguma
```

- [ ] **Step 6: Editar `gemini/skills/orquestrador/SKILL.md` — nova seção, depois de "Teto de convergência" (Task 2) e antes de "Bug fora do escopo reportado por uma etapa"**

old_string:
```
  não de implementação ruim. Trate essa escalada também como candidata a
  regra de aprendizado (ver "Aprendizado por feedback" abaixo).

## Bug fora do escopo reportado por uma etapa
```
new_string:
```
  não de implementação ruim. Trate essa escalada também como candidata a
  regra de aprendizado (ver "Aprendizado por feedback" abaixo).

## Aprendizado por feedback

Complementa a "Atualização de contexto sugerida" (fatos do projeto, vai para
`.agents/CONTEXTO.md`): este mecanismo é sobre regras de comportamento do
próprio agente, propostas por você mesmo, Orquestrador, com base no que o
usuário disse durante a sessão.

**Detecção:** ver "Comportamento durante o pipeline" acima. Registre em
memória (texto da regra, persona afetada, gatilho) — sem gravar nada.

**Decisão (no resumo final):** se houver regra candidata, liste todas antes
de encerrar: "Identifiquei estas regras que você decidiu seguir nesta
sessão: ... Para cada uma: gravar como regra local deste projeto, gravar
como pendência global, ou ignorar?"

**Escrita local:** `.agents/<PERSONA>.md` e/ou `.agents/skills/<persona>/SKILL.md`, seção `## Aprendizados`.

**Fila global:** `.agents/.aprendizados-globais-pendentes.md`, processada
depois por `/aprendizados-sync` no repo-fonte.

## Bug fora do escopo reportado por uma etapa
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bash tests/aprendizado-feedback.test.sh && bash tests/teto-convergencia.test.sh && bash tests/subagentes-modelo.test.sh`
Expected: todas `PASS`, exit code 0 nos três.

- [ ] **Step 8: Commit**

```bash
git add agentes/ORQUESTRADOR.md gemini/skills/orquestrador/SKILL.md tests/aprendizado-feedback.test.sh
git commit -m "feat: Orquestrador detecta e propõe regras de aprendizado no fim da sessão"
```

---

## Task 4: Convenção `## Aprendizados` nas personas

**Files:**
- Modify: `agentes/PIPELINE.md`
- Modify: `tests/aprendizado-feedback.test.sh`

**Interfaces:**
- Consumes: nada novo (documenta o que a Task 3 já referencia).
- Produces: frase-âncora `Convenção: seção` + formato de bullet, consumidos pela Task 5 (o comando de sync segue exatamente este formato).

- [ ] **Step 1: Estender o teste (vai falhar)**

Adicione ao final de `tests/aprendizado-feedback.test.sh`, antes de `exit $fail`:

```bash
# --- Task 4: convenção de escrita ---
check "$ROOT/agentes/PIPELINE.md" 'Convenção: seção' "PIPELINE.md documenta a convenção de Aprendizados"
check "$ROOT/agentes/PIPELINE.md" 'aprendizados-globais-pendentes' "PIPELINE.md documenta a fila global"
check "$ROOT/agentes/PIPELINE.md" 'aprendizados-sync' "PIPELINE.md referencia o comando de sync"
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/aprendizado-feedback.test.sh`
Expected: as 3 linhas novas `FAIL`, resto `PASS`.

- [ ] **Step 3: Editar `agentes/PIPELINE.md` — inserir a seção nova depois de "Template de CONTEXTO.md" e antes de "Fases de execução e estado do pipeline"**

old_string:
```
Ao fundir com um `CONTEXTO.md` já existente: preserva o que ainda é válido,
atualiza o que mudou, sempre registra uma linha nova na seção 7.

## Fases de execução e estado do pipeline (PIPELINE-STATE.md)
```
new_string:
````
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
- **Posicionamento** (lado Claude, instalado ou fonte): sempre antes da
  linha final `` Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`. ``
  — nunca depois. Se a seção ainda não existir no arquivo, é criada nesse
  ponto; se já existir, a regra nova é só mais um bullet.
- **Fila de pendências globais** (`.agents/.aprendizados-globais-pendentes.md`,
  só existe quando pelo menos uma regra "global" foi decidida numa sessão
  fora do repo-fonte): dado de projeto, nunca tocado pelo instalador —
  agrupado por persona-alvo, processado por `/aprendizados-sync
  <caminho-do-projeto>` rodado no repo-fonte.

## Fases de execução e estado do pipeline (PIPELINE-STATE.md)
````

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `bash tests/aprendizado-feedback.test.sh`
Expected: todas `PASS`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add agentes/PIPELINE.md tests/aprendizado-feedback.test.sh
git commit -m "docs: convenção da seção Aprendizados nas personas"
```

---

## Task 5: Comando `/aprendizados-sync`

**Files:**
- Create: `.claude/commands/aprendizados-sync.md`
- Modify: `tests/aprendizado-feedback.test.sh`

**Interfaces:**
- Consumes: formato da seção `## Aprendizados` e da fila `.agents/.aprendizados-globais-pendentes.md` (Task 4).
- Produces: nenhuma interface consumida por outra task — é o fim da cadeia do mecanismo.

- [ ] **Step 1: Estender o teste (vai falhar)**

Adicione ao final de `tests/aprendizado-feedback.test.sh`, antes de `exit $fail`:

```bash
# --- Task 5: comando de sync ---
check "$ROOT/.claude/commands/aprendizados-sync.md" 'aprendizados-globais-pendentes' "comando lê a fila global"
check "$ROOT/.claude/commands/aprendizados-sync.md" 'repo-fonte' "comando avisa que só roda no repo-fonte"
check "$ROOT/.claude/commands/aprendizados-sync.md" '## Aprendizados' "comando escreve na seção correta"
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/aprendizado-feedback.test.sh`
Expected: as 3 linhas novas `FAIL` (arquivo ainda não existe), resto `PASS`.

- [ ] **Step 3: Criar `.claude/commands/aprendizados-sync.md`**

Verifique antes se `.claude/commands/` já existe neste repo (`ls .claude/commands/ 2>/dev/null`); crie a pasta se não existir.

```markdown
---
description: Sincroniza um projeto e aplica as regras de aprendizado pendentes marcadas como "global" nos arquivos de persona-fonte deste repo (agentes/*.md e gemini/skills/*/SKILL.md).
argument-hint: <caminho-do-projeto>
---

Este comando só faz sentido rodando dentro do repo-fonte `agentes-pipeline`
(este repositório) — é aqui que vivem os arquivos de persona-fonte que ele
atualiza. Consulte `agentes/PIPELINE.md` (seção "Convenção: seção `##
Aprendizados` nas personas") para o formato completo.

Caminho do projeto a sincronizar:

$ARGUMENTS

Passos:
1. Leia `<caminho>/.agents/.aprendizados-globais-pendentes.md`. Se não
   existir ou estiver vazio, informe ao Bruno que não há regra pendente
   nesse projeto e pare.
2. Para cada regra pendente (agrupada por persona-alvo no arquivo),
   apresente ao Bruno: o texto da regra e a persona-alvo. Bruno responde:
   aprovar como está, editar o texto, ou descartar.
3. Regra aprovada (com ou sem edição): adicione um bullet datado na seção
   `## Aprendizados` de `agentes/<PERSONA>.md` (crie a seção, antes da linha
   final `Ver "Subagentes e escolha de modelo"...`, se ainda não existir) —
   e replique o mesmo bullet numa seção `## Aprendizados` equivalente em
   `gemini/skills/<persona>/SKILL.md` (sem a linha-ponteiro, que esse lado
   não tem).
4. Depois de decididas todas as regras do arquivo (aprovadas ou
   descartadas), reescreva `<caminho>/.agents/.aprendizados-globais-pendentes.md`
   removendo as entradas processadas. Se não sobrar nenhuma entrada, remova
   o arquivo.
5. Resuma ao Bruno: quantas regras foram aplicadas, em quais personas, e
   quantas foram descartadas.
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `bash tests/aprendizado-feedback.test.sh`
Expected: todas `PASS`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add .claude/commands/aprendizados-sync.md tests/aprendizado-feedback.test.sh
git commit -m "feat: comando /aprendizados-sync aplica regras globais pendentes nas personas-fonte"
```

---

## Task 6: Documentação (`README.md` + `init-project/SKILL.md`)

**Files:**
- Modify: `README.md`
- Modify: `claude/skills/init-project/SKILL.md`

**Interfaces:**
- Consumes: nada novo — só documenta o que as Tasks 1-5 já implementaram.

- [ ] **Step 1: Editar `README.md` — nova seção no final, depois de "Atualizando o pipeline"**

old_string:
```
## Atualizando o pipeline

Edite os arquivos em `agentes/`, `skills/` ou em `gemini/skills/` e commite.
Para reinstalar num projeto existente:

```bash
# Claude:
/init-project --update

# Antigravity (sobrescreve):
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/
```
```
new_string:
````
## Atualizando o pipeline

Edite os arquivos em `agentes/`, `skills/` ou em `gemini/skills/` e commite.
Para reinstalar num projeto existente:

```bash
# Claude:
/init-project --update

# Antigravity (sobrescreve):
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/
```

## Aprendizado por feedback

Durante uma sessão de `/orquestrador`, se o Bruno corrigir o comportamento
de um agente ("sempre faça X", "nunca faça Y"), o Orquestrador identifica
isso como candidata a regra de aprendizado e, no resumo final, pergunta se
deve gravar como regra **local** (só este projeto, seção `## Aprendizados`
em `.agents/<PERSONA>.md`) ou **global** (fica pendente em
`.agents/.aprendizados-globais-pendentes.md` até ser sincronizada com o
repo-fonte).

Para aplicar as pendências globais de um projeto às personas-fonte deste
repo, rode (aqui no repo-fonte):

```bash
/aprendizados-sync /caminho/do/projeto
```

Ele apresenta cada regra pendente para aprovação antes de gravar em
`agentes/<PERSONA>.md` e `gemini/skills/<persona>/SKILL.md`.
````

- [ ] **Step 2: Editar `claude/skills/init-project/SKILL.md` — lista de dado de projeto nunca tocado (fluxo `--update`)**

old_string:
```
   4. `.agents/CONTEXTO.md`, `.agents/TEAM.md` e `.agents/.init-manifest.json`
      nunca são tocados por este fluxo — são dados do projeto, não do
      template.
```
new_string:
```
   4. `.agents/CONTEXTO.md`, `.agents/TEAM.md`, `.agents/.init-manifest.json`
      e `.agents/.aprendizados-globais-pendentes.md` nunca são tocados por
      este fluxo — são dados do projeto, não do template.
```

- [ ] **Step 3: Editar `claude/skills/init-project/SKILL.md` — regra geral do passo 7**

old_string:
```
7. Em todos os casos, o CONTEÚDO de `.agents/CONTEXTO.md` e `.agents/TEAM.md`
   nunca é modificado, sobrescrito ou gerado pelo processo — são dados do
   projeto, não do template. No fluxo do passo 5 eles são temporariamente
```
new_string:
```
7. Em todos os casos, o CONTEÚDO de `.agents/CONTEXTO.md`, `.agents/TEAM.md`
   e `.agents/.aprendizados-globais-pendentes.md` nunca é modificado,
   sobrescrito ou gerado pelo processo — são dados do projeto, não do
   template. No fluxo do passo 5 eles são temporariamente
```

- [ ] **Step 4: Editar `claude/skills/init-project/SKILL.md` — restauração no fluxo de reinstalação completa (passo 5, item 5)**

old_string:
```
   5. Se `./.agents/.backup-{YYYYMMDD-HHMMSS}/CONTEXTO.md` existir,
      copie-o (não mova) para `./.agents/CONTEXTO.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/TEAM.md` existir, copie-o
      (não mova) para `./.agents/TEAM.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/skills/` existir (instalação
      Gemini/Antigravity presente antes do backup), copie-o (não mova,
      pasta inteira) para `./.agents/skills/` — sem essa restauração, o
      Antigravity para de descobrir os skills depois de qualquer
      atualização sem `--update`. O backup continua intacto com as
      cópias originais.
```
new_string:
```
   5. Se `./.agents/.backup-{YYYYMMDD-HHMMSS}/CONTEXTO.md` existir,
      copie-o (não mova) para `./.agents/CONTEXTO.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/TEAM.md` existir, copie-o
      (não mova) para `./.agents/TEAM.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/.aprendizados-globais-pendentes.md`
      existir, copie-o (não mova) para
      `./.agents/.aprendizados-globais-pendentes.md`. Se
      `./.agents/.backup-{YYYYMMDD-HHMMSS}/skills/` existir (instalação
      Gemini/Antigravity presente antes do backup), copie-o (não mova,
      pasta inteira) para `./.agents/skills/` — sem essa restauração, o
      Antigravity para de descobrir os skills depois de qualquer
      atualização sem `--update`. O backup continua intacto com as
      cópias originais.
```

- [ ] **Step 5: Commit**

```bash
git add README.md claude/skills/init-project/SKILL.md
git commit -m "docs: documenta aprendizado por feedback, /aprendizados-sync e a fila global no instalador"
```

---

## Task 7: Suíte completa + fechamento

**Files:**
- Nenhum arquivo novo — apenas verificação

- [ ] **Step 1: Rodar toda a suíte de testes do repositório**

Run:
```bash
for t in tests/*.test.sh commands/commands.test.sh; do
  echo "=== $t ==="
  bash "$t" || echo "FALHOU: $t"
done
```
Expected: todos os blocos terminam sem `FALHOU`, **exceto** `tests/pipeline-state.test.sh` — que já falhava antes deste plano (ver "Global Constraints", item de dívida pré-existente) e não foi tocado por nenhuma task acima. Se qualquer *outro* script falhar, é regressão deste plano — investigue antes de prosseguir.

- [ ] **Step 2: Conferir `git status` limpo**

Run: `git status`
Expected: working tree limpo (tudo commitado nas Tasks 1-6).

- [ ] **Step 3: Se algo ficou pendente, commit final**

```bash
git add -A
git commit -m "chore: fechamento da implementação de aprendizado por feedback + despoluição + teto de convergência"
```

- [ ] **Step 4: Registrar a verificação manual pendente (não automatizável em bash)**

Comunique ao Bruno que os passos abaixo só podem ser feitos rodando sessões
reais do `/orquestrador` num projeto instalado — não são checks de `grep`,
ficam fora da suíte automatizada:

1. Rodar `/orquestrador` numa tarefa qualquer, corrigir um agente no meio da
   sessão ("sempre faça X"), e confirmar que o resumo final lista a regra
   candidata e pergunta local/global/ignorar.
2. Confirmar que uma regra marcada "local" aparece na seção `## Aprendizados`
   de `.agents/<PERSONA>.md` do projeto certo, antes da linha-ponteiro.
3. Confirmar que uma regra marcada "global" aparece em
   `.agents/.aprendizados-globais-pendentes.md`, e que rodar
   `/aprendizados-sync <caminho>` aqui no repo-fonte apresenta a regra,
   aplica em `agentes/<PERSONA>.md` + espelho, e limpa a fila de origem.
4. Forçar uma reprovação repetida pelo mesmo motivo (2ª tentativa) e
   confirmar que o Orquestrador escala em vez de tentar uma 3ª vez
   automaticamente.
5. Confirmar visualmente que `agentes/ARQUITETO.md`, `TL.md`, `PO.md` e
   `DESIGNER.md` fazem sentido como personas genéricas, lendo-as do zero sem
   o contexto desta investigação.

Não feche a tarefa como 100% verificada sem isso.
