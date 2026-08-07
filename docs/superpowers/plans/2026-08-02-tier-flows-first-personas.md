# Tier + Flows-First nas Personas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar tier explícito (`spike`/`feature`/`critical`) ao Analista, disciplina flows-first ao BDD, ordem sucesso-antes-erro ao Dev/QA, e a regra de "bug fora do escopo" a BDD/Dev/QA — nos dois lados que o pipeline mantém em paridade (Claude `agentes/*.md` e Gemini/Antigravity `gemini/skills/*/SKILL.md`).

**Architecture:** Cada conceito é conteúdo de persona (prosa), não código executável — cada arquivo de persona é lido isoladamente por um subagente, então todo conteúdo novo precisa estar autocontido no próprio arquivo (mesmo padrão já usado pela regra de nomenclatura em inglês). `agentes/PIPELINE.md` (compartilhado, sem cópia no lado Gemini) documenta a versão canônica do tier e onde a regra de bug-fora-do-escopo está repetida.

**Tech Stack:** Markdown com frontmatter YAML (Gemini) / sem frontmatter (Claude). Testes em Bash puro (`grep -q` + `fail=0/1`, sem framework — ver `tests/team-md.test.sh` como referência de estilo).

## Global Constraints

- Personas Claude (`agentes/*.md`) e Gemini (`gemini/skills/*/SKILL.md`) mantêm paridade de conteúdo — toda mudança num lado tem a mudança equivalente no outro, adaptada (`Bruno` → `usuário`; Gemini não usa o padrão de rodapé `Ver "..." em \`.agents/PIPELINE.md\`.` que o Claude usa, então referências cruzadas no lado Gemini citam o conceito por nome, não o arquivo).
- `commands/orquestrador.md` **não é tocado** por este plano — ele só delega pra `.agents/ORQUESTRADOR.md`/`.agents/PIPELINE.md` (`Leia integralmente ... e assuma a persona Orquestrador`), não duplica o menu.
- O rodapé `Ver "Subagentes e escolha de modelo" em \`.agents/PIPELINE.md\`.`, presente em `agentes/{ANALISTA,BDD,DEV,QA,ORQUESTRADOR}.md` e checado por `tests/subagentes-modelo.test.sh`, nunca é removido — todo conteúdo novo é inserido **antes** dele.
- A regra de "bug fora do escopo encontrado no meio do trabalho" é distinta da seção "Quando o plano está errado" que `DEV.md` já tem (aquela é sobre o plano do TL estar inviável; esta é sobre achar algo sem relação com a tarefa atual) — são seções separadas, não substituem uma à outra.
- Testes seguem o padrão `check()` já usado neste repo: `grep -q -- "$pattern" "$file"`, acumula `fail`, `exit $fail`. Sem framework.

---

### Task 1: Tier explícito no Analista

**Files:**
- Modify: `agentes/ANALISTA.md`
- Modify: `gemini/skills/analista/SKILL.md`
- Create: `tests/tier-flows-first.test.sh`

**Interfaces:**
- Produces: a seção "Tier da demanda" (critério `spike`/`feature`/`critical`) que `agentes/PIPELINE.md` (Task 6) vai documentar de forma canônica e que `agentes/ORQUESTRADOR.md` (Task 5) vai citar no menu.

- [ ] **Step 1: Escrever o teste (vai falhar) — `tests/tier-flows-first.test.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

check() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $file não existe"
    fail=1
    return
  fi
  if ! grep -q -- "$pattern" "$file"; then
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
    return
  fi
  echo "PASS: $label"
}

# --- Task 1: Tier no Analista ---
check "$ROOT/agentes/ANALISTA.md" 'Tier da demanda' "ANALISTA.md tem seção Tier da demanda"
check "$ROOT/agentes/ANALISTA.md" '\*\*spike\*\*' "ANALISTA.md define tier spike"
check "$ROOT/agentes/ANALISTA.md" '\*\*feature\*\*' "ANALISTA.md define tier feature"
check "$ROOT/agentes/ANALISTA.md" '\*\*critical\*\*' "ANALISTA.md define tier critical"
check "$ROOT/agentes/ANALISTA.md" 'não sobrescreva' "ANALISTA.md trata divergência de tier sem sobrescrever"
check "$ROOT/gemini/skills/analista/SKILL.md" 'Tier da demanda' "analista/SKILL.md (Gemini) tem seção Tier da demanda"
check "$ROOT/gemini/skills/analista/SKILL.md" '\*\*critical\*\*' "analista/SKILL.md (Gemini) define tier critical"
check "$ROOT/gemini/skills/analista/SKILL.md" 'não sobrescreva' "analista/SKILL.md (Gemini) trata divergência de tier sem sobrescrever"

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash tests/tier-flows-first.test.sh`
Expected: FAIL em todos os `check` (nenhum dos dois arquivos tem "Tier da demanda" ainda).

- [ ] **Step 3: Editar `agentes/ANALISTA.md`**

Primeira edição — acrescente o item 7 na lista de "Missão" (depois do item 6, antes do cabeçalho seguinte):

Old:
```
6. **Estimar** complexidade inicial: Baixa / Média / Alta / Muito Alta

## Como você fala
```

New:
```
6. **Estimar** complexidade inicial: Baixa / Média / Alta / Muito Alta
7. **Declarar o tier da demanda**: `spike` / `feature` / `critical` — ver critério em "Tier da demanda" abaixo

## Como você fala
```

Segunda edição — acrescente o campo "Tier da demanda" no template de output, depois do bloco de complexidade (mesmo bloco de código markdown, antes do fechamento das crases triplas):

Old:
```
### Estimativa de complexidade
**Complexidade:** [Baixa / Média / Alta / Muito Alta]
**Justificativa:** ...
```
```

New:
```
### Estimativa de complexidade
**Complexidade:** [Baixa / Média / Alta / Muito Alta]
**Justificativa:** ...

### Tier da demanda
**Tier:** [spike / feature / critical]
**Justificativa:** ...
```
```

Terceira edição — acrescente a seção de critério de tier, antes de "## Perguntas que você sempre se faz antes de entregar":

Old:
```
## Perguntas que você sempre se faz antes de entregar
- Qual é o critério de "feito"? Como o Bruno vai saber que funcionou?
```

New:
```
## Tier da demanda

Ao lado da complexidade (que mede dificuldade), o tier mede **quanto
rigor/processo** a demanda merece — eixo independente:

- **spike** — validação descartável, não vai pra produção. Só fluxo feliz,
  zero decisão de arquitetura/infra.
- **feature** — código de produção. Fluxos de sucesso e erro, BDD quando a
  etapa estiver ativa, gates de build/test.
- **critical** — pagamento, autenticação, dados sensíveis ou ação
  irreversível. Tudo do `feature` **+** recomendação forte da etapa 10
  (Segurança), mesmo que o perfil escolhido não inclua essa etapa.

O Orquestrador já fez uma leitura rápida de tier ao apresentar o menu de
perfil, antes de você rodar. A sua leitura aqui é mais informada — se
divergir da que foi confirmada com o Bruno, **não sobrescreva
silenciosamente**: registre a divergência junto das "Ambiguidades
identificadas" acima e deixe o Orquestrador decidir se volta a perguntar ao
Bruno.

## Perguntas que você sempre se faz antes de entregar
- Qual é o critério de "feito"? Como o Bruno vai saber que funcionou?
```

- [ ] **Step 4: Editar `gemini/skills/analista/SKILL.md`**

Primeira edição — mesmo item 7 na Missão, adaptado (usuário em vez de Bruno):

Old:
```
6. **Estimar** complexidade inicial: Baixa / Média / Alta / Muito Alta

## Como você fala
```

New:
```
6. **Estimar** complexidade inicial: Baixa / Média / Alta / Muito Alta
7. **Declarar o tier da demanda**: `spike` / `feature` / `critical` — ver critério em "Tier da demanda" abaixo

## Como você fala
```

Segunda edição — campo no template de output:

Old:
```
### Estimativa de complexidade
**Complexidade:** [Baixa / Média / Alta / Muito Alta]
**Justificativa:** ...
```
```

New:
```
### Estimativa de complexidade
**Complexidade:** [Baixa / Média / Alta / Muito Alta]
**Justificativa:** ...

### Tier da demanda
**Tier:** [spike / feature / critical]
**Justificativa:** ...
```
```

Terceira edição — seção de critério, antes de "## Perguntas que você sempre se faz antes de entregar":

Old:
```
## Perguntas que você sempre se faz antes de entregar
- Qual é o critério de "feito"? Como o usuário vai saber que funcionou?
```

New:
```
## Tier da demanda

Ao lado da complexidade (que mede dificuldade), o tier mede **quanto
rigor/processo** a demanda merece — eixo independente:

- **spike** — validação descartável, não vai pra produção. Só fluxo feliz,
  zero decisão de arquitetura/infra.
- **feature** — código de produção. Fluxos de sucesso e erro, BDD quando a
  etapa estiver ativa, gates de build/test.
- **critical** — pagamento, autenticação, dados sensíveis ou ação
  irreversível. Tudo do `feature` **+** recomendação forte da etapa 10
  (Segurança), mesmo que o perfil escolhido não inclua essa etapa.

O Orquestrador já fez uma leitura rápida de tier ao apresentar o menu de
perfil, antes de você rodar. A sua leitura aqui é mais informada — se
divergir da que foi confirmada com o usuário, **não sobrescreva
silenciosamente**: registre a divergência junto das "Ambiguidades
identificadas" acima e deixe o Orquestrador decidir se volta a perguntar.

## Perguntas que você sempre se faz antes de entregar
- Qual é o critério de "feito"? Como o usuário vai saber que funcionou?
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash tests/tier-flows-first.test.sh`
Expected: PASS em todos os `check`.

- [ ] **Step 6: Rodar os testes de regressão que também tocam esses dois arquivos**

Run: `bash tests/subagentes-modelo.test.sh && bash tests/gemini-orquestrador-paridade.test.sh && bash tests/gemini-skills.test.sh`
Expected: PASS nos três (nenhum deles checa o texto que você adicionou, mas todos checam texto que já existia em `ANALISTA.md`/`analista/SKILL.md` e não deve ter sido removido).

- [ ] **Step 7: Commit**

```bash
git add agentes/ANALISTA.md gemini/skills/analista/SKILL.md tests/tier-flows-first.test.sh
git commit -m "$(cat <<'EOF'
feat: Analista declara tier explícito da demanda (spike/feature/critical)

Eixo independente da estimativa de complexidade — mede quanto
rigor/processo a demanda merece, não quão difícil é. Paridade Claude
e Gemini/Antigravity.
EOF
)"
```

---

### Task 2: Flows-first no BDD + regra de bug fora do escopo

**Files:**
- Modify: `agentes/BDD.md`
- Modify: `gemini/skills/bdd/SKILL.md`
- Modify: `tests/tier-flows-first.test.sh`

**Interfaces:**
- Consumes: conceito de tier (Task 1) — a nota de tier `spike` cita "definido pelo Analista" (Gemini) / `.agents/PIPELINE.md` (Claude, Task 6 vai criar essa seção; a referência textual já é válida antes disso, é só um pointer de documentação).

- [ ] **Step 1: Estender o teste (vai falhar) — acrescente ao final de `tests/tier-flows-first.test.sh`, antes de `exit $fail`**

```bash
# --- Task 2: Flows-first no BDD ---
check "$ROOT/agentes/BDD.md" 'alinhamento de fluxos' "BDD.md tem seção de flows-first"
check "$ROOT/agentes/BDD.md" '1 fluxo = 1 caso ponta-a-ponta' "BDD.md tem regra de granularidade"
check "$ROOT/agentes/BDD.md" 'Bug fora do escopo' "BDD.md tem regra de bug fora do escopo"
check "$ROOT/gemini/skills/bdd/SKILL.md" 'alinhamento de fluxos' "bdd/SKILL.md (Gemini) tem seção de flows-first"
check "$ROOT/gemini/skills/bdd/SKILL.md" 'Bug fora do escopo' "bdd/SKILL.md (Gemini) tem regra de bug fora do escopo"
```

- [ ] **Step 2: Rodar o teste e confirmar que as 5 linhas novas falham**

Run: `bash tests/tier-flows-first.test.sh`
Expected: FAIL nas 5 checagens novas (as 8 do Task 1 continuam passando).

- [ ] **Step 3: Editar `agentes/BDD.md`**

Primeira edição — seção de flows-first, entre "Missão" e "Como você fala":

Old:
```
5. **Priorizar** cenários por criticidade: P0 (blocker) → P1 (importante) → P2 (nice-to-have)

## Como você fala
```

New:
```
5. **Priorizar** cenários por criticidade: P0 (blocker) → P1 (importante) → P2 (nice-to-have)

## Antes do Gherkin: alinhamento de fluxos (flows-first)

Antes de qualquer cenário Gherkin, alinhe os fluxos com o Bruno **um por
vez**, na ordem sucesso → alternativos → erro. Para cada fluxo, apresente:

- **Nome:** "X faz Y"
- **Ator:** quem inicia
- **Pré-condição:** estado do sistema antes
- **Passos:** sequência observável
- **Resultado esperado:** pós-estado + resposta visível
- **Efeitos colaterais:** banco, filas, e-mails, logs, chamadas externas

Espere aprovação do Bruno a cada fluxo antes de propor o próximo — não
avance sem aprovação explícita. Só depois de todos os fluxos relevantes
aprovados, converta cada um pro Gherkin (ver "Estrutura de output" abaixo).

**Regra de granularidade:** 1 fluxo = 1 caso ponta-a-ponta do usuário, não 1
endpoint/função (ex.: "usuário completa cadastro" — cadastro → confirmação →
login —, não "POST /signup" isolado, que não exercita a cadeia inteira).

Em tier `spike` (ver `.agents/PIPELINE.md`, "Tier da demanda"), aplique esta
fase de forma leve — só o fluxo feliz, sem alternativos/erro.

## Como você fala
```

Segunda edição — regra de bug fora do escopo, antes do rodapé final:

Old:
```
## Perguntas-chave que você faz
- Quem é o usuário neste fluxo? (há diferentes perfis com comportamentos distintos?)
- O que exatamente significa "sucesso" neste caso?
- O que acontece com dados já existentes?
- Há limites? (ex: máximo de X itens, timeout de Y segundos)

---
*Ativado como etapa 4 do pipeline (opcional). Output é usado pelo QA para implementar os testes.*

Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.
```

New:
```
## Perguntas-chave que você faz
- Quem é o usuário neste fluxo? (há diferentes perfis com comportamentos distintos?)
- O que exatamente significa "sucesso" neste caso?
- O que acontece com dados já existentes?
- Há limites? (ex: máximo de X itens, timeout de Y segundos)

## Bug fora do escopo encontrado no meio do trabalho

Se encontrar um bug, inconsistência ou requisito quebrado que **não é o
alvo da tarefa atual**:
1. **Para** o que estava fazendo na parte afetada
2. **Reporta** o achado claramente ao Orquestrador
3. **Apresenta 2-3 opções**: corrigir agora (dentro desta tarefa) / abrir
   tarefa separada / pular
4. **Espera** a decisão do Bruno
5. **Nunca corrige silenciosamente**

---
*Ativado como etapa 4 do pipeline (opcional). Output é usado pelo QA para implementar os testes.*

Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.
```

- [ ] **Step 4: Editar `gemini/skills/bdd/SKILL.md`**

Primeira edição — seção de flows-first (usuário em vez de Bruno; sem citar `.agents/PIPELINE.md`, já que o lado Gemini não usa esse padrão de rodapé — cita "definido pelo Analista" em vez disso):

Old:
```
5. **Priorizar** cenários por criticidade: P0 (blocker) → P1 (importante) → P2 (nice-to-have)

## Como você fala
```

New:
```
5. **Priorizar** cenários por criticidade: P0 (blocker) → P1 (importante) → P2 (nice-to-have)

## Antes do Gherkin: alinhamento de fluxos (flows-first)

Antes de qualquer cenário Gherkin, alinhe os fluxos com o usuário **um por
vez**, na ordem sucesso → alternativos → erro. Para cada fluxo, apresente:

- **Nome:** "X faz Y"
- **Ator:** quem inicia
- **Pré-condição:** estado do sistema antes
- **Passos:** sequência observável
- **Resultado esperado:** pós-estado + resposta visível
- **Efeitos colaterais:** banco, filas, e-mails, logs, chamadas externas

Espere aprovação do usuário a cada fluxo antes de propor o próximo — não
avance sem aprovação explícita. Só depois de todos os fluxos relevantes
aprovados, converta cada um pro Gherkin (ver "Estrutura de output" abaixo).

**Regra de granularidade:** 1 fluxo = 1 caso ponta-a-ponta do usuário, não 1
endpoint/função (ex.: "usuário completa cadastro" — cadastro → confirmação →
login —, não "POST /signup" isolado, que não exercita a cadeia inteira).

Em tier `spike` (definido pelo Analista), aplique esta fase de forma leve —
só o fluxo feliz, sem alternativos/erro.

## Como você fala
```

Segunda edição — regra de bug fora do escopo, antes do rodapé final:

Old:
```
## Perguntas-chave que você faz
- Quem é o usuário neste fluxo?
- O que exatamente significa "sucesso" neste caso?
- O que acontece com dados já existentes?
- Há limites? (ex: máximo de X itens, timeout de Y segundos)

---
*Etapa 4 do pipeline (opcional). Output usado pelo QA para implementar os testes.*
```

New:
```
## Perguntas-chave que você faz
- Quem é o usuário neste fluxo?
- O que exatamente significa "sucesso" neste caso?
- O que acontece com dados já existentes?
- Há limites? (ex: máximo de X itens, timeout de Y segundos)

## Bug fora do escopo encontrado no meio do trabalho

Se encontrar um bug, inconsistência ou requisito quebrado que **não é o
alvo da tarefa atual**:
1. **Para** o que estava fazendo na parte afetada
2. **Reporta** o achado claramente ao Orquestrador
3. **Apresenta 2-3 opções**: corrigir agora (dentro desta tarefa) / abrir
   tarefa separada / pular
4. **Espera** a decisão do usuário
5. **Nunca corrige silenciosamente**

---
*Etapa 4 do pipeline (opcional). Output usado pelo QA para implementar os testes.*
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash tests/tier-flows-first.test.sh`
Expected: PASS em todas as 13 checagens (8 do Task 1 + 5 do Task 2).

- [ ] **Step 6: Rodar testes de regressão**

Run: `bash tests/gemini-orquestrador-paridade.test.sh && bash tests/gemini-skills.test.sh`
Expected: PASS nos dois.

- [ ] **Step 7: Commit**

```bash
git add agentes/BDD.md gemini/skills/bdd/SKILL.md tests/tier-flows-first.test.sh
git commit -m "$(cat <<'EOF'
feat: BDD alinha fluxos um a um (flows-first) antes de gerar Gherkin

Propõe cada fluxo (sucesso → alternativos → erro) separadamente, com
aprovação antes do próximo, seguindo a regra de granularidade "1
fluxo = 1 caso ponta-a-ponta". Também ganha a regra de "bug fora do
escopo": para, reporta, apresenta opções, nunca corrige
silenciosamente. Paridade Claude e Gemini/Antigravity.
EOF
)"
```

---

### Task 3: Sucesso antes de erro + bug fora do escopo no Dev

**Files:**
- Modify: `agentes/DEV.md`
- Modify: `gemini/skills/dev/SKILL.md`
- Modify: `tests/tier-flows-first.test.sh`

**Interfaces:**
- Consumes: nenhuma nova (a ordem sucesso/erro só se aplica quando há cenários BDD do Task 2 disponíveis; sem BDD ativo, o Dev segue como sempre).

- [ ] **Step 1: Estender o teste (vai falhar)**

Acrescente ao final de `tests/tier-flows-first.test.sh`, antes de `exit $fail`:

```bash
# --- Task 3: Sucesso antes de erro + bug fora do escopo no Dev ---
check "$ROOT/agentes/DEV.md" 'Sucesso antes de erro' "DEV.md tem regra de ordem sucesso-antes-erro"
check "$ROOT/agentes/DEV.md" 'Bug fora do escopo' "DEV.md tem regra de bug fora do escopo"
check "$ROOT/gemini/skills/dev/SKILL.md" 'Sucesso antes de erro' "dev/SKILL.md (Gemini) tem regra de ordem sucesso-antes-erro"
check "$ROOT/gemini/skills/dev/SKILL.md" 'Bug fora do escopo' "dev/SKILL.md (Gemini) tem regra de bug fora do escopo"
```

- [ ] **Step 2: Rodar o teste e confirmar que as 4 linhas novas falham**

Run: `bash tests/tier-flows-first.test.sh`
Expected: FAIL nas 4 checagens novas (as 13 anteriores continuam passando).

- [ ] **Step 3: Editar `agentes/DEV.md`**

Primeira edição — regra de ordem, na lista "Padrões que você segue":

Old:
```
- **Compatível com o que o TL planejou**: não inventa nova camada sem autorização
- **Nomenclatura e comentários sempre em inglês**: variáveis, funções, classes, arquivos, pastas, comentários e schema de banco (tabelas/colunas) — nunca em português, mesmo com o Bruno pedindo em português (a comunicação com ele continua em português normalmente). Isso tem prioridade sobre "seguir convenções do projeto" quando o projeto legado tem nomenclatura em português: não migra o código existente em massa por conta própria, só sinaliza a inconsistência. Exceção: strings visíveis ao usuário final (UI, mensagens de erro exibidas) seguem o idioma do produto, não esta regra.
```

New:
```
- **Compatível com o que o TL planejou**: não inventa nova camada sem autorização
- **Sucesso antes de erro**: quando há cenários BDD disponíveis (fluxos de sucesso e de erro), implementa os de sucesso primeiro, por completo, antes de começar os de erro — não mistura as duas levas
- **Nomenclatura e comentários sempre em inglês**: variáveis, funções, classes, arquivos, pastas, comentários e schema de banco (tabelas/colunas) — nunca em português, mesmo com o Bruno pedindo em português (a comunicação com ele continua em português normalmente). Isso tem prioridade sobre "seguir convenções do projeto" quando o projeto legado tem nomenclatura em português: não migra o código existente em massa por conta própria, só sinaliza a inconsistência. Exceção: strings visíveis ao usuário final (UI, mensagens de erro exibidas) seguem o idioma do produto, não esta regra.
```

Segunda edição — regra de bug fora do escopo, depois de "Quando o plano está errado":

Old:
```
## Quando o plano está errado
Se o plano técnico do TL for inviável ou contraditório:
1. Para imediatamente
2. Documenta o problema encontrado
3. Reporta ao Orquestrador com proposta de solução
4. Aguarda decisão antes de continuar

---
*Ativado como etapa 7 do pipeline. Recebe como input: análise do ANALISTA + plano do TL + cenários do BDD (se houver).*

Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.
```

New:
```
## Quando o plano está errado
Se o plano técnico do TL for inviável ou contraditório:
1. Para imediatamente
2. Documenta o problema encontrado
3. Reporta ao Orquestrador com proposta de solução
4. Aguarda decisão antes de continuar

## Bug fora do escopo encontrado no meio do trabalho

Diferente de "quando o plano está errado" (acima, sobre o **plano do TL**
ser inviável): se encontrar um bug, inconsistência ou código quebrado que
**não é o alvo da tarefa atual** e não tem relação com o plano em si:
1. **Para** a implementação da parte afetada
2. **Reporta** o achado claramente ao Orquestrador
3. **Apresenta 2-3 opções**: corrigir agora (dentro desta tarefa) / abrir
   tarefa separada / pular
4. **Espera** a decisão do Bruno
5. **Nunca corrige silenciosamente**

---
*Ativado como etapa 7 do pipeline. Recebe como input: análise do ANALISTA + plano do TL + cenários do BDD (se houver).*

Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.
```

- [ ] **Step 4: Editar `gemini/skills/dev/SKILL.md`**

Primeira edição — regra de ordem, na lista "Padrões que você segue":

Old:
```
- **Compatível com o que o TL planejou**: não inventa nova camada sem autorização
- **Nomenclatura e comentários sempre em inglês**: variáveis, funções, classes, arquivos, pastas, comentários e schema de banco (tabelas/colunas) — nunca em português, mesmo com o usuário pedindo em português (a comunicação com ele continua em português normalmente). Isso tem prioridade sobre "seguir convenções do projeto" quando o projeto legado tem nomenclatura em português: não migra o código existente em massa por conta própria, só sinaliza a inconsistência. Exceção: strings visíveis ao usuário final (UI, mensagens de erro exibidas) seguem o idioma do produto, não esta regra.
```

New:
```
- **Compatível com o que o TL planejou**: não inventa nova camada sem autorização
- **Sucesso antes de erro**: quando há cenários BDD disponíveis (fluxos de sucesso e de erro), implementa os de sucesso primeiro, por completo, antes de começar os de erro — não mistura as duas levas
- **Nomenclatura e comentários sempre em inglês**: variáveis, funções, classes, arquivos, pastas, comentários e schema de banco (tabelas/colunas) — nunca em português, mesmo com o usuário pedindo em português (a comunicação com ele continua em português normalmente). Isso tem prioridade sobre "seguir convenções do projeto" quando o projeto legado tem nomenclatura em português: não migra o código existente em massa por conta própria, só sinaliza a inconsistência. Exceção: strings visíveis ao usuário final (UI, mensagens de erro exibidas) seguem o idioma do produto, não esta regra.
```

Segunda edição — regra de bug fora do escopo, depois de "Quando o plano está errado":

Old:
```
## Quando o plano está errado
Se o plano técnico do TL for inviável ou contraditório:
1. Para imediatamente
2. Documenta o problema encontrado
3. Reporta ao Orquestrador com proposta de solução
4. Aguarda decisão antes de continuar

---
*Etapa 7 do pipeline. Recebe: análise do ANALISTA + plano do TL + cenários do BDD (se houver).*
```

New:
```
## Quando o plano está errado
Se o plano técnico do TL for inviável ou contraditório:
1. Para imediatamente
2. Documenta o problema encontrado
3. Reporta ao Orquestrador com proposta de solução
4. Aguarda decisão antes de continuar

## Bug fora do escopo encontrado no meio do trabalho

Diferente de "quando o plano está errado" (acima, sobre o **plano do TL**
ser inviável): se encontrar um bug, inconsistência ou código quebrado que
**não é o alvo da tarefa atual** e não tem relação com o plano em si:
1. **Para** a implementação da parte afetada
2. **Reporta** o achado claramente ao Orquestrador
3. **Apresenta 2-3 opções**: corrigir agora (dentro desta tarefa) / abrir
   tarefa separada / pular
4. **Espera** a decisão do usuário
5. **Nunca corrige silenciosamente**

---
*Etapa 7 do pipeline. Recebe: análise do ANALISTA + plano do TL + cenários do BDD (se houver).*
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash tests/tier-flows-first.test.sh`
Expected: PASS em todas as 17 checagens.

- [ ] **Step 6: Rodar testes de regressão**

Run: `bash tests/gemini-orquestrador-paridade.test.sh && bash tests/gemini-skills.test.sh`
Expected: PASS nos dois.

- [ ] **Step 7: Commit**

```bash
git add agentes/DEV.md gemini/skills/dev/SKILL.md tests/tier-flows-first.test.sh
git commit -m "$(cat <<'EOF'
feat: Dev implementa sucesso antes de erro + regra de bug fora do escopo

Quando há cenários BDD disponíveis, implementa os de sucesso por
completo antes de começar os de erro. Ganha também a regra de "bug
fora do escopo" (distinta de "quando o plano está errado", que é
sobre o plano do TL). Paridade Claude e Gemini/Antigravity.
EOF
)"
```

---

### Task 4: Sucesso antes de erro + bug fora do escopo no QA

**Files:**
- Modify: `agentes/QA.md`
- Modify: `gemini/skills/qa/SKILL.md`
- Modify: `tests/tier-flows-first.test.sh`

**Interfaces:**
- Consumes: nenhuma nova (mesma lógica do Task 3, aplicada à ordem de teste em vez de implementação).

- [ ] **Step 1: Estender o teste (vai falhar)**

Acrescente ao final de `tests/tier-flows-first.test.sh`, antes de `exit $fail`:

```bash
# --- Task 4: Sucesso antes de erro + bug fora do escopo no QA ---
check "$ROOT/agentes/QA.md" 'Sucesso antes de erro' "QA.md tem regra de ordem sucesso-antes-erro"
check "$ROOT/agentes/QA.md" 'Bug fora do escopo' "QA.md tem regra de bug fora do escopo"
check "$ROOT/gemini/skills/qa/SKILL.md" 'Sucesso antes de erro' "qa/SKILL.md (Gemini) tem regra de ordem sucesso-antes-erro"
check "$ROOT/gemini/skills/qa/SKILL.md" 'Bug fora do escopo' "qa/SKILL.md (Gemini) tem regra de bug fora do escopo"
```

- [ ] **Step 2: Rodar o teste e confirmar que as 4 linhas novas falham**

Run: `bash tests/tier-flows-first.test.sh`
Expected: FAIL nas 4 checagens novas (as 17 anteriores continuam passando).

- [ ] **Step 3: Editar `agentes/QA.md`**

Primeira edição — regra de ordem, na lista "Estratégia de testes que você segue" (acrescenta item 6, depois do item 5 existente):

Old:
```
5. **Nomes de teste sempre em inglês**: `describe`/`it`/`test`, nomes de fixtures e mocks — mesmo que o relatório para o Bruno seja em português. Exceção: nomes de cenário BDD copiados de um `.feature` que a etapa BDD tenha escrito em português permanecem como estão (não é o QA quem decide o idioma do BDD).

## Quando você reprova
```

New:
```
5. **Nomes de teste sempre em inglês**: `describe`/`it`/`test`, nomes de fixtures e mocks — mesmo que o relatório para o Bruno seja em português. Exceção: nomes de cenário BDD copiados de um `.feature` que a etapa BDD tenha escrito em português permanecem como estão (não é o QA quem decide o idioma do BDD).
6. **Sucesso antes de erro**: quando há cenários BDD disponíveis, testa (escreve e roda) os de sucesso primeiro, por completo, antes de começar os de erro — mesma ordem que o Dev já segue na implementação

## Quando você reprova
```

Segunda edição — regra de bug fora do escopo, antes do rodapé final (nota: distinta da tabela "Bugs encontrados" já existente, que é sobre bugs **dentro** do escopo da feature testada):

Old:
```
QA aprova com ressalvas (⚠️) quando:
- Bugs menores que não bloqueiam o uso principal
- Cobertura parcial com justificativa

---
*Ativado como etapa 8 do pipeline (opcional). Se reprovado, Orquestrador volta para o DEV com o relatório como contexto.*

Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.
```

New:
```
QA aprova com ressalvas (⚠️) quando:
- Bugs menores que não bloqueiam o uso principal
- Cobertura parcial com justificativa

## Bug fora do escopo encontrado no meio do trabalho

Diferente da tabela "Bugs encontrados" acima (que é sobre bugs **dentro**
do escopo da feature que você está testando): se encontrar um bug,
inconsistência ou código quebrado que **não é o alvo da tarefa atual** —
algo não relacionado que você notou enquanto testava outra coisa:
1. **Para** a investigação da parte afetada
2. **Reporta** o achado claramente ao Orquestrador
3. **Apresenta 2-3 opções**: corrigir agora (dentro desta tarefa) / abrir
   tarefa separada / pular
4. **Espera** a decisão do Bruno
5. **Nunca corrige silenciosamente**

---
*Ativado como etapa 8 do pipeline (opcional). Se reprovado, Orquestrador volta para o DEV com o relatório como contexto.*

Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`.
```

- [ ] **Step 4: Editar `gemini/skills/qa/SKILL.md`**

Primeira edição — regra de ordem, na lista "Estratégia de testes que você segue":

Old:
```
5. **Nomes de teste sempre em inglês**: `describe`/`it`/`test`, nomes de fixtures e mocks — mesmo que o relatório para o usuário seja em português. Exceção: nomes de cenário BDD copiados de um `.feature` que a etapa BDD tenha escrito em português permanecem como estão.

## Quando você reprova
```

New:
```
5. **Nomes de teste sempre em inglês**: `describe`/`it`/`test`, nomes de fixtures e mocks — mesmo que o relatório para o usuário seja em português. Exceção: nomes de cenário BDD copiados de um `.feature` que a etapa BDD tenha escrito em português permanecem como estão.
6. **Sucesso antes de erro**: quando há cenários BDD disponíveis, testa (escreve e roda) os de sucesso primeiro, por completo, antes de começar os de erro — mesma ordem que o Dev já segue na implementação

## Quando você reprova
```

Segunda edição — regra de bug fora do escopo, antes do rodapé final:

Old:
```
## Quando você reprova
- ❌ Há bug crítico que quebra o fluxo principal
- ❌ Cobertura de funções críticas abaixo de 80%
- ❌ Cenário BDD P0 falhou

---
*Etapa 8 do pipeline (opcional). Se reprovado, Orquestrador volta para o DEV com o relatório como contexto.*
```

New:
```
## Quando você reprova
- ❌ Há bug crítico que quebra o fluxo principal
- ❌ Cobertura de funções críticas abaixo de 80%
- ❌ Cenário BDD P0 falhou

## Bug fora do escopo encontrado no meio do trabalho

Diferente dos bugs listados acima (que são **dentro** do escopo da feature
que você está testando): se encontrar um bug, inconsistência ou código
quebrado que **não é o alvo da tarefa atual** — algo não relacionado que
você notou enquanto testava outra coisa:
1. **Para** a investigação da parte afetada
2. **Reporta** o achado claramente ao Orquestrador
3. **Apresenta 2-3 opções**: corrigir agora (dentro desta tarefa) / abrir
   tarefa separada / pular
4. **Espera** a decisão do usuário
5. **Nunca corrige silenciosamente**

---
*Etapa 8 do pipeline (opcional). Se reprovado, Orquestrador volta para o DEV com o relatório como contexto.*
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash tests/tier-flows-first.test.sh`
Expected: PASS em todas as 21 checagens.

- [ ] **Step 6: Rodar testes de regressão**

Run: `bash tests/gemini-orquestrador-paridade.test.sh && bash tests/gemini-skills.test.sh`
Expected: PASS nos dois.

- [ ] **Step 7: Commit**

```bash
git add agentes/QA.md gemini/skills/qa/SKILL.md tests/tier-flows-first.test.sh
git commit -m "$(cat <<'EOF'
feat: QA testa sucesso antes de erro + regra de bug fora do escopo

Mesma ordem que o Dev já segue na implementação. Ganha também a
regra de "bug fora do escopo" (distinta da tabela "Bugs encontrados",
que é sobre a feature testada). Paridade Claude e Gemini/Antigravity.
EOF
)"
```

---

### Task 5: Menu do Orquestrador exibe o tier sugerido

**Files:**
- Modify: `agentes/ORQUESTRADOR.md`
- Modify: `gemini/skills/orquestrador/SKILL.md`
- Modify: `tests/tier-flows-first.test.sh`

**Interfaces:**
- Consumes: conceito de tier (Task 1).
- Produces: o campo "Tier" no cabeçalho de `.agents/PIPELINE-STATE.md`, que `agentes/PIPELINE.md` (Task 6) documenta no template completo.

- [ ] **Step 1: Estender o teste (vai falhar)**

Acrescente ao final de `tests/tier-flows-first.test.sh`, antes de `exit $fail`:

```bash
# --- Task 5: Menu do Orquestrador exibe o tier ---
check "$ROOT/agentes/ORQUESTRADOR.md" 'Tier sugerido' "ORQUESTRADOR.md mostra tier sugerido no menu"
check "$ROOT/agentes/ORQUESTRADOR.md" 'tier confirmado' "ORQUESTRADOR.md registra tier confirmado no cabeçalho do PIPELINE-STATE"
check "$ROOT/gemini/skills/orquestrador/SKILL.md" 'Tier sugerido' "orquestrador/SKILL.md (Gemini) mostra tier sugerido no menu"
```

- [ ] **Step 2: Rodar o teste e confirmar que as 3 linhas novas falham**

Run: `bash tests/tier-flows-first.test.sh`
Expected: FAIL nas 3 checagens novas (as 21 anteriores continuam passando).

- [ ] **Step 3: Editar `agentes/ORQUESTRADOR.md`**

Primeira edição — leitura rápida de tier antes do menu, e linha de Tier dentro do template do menu:

Old:
```
Se `.agents/TEAM.md` existir, use-o para pré-marcar o menu abaixo (em vez do
padrão fixo) antes de apresentá-lo ao Bruno.

**Menu padrão a apresentar:**

```
[ORQUESTRADOR] Recebi sua solicitação: "{resumo curto}"

Antes de começar, configure o pipeline desta sessão.
Marque com ✅ as etapas que deseja ativar:
```

New:
```
Se `.agents/TEAM.md` existir, use-o para pré-marcar o menu abaixo (em vez do
padrão fixo) antes de apresentá-lo ao Bruno.

Antes de montar o menu, faça uma leitura rápida de **tier** a partir da
solicitação bruta (critério completo em `.agents/PIPELINE.md`, "Tier da
demanda": `spike` = descartável/só fluxo feliz; `feature` = produção normal;
`critical` = pagamento/auth/dados sensíveis/irreversível). Essa é uma
primeira leitura, mais rasa que a do Analista (que ainda não rodou) — mostre
junto do menu e deixe o Bruno confirmar ou ajustar os dois ao mesmo tempo.

**Menu padrão a apresentar:**

```
[ORQUESTRADOR] Recebi sua solicitação: "{resumo curto}"

Tier sugerido: {spike/feature/critical} — {justificativa em 1 linha}
(veja "Tier da demanda" em .agents/PIPELINE.md; discorde se achar que não é esse)

Antes de começar, configure o pipeline desta sessão.
Marque com ✅ as etapas que deseja ativar:
```

Segunda edição — registrar o tier confirmado no cabeçalho do `PIPELINE-STATE.md`:

Old:
```
4. Assim que o menu for confirmado, cria `.agents/PIPELINE-STATE.md` com o
   cabeçalho (resumo da tarefa, data, perfil ativo) e a seção "Planejamento"
   vazia — as etapas vão sendo marcadas conforme completam (ver "Estado do
   pipeline" abaixo)
```

New:
```
4. Assim que o menu for confirmado, cria `.agents/PIPELINE-STATE.md` com o
   cabeçalho (resumo da tarefa, data, perfil ativo, tier confirmado) e a
   seção "Planejamento" vazia — as etapas vão sendo marcadas conforme
   completam (ver "Estado do pipeline" abaixo)
```

- [ ] **Step 4: Editar `gemini/skills/orquestrador/SKILL.md`**

Leitura rápida de tier antes do menu, e linha de Tier no template do menu (este arquivo não gerencia `PIPELINE-STATE.md`, então não há segunda edição equivalente):

Old:
```
Se `.agents/CONTEXTO.md` existir, leia e use como pano de fundo (nunca leia o `CONTEXTO.md` de outro projeto). Se `.agents/TEAM.md` existir, use como pré-seleção padrão do menu de etapas abaixo, em vez do padrão fixo.

**Menu padrão a apresentar:**

```
[ORQUESTRADOR] Recebi sua solicitação: "{resumo curto}"

Antes de começar, configure o pipeline desta sessão.
Marque com ✅ as etapas que deseja ativar:
```

New:
```
Se `.agents/CONTEXTO.md` existir, leia e use como pano de fundo (nunca leia o `CONTEXTO.md` de outro projeto). Se `.agents/TEAM.md` existir, use como pré-seleção padrão do menu de etapas abaixo, em vez do padrão fixo.

Antes de montar o menu, faça uma leitura rápida de **tier** a partir da
solicitação bruta (critério completo em `.agents/PIPELINE.md`, "Tier da
demanda": `spike` = descartável/só fluxo feliz; `feature` = produção normal;
`critical` = pagamento/auth/dados sensíveis/irreversível). É uma primeira
leitura, mais rasa que a do Analista (que ainda não rodou) — mostre junto do
menu e deixe o usuário confirmar ou ajustar os dois ao mesmo tempo.

**Menu padrão a apresentar:**

```
[ORQUESTRADOR] Recebi sua solicitação: "{resumo curto}"

Tier sugerido: {spike/feature/critical} — {justificativa em 1 linha}
(veja "Tier da demanda" em .agents/PIPELINE.md; discorde se achar que não é esse)

Antes de começar, configure o pipeline desta sessão.
Marque com ✅ as etapas que deseja ativar:
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash tests/tier-flows-first.test.sh`
Expected: PASS em todas as 24 checagens.

- [ ] **Step 6: Rodar testes de regressão**

Run: `bash tests/team-md.test.sh && bash tests/gemini-orquestrador-paridade.test.sh && bash tests/subagentes-modelo.test.sh`
Expected: PASS nos três (todos leem `ORQUESTRADOR.md`/`orquestrador/SKILL.md` e checam texto que suas edições não devem ter removido).

- [ ] **Step 7: Commit**

```bash
git add agentes/ORQUESTRADOR.md gemini/skills/orquestrador/SKILL.md tests/tier-flows-first.test.sh
git commit -m "$(cat <<'EOF'
feat: Orquestrador sugere tier no menu, confirmado junto do perfil

Leitura rápida da solicitação bruta, antes de qualquer etapa rodar
(inclusive o Analista) — mostrada junto do menu de perfis rápidos. O
tier confirmado entra no cabeçalho do PIPELINE-STATE.md. Paridade
Claude e Gemini/Antigravity.
EOF
)"
```

---

### Task 6: `PIPELINE.md` documenta o tier canonicamente

**Files:**
- Modify: `agentes/PIPELINE.md`
- Modify: `tests/tier-flows-first.test.sh`

**Interfaces:**
- Produces: a seção "## Tier da demanda" que `agentes/ORQUESTRADOR.md`/`gemini/skills/orquestrador/SKILL.md` (Task 5) e `agentes/ANALISTA.md` (Task 1) já citam por nome.

- [ ] **Step 1: Estender o teste (vai falhar)**

Acrescente ao final de `tests/tier-flows-first.test.sh`, antes de `exit $fail`:

```bash
# --- Task 6: PIPELINE.md documenta o tier ---
check "$ROOT/agentes/PIPELINE.md" '## Tier da demanda' "PIPELINE.md documenta tier canonicamente"
check "$ROOT/agentes/PIPELINE.md" 'não força automaticamente um perfil' "PIPELINE.md documenta relação tier x perfil"
check "$ROOT/agentes/PIPELINE.md" 'está repetida de forma autocontida em `BDD.md`, `DEV.md` e' "PIPELINE.md cita onde a regra de bug fora do escopo está repetida"
check "$ROOT/agentes/PIPELINE.md" 'Tier: <tier>' "PIPELINE.md template de PIPELINE-STATE.md inclui linha Tier"
```

- [ ] **Step 2: Rodar o teste e confirmar que as 4 linhas novas falham**

Run: `bash tests/tier-flows-first.test.sh`
Expected: FAIL nas 4 checagens novas (as 24 anteriores continuam passando).

- [ ] **Step 3: Editar `agentes/PIPELINE.md`**

Primeira edição — seção "Tier da demanda", entre "Perfis rápidos de pipeline" e "Template de TEAM.md":

Old:
```
| 🐛 Bug simples | 1 → 7 → 9 |
| 🔍 Bug complexo | 1 → 6 → 7 → 8 → 9 |
| 🔐 Bug de segurança | 1 → 6 → 7 → 8 → 9 → 10 |

## Template de TEAM.md
```

New:
```
| 🐛 Bug simples | 1 → 7 → 9 |
| 🔍 Bug complexo | 1 → 6 → 7 → 8 → 9 |
| 🔐 Bug de segurança | 1 → 6 → 7 → 8 → 9 → 10 |

## Tier da demanda

Eixo independente do perfil — perfil escolhe **quais etapas rodam**, tier
escolhe **quanto rigor/processo** a demanda merece dentro das etapas que
rodam. O Orquestrador sugere um tier no menu (leitura rápida da solicitação
bruta) e o Analista confirma/refina depois de rodar (etapa 1, sempre
ativa) — ver `.agents/ANALISTA.md`, "Tier da demanda".

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
```

Segunda edição — linha "Tier" no template de `PIPELINE-STATE.md`:

Old:
```
### Formato de `.agents/PIPELINE-STATE.md`

```markdown
# Estado do Pipeline — <resumo curto da tarefa original>

Iniciado em: <data>
Perfil ativo: <perfil> (<lista de etapas ativas>)

## Planejamento
```

New:
```
### Formato de `.agents/PIPELINE-STATE.md`

```markdown
# Estado do Pipeline — <resumo curto da tarefa original>

Iniciado em: <data>
Perfil ativo: <perfil> (<lista de etapas ativas>)
Tier: <tier>

## Planejamento
```

Terceira edição — nota sobre onde a regra de bug-fora-do-escopo está repetida, depois da nota equivalente da convenção de idioma:

Old:
```
Esta regra está repetida de forma autocontida em cada persona que produz ou
revisa código (`ARQUITETO.md`, `TL.md`, `DEV.md`, `QA.md`, `REVISOR.md`) porque
cada subagente recebe apenas o conteúdo do próprio arquivo de persona, não este
documento — ver "Como disparar cada etapa" em `ORQUESTRADOR.md`.

Além disso, `/init-project` instala a skill `coding-standards`
```

New:
```
Esta regra está repetida de forma autocontida em cada persona que produz ou
revisa código (`ARQUITETO.md`, `TL.md`, `DEV.md`, `QA.md`, `REVISOR.md`) porque
cada subagente recebe apenas o conteúdo do próprio arquivo de persona, não este
documento — ver "Como disparar cada etapa" em `ORQUESTRADOR.md`.

Pelo mesmo motivo, a regra de **"bug fora do escopo encontrado no meio do
trabalho"** (para, reporta, apresenta opções, espera decisão, nunca corrige
silenciosamente) está repetida de forma autocontida em `BDD.md`, `DEV.md` e
`QA.md` — as três personas mais prováveis de topar com algo assim.

Além disso, `/init-project` instala a skill `coding-standards`
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash tests/tier-flows-first.test.sh`
Expected: PASS em todas as 28 checagens.

- [ ] **Step 5: Rodar testes de regressão**

Run: `bash tests/team-md.test.sh && bash tests/contexto-md.test.sh && bash tests/pipeline-state.test.sh`
Expected: PASS em `team-md.test.sh` e `contexto-md.test.sh`. `pipeline-state.test.sh` **já falhava antes deste plano inteiro** (bug de paridade Gemini/Claude não relacionado, documentado desde a branch anterior) — confirme que a contagem/conteúdo das falhas é exatamente a mesma de antes desta task, não uma falha nova.

- [ ] **Step 6: Rodar a suíte ampla inteira**

Run:
```bash
for f in tests/*.test.sh commands/commands.test.sh scripts/*.test.sh; do
  bash "$f" >/dev/null 2>&1 && echo "PASS: $f" || echo "FAIL: $f"
done
```
Expected: só `tests/pipeline-state.test.sh` falha (pré-existente, confirmado no Step 5).

- [ ] **Step 7: Commit**

```bash
git add agentes/PIPELINE.md tests/tier-flows-first.test.sh
git commit -m "$(cat <<'EOF'
docs: PIPELINE.md documenta tier canonicamente e sua relação com perfil

Tier e perfil são eixos independentes (perfil = quais etapas rodam,
tier = quanto rigor). Também documenta onde a regra de "bug fora do
escopo" está repetida, mesmo padrão já usado pra convenção de idioma
do código.
EOF
)"
```
