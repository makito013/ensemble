# Fases de Execução + Estado Persistido do Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir que o Orquestrador divida features grandes em "fases" (cada uma com seu próprio ciclo Dev→QA→Revisor), persista o progresso em `agentes/PIPELINE-STATE.md` a cada etapa/fase concluída, e ofereça um comando (`/orquestrador-status`) + retomada automática via `/orquestrador` — para que o Bruno possa dar `/clear` a qualquer momento sem perder a posição no pipeline.

**Architecture:** Mudança é 100% em arquivos de instrução (Markdown) — nenhum código executável novo. `agentes/PIPELINE.md` documenta o formato/ciclo de vida do estado; `agentes/ORQUESTRADOR.md` ganha a lógica de detectar/gravar/arquivar esse estado; `ARQUITETO.md`/`TL.md` ganham a instrução de dividir em fases; `DEV.md`/`QA.md`/`REVISOR.md` ganham a instrução de escopo por fase; um novo comando `orquestrador-status` (só leitura) expõe o estado. Toda mudança em `agentes/*.md` é espelhada em `gemini/skills/*/SKILL.md` (self-contained, sem cross-reference a `agentes/PIPELINE.md`, que não existe do lado Antigravity).

**Tech Stack:** Markdown puro + testes em Bash (`tests/*.test.sh`, padrão `grep`-based já usado no repo, sem framework de teste).

## Global Constraints

- Todo texto de instrução das personas é em português (convenção do repo já em vigor).
- "Fase" nunca é usada como sinônimo de "Etapa" em nenhum arquivo tocado — etapa = uma das 10 etapas do pipeline; fase = subdivisão só dentro da execução (etapas 7-9).
- Toda mudança em `agentes/{ARQUITETO,TL,DEV,QA,REVISOR,ORQUESTRADOR}.md` tem um espelho equivalente em `gemini/skills/{arquiteto,tl,dev,qa,revisor,orquestrador}/SKILL.md`, com conteúdo adaptado pra ser self-contained (o lado Gemini não tem `agentes/PIPELINE.md`).
- Testes seguem o padrão já existente: `tests/*.test.sh`, bash com `set -euo pipefail`, função `check()` fazendo `grep -q`, `exit $fail` no final. Nenhum framework novo.
- Nenhuma edição pode remover ou alterar as seguintes substrings já cobertas por testes existentes (rodar a suíte completa a cada task confirma isso):
  - `Ver "Subagentes e escolha de modelo" em \`agentes/PIPELINE.md\`.` (linha final de `ARQUITETO.md`, `TL.md`, `DEV.md`, `QA.md`, `REVISOR.md`, `ORQUESTRADOR.md`, entre outros)
  - `Atualização de contexto sugerida` e `pergunta ao Bruno antes de gravar` em `agentes/ORQUESTRADOR.md`
  - `agentes/TEAM.md`, `agentes/CONTEXTO.md`, `Atualização de contexto sugerida`, `antes de gravar`, `subagentes`, `sempre herda o modelo` em `gemini/skills/orquestrador/SKILL.md`
  - `Subagentes e escolha de modelo` / `não funciona ao disparar um` em `agentes/PIPELINE.md`
  - `/orquestrador` em `agentes/ORQUESTRADOR.md`, `AGENTS.md`, `README.md`
- Commits: um por task, mensagem curta descrevendo o que foi adicionado.

---

### Task 1: `agentes/PIPELINE.md` — terminologia Fase/Etapa + formato de `PIPELINE-STATE.md`

**Files:**
- Modify: `agentes/PIPELINE.md`
- Test: `tests/pipeline-state.test.sh` (novo)

**Interfaces:**
- Produces: o texto exato da seção `## Fases de execução e estado do pipeline (PIPELINE-STATE.md)` e o formato de `agentes/PIPELINE-STATE.md` — todas as tasks seguintes (2-7) referenciam este formato e esta seção por nome.

- [ ] **Step 1: Escrever o teste (vai falhar)**

Criar `tests/pipeline-state.test.sh`:

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

# Task 1 — PIPELINE.md: terminologia e formato do estado
check "$ROOT/agentes/PIPELINE.md" 'Fases de execução e estado do pipeline' "PIPELINE.md tem a seção de fases/estado"
check "$ROOT/agentes/PIPELINE.md" 'agentes/PIPELINE-STATE.md' "PIPELINE.md documenta o arquivo de estado"
check "$ROOT/agentes/PIPELINE.md" 'agentes/\.pipeline-history/' "PIPELINE.md documenta o arquivamento"
check "$ROOT/agentes/PIPELINE.md" 'Existe um `PIPELINE-STATE.md` em aberto por vez' "PIPELINE.md documenta single-slot"
check "$ROOT/agentes/PIPELINE.md" 'PIPELINE-STATE.md.corrompido' "PIPELINE.md documenta tratamento de estado malformado"

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `chmod +x tests/pipeline-state.test.sh && bash tests/pipeline-state.test.sh`
Expected: as 5 linhas `FAIL: ... PIPELINE.md não contém ...` (o arquivo ainda não tem a seção).

- [ ] **Step 3: Editar `agentes/PIPELINE.md`**

Usar Edit com:

old_string:
```
## Como usar

**Inicie sempre pelo Orquestrador (Claude Code):**
```

new_string:
````
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
todas as fases — audita a feature inteira, não fase a fase.

### Formato de `agentes/PIPELINE-STATE.md`

```markdown
# Estado do Pipeline — <resumo curto da tarefa original>

Iniciado em: <data>
Perfil ativo: <perfil> (<lista de etapas ativas>)

## Planejamento
- [x] 1. Analista — <resumo condensado, 2-3 linhas>
- [x] 2. PO — <resumo>
- [x] 3. Arquiteto — <resumo, inclui divisão em fases quando houver>
- [x] 6. TL — <resumo, plano por fase>

## Fases
- [x] Fase 1 — <nome> — concluída (Dev → QA → Revisor aprovado)
      Resumo do que foi entregue: <2-4 linhas>
- [ ] Fase 2 — <nome> — EM ANDAMENTO (próxima ação: <ação concreta>)
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
  `agentes/.pipeline-history/<slug-da-tarefa>-<data>.md` — nunca apaga — e o
  slot fica livre pro próximo `/orquestrador`.
- Se `/orquestrador` for chamado com um estado já aberto de uma tarefa
  diferente, avisa e pergunta: continuar o que está aberto, ou arquivar e
  começar do zero? Nunca decide sozinho, nunca sobrescreve silenciosamente.
- Se o arquivo existir malformado ou incompleto, o Orquestrador não trava a
  sessão: avisa, renomeia para `PIPELINE-STATE.md.corrompido-<data>`
  (preserva o bruto) e oferece começar do zero.
- `agentes/PIPELINE-STATE.md` e `agentes/.pipeline-history/` são dado de
  projeto, igual `CONTEXTO.md`/`TEAM.md` — nunca tocados pelo instalador.
- O comando `/orquestrador-status` (só leitura) mostra este arquivo de forma
  resumida a qualquer momento, sem alterar nada.

Ver "Como você inicia uma sessão", "Como disparar cada etapa" e "Estado do
pipeline" em `ORQUESTRADOR.md` para a mecânica de leitura/escrita.

## Como usar

**Inicie sempre pelo Orquestrador (Claude Code):**
````

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `bash tests/pipeline-state.test.sh`
Expected: 5 linhas `PASS`.

- [ ] **Step 5: Rodar a suíte completa (garantir que nada quebrou)**

Run: `for t in tests/*.test.sh docs-cleanup.test.sh; do bash "$t" || echo "FALHOU: $t"; done`
Expected: nenhuma linha `FALHOU`.

- [ ] **Step 6: Commit**

```bash
git add agentes/PIPELINE.md tests/pipeline-state.test.sh
git commit -m "docs: documenta fases de execução e formato do PIPELINE-STATE.md"
```

---

### Task 2: `agentes/ARQUITETO.md` + espelho Gemini — instrução de dividir em fases

**Files:**
- Modify: `agentes/ARQUITETO.md`
- Modify: `gemini/skills/arquiteto/SKILL.md`
- Modify: `tests/pipeline-state.test.sh`

**Interfaces:**
- Consumes: seção "Fases de execução e estado do pipeline" de `agentes/PIPELINE.md` (Task 1).
- Produces: frase-gatilho `Dividir a feature em fases`, usada pela Task 4 (Orquestrador) como referência de que Arquiteto pode originar a divisão.

- [ ] **Step 1: Escrever o teste (vai falhar)**

Editar `tests/pipeline-state.test.sh`, usando Edit com:

old_string:
```
exit $fail
```

new_string:
```
# Task 2 — ARQUITETO.md: instrução de dividir em fases
check "$ROOT/agentes/ARQUITETO.md" 'Dividir a feature em fases' "ARQUITETO.md instrui divisão em fases"
check "$ROOT/gemini/skills/arquiteto/SKILL.md" 'Dividir a feature em fases' "arquiteto/SKILL.md instrui divisão em fases"

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/pipeline-state.test.sh`
Expected: as 2 novas linhas com `FAIL`.

- [ ] **Step 3: Editar `agentes/ARQUITETO.md`**

old_string:
```
6. **Definir nomenclatura em inglês** para módulos, camadas, entidades e contratos — independente do idioma da conversa com o Bruno

## Como você fala
```

new_string:
```
6. **Definir nomenclatura em inglês** para módulos, camadas, entidades e contratos — independente do idioma da conversa com o Bruno
7. **Dividir a feature em fases** quando for grande/complexa demais pra um ciclo único de Dev→QA→Revisor — cada fase nomeada com objetivo próprio (ex: "Fase 1 — Backend do carrinho", "Fase 2 — Integração com pagamento"). Ver `agentes/PIPELINE.md` (seção "Fases de execução e estado do pipeline")

## Como você fala
```

- [ ] **Step 4: Editar `gemini/skills/arquiteto/SKILL.md`**

old_string:
```
7. **Definir nomenclatura em inglês** para módulos, camadas, entidades e contratos — independente do idioma da conversa com o usuário

## Como você fala
```

new_string:
```
7. **Definir nomenclatura em inglês** para módulos, camadas, entidades e contratos — independente do idioma da conversa com o usuário
8. **Dividir a feature em fases** quando for grande/complexa demais pra um ciclo único de Dev→QA→Revisor — cada fase nomeada com objetivo próprio (ex: "Fase 1 — Backend do carrinho", "Fase 2 — Integração com pagamento"). Cada fase roda seu próprio Dev→QA→Revisor; a Segurança (se ativa) roda uma vez só, no final, para a feature inteira

## Como você fala
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `bash tests/pipeline-state.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 6: Rodar a suíte completa**

Run: `for t in tests/*.test.sh docs-cleanup.test.sh; do bash "$t" || echo "FALHOU: $t"; done`
Expected: nenhuma linha `FALHOU`.

- [ ] **Step 7: Commit**

```bash
git add agentes/ARQUITETO.md gemini/skills/arquiteto/SKILL.md tests/pipeline-state.test.sh
git commit -m "docs: Arquiteto pode dividir features grandes em fases"
```

---

### Task 3: `agentes/TL.md` + espelho Gemini — plano organizado por fase

**Files:**
- Modify: `agentes/TL.md`
- Modify: `gemini/skills/tl/SKILL.md`
- Modify: `tests/pipeline-state.test.sh`

**Interfaces:**
- Consumes: seção de fases de `agentes/PIPELINE.md` (Task 1); frase-gatilho do Arquiteto (Task 2).
- Produces: convenção de cabeçalho `## Fase N — {nome}` usada pelo Dev/QA/Revisor (Task 5) para saber que um disparo é escopado a uma fase.

- [ ] **Step 1: Escrever o teste (vai falhar)**

Editar `tests/pipeline-state.test.sh`:

old_string:
```
exit $fail
```

new_string:
```
# Task 3 — TL.md: plano organizado por fase
check "$ROOT/agentes/TL.md" 'Organizar o plano de implementação por fase' "TL.md instrui organizar plano por fase"
check "$ROOT/agentes/TL.md" 'Fase N —' "TL.md documenta cabeçalho de fase no plano"
check "$ROOT/gemini/skills/tl/SKILL.md" 'Organizar o plano de implementação por fase' "tl/SKILL.md instrui organizar plano por fase"
check "$ROOT/gemini/skills/tl/SKILL.md" 'Fase N —' "tl/SKILL.md documenta cabeçalho de fase no plano"

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/pipeline-state.test.sh`
Expected: as 4 novas linhas com `FAIL`.

- [ ] **Step 3: Editar `agentes/TL.md`**

old_string:
```
9. **Definir que toda nomenclatura de código e banco de dados no plano seja em inglês** (tabelas, colunas, contratos, nomes de módulo) — mesmo em projeto legado com nomenclatura em português, sinaliza a inconsistência ao Bruno em vez de decidir migrar por conta própria

## Como você fala
```

new_string:
```
9. **Definir que toda nomenclatura de código e banco de dados no plano seja em inglês** (tabelas, colunas, contratos, nomes de módulo) — mesmo em projeto legado com nomenclatura em português, sinaliza a inconsistência ao Bruno em vez de decidir migrar por conta própria
10. **Organizar o plano de implementação por fase** quando o Arquiteto (ou você mesmo) identificar que a feature precisa ser dividida — cada fase com sua própria lista de tarefas, estratégia de testes e riscos. Ver `agentes/PIPELINE.md` (seção "Fases de execução e estado do pipeline")

## Como você fala
```

old_string:
````
### Riscos técnicos desta implementação
- ⚠️ {risco}: {como mitigar}
```

### Contexto do Projeto
````

new_string:
````
### Riscos técnicos desta implementação
- ⚠️ {risco}: {como mitigar}
```

Quando a feature foi dividida em fases (pelo Arquiteto ou por você), repita
esta estrutura inteira — Tarefas, Dependências, Estratégia de testes,
Riscos — uma vez por fase, sob um cabeçalho `## Fase N — {nome}`.

### Contexto do Projeto
````

- [ ] **Step 4: Editar `gemini/skills/tl/SKILL.md`**

old_string:
```
9. **Definir que toda nomenclatura de código e banco de dados no plano seja em inglês** (tabelas, colunas, contratos, nomes de módulo) — mesmo em projeto legado com nomenclatura em português, sinaliza a inconsistência ao usuário em vez de decidir migrar por conta própria

## Como você fala
```

new_string:
```
9. **Definir que toda nomenclatura de código e banco de dados no plano seja em inglês** (tabelas, colunas, contratos, nomes de módulo) — mesmo em projeto legado com nomenclatura em português, sinaliza a inconsistência ao usuário em vez de decidir migrar por conta própria
10. **Organizar o plano de implementação por fase** quando o Arquiteto (ou você mesmo) identificar que a feature precisa ser dividida — cada fase com sua própria lista de tarefas, estratégia de testes e riscos

## Como você fala
```

old_string:
````
### Estimativa total
- Otimista: {X horas}
- Realista: {Y horas}
- Pessimista: {Z horas}
```

## Perguntas que você sempre faz
````

new_string:
````
### Estimativa total
- Otimista: {X horas}
- Realista: {Y horas}
- Pessimista: {Z horas}
```

Quando a feature foi dividida em fases, repita esta estrutura inteira uma
vez por fase, sob um cabeçalho `## Fase N — {nome}`.

## Perguntas que você sempre faz
````

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `bash tests/pipeline-state.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 6: Rodar a suíte completa**

Run: `for t in tests/*.test.sh docs-cleanup.test.sh; do bash "$t" || echo "FALHOU: $t"; done`
Expected: nenhuma linha `FALHOU`.

- [ ] **Step 7: Commit**

```bash
git add agentes/TL.md gemini/skills/tl/SKILL.md tests/pipeline-state.test.sh
git commit -m "docs: TL organiza plano de implementação por fase quando aplicável"
```

---

### Task 4: `agentes/ORQUESTRADOR.md` + espelho Gemini — detecção/gravação/arquivamento do estado

**Files:**
- Modify: `agentes/ORQUESTRADOR.md`
- Modify: `gemini/skills/orquestrador/SKILL.md`
- Modify: `tests/pipeline-state.test.sh`

**Interfaces:**
- Consumes: formato de `PIPELINE-STATE.md` (Task 1); conceito de fase originado por Arquiteto/TL (Tasks 2-3).
- Produces: mecânica de leitura/escrita/arquivamento que a Task 6 (`/orquestrador-status`) e a Task 5 (Dev/QA/Revisor escopados por fase) pressupõem existir.

- [ ] **Step 1: Escrever o teste (vai falhar)**

Editar `tests/pipeline-state.test.sh`:

old_string:
```
exit $fail
```

new_string:
```
# Task 4 — ORQUESTRADOR.md: detecção/gravação/arquivamento do estado
for f in "$ROOT/agentes/ORQUESTRADOR.md" "$ROOT/gemini/skills/orquestrador/SKILL.md"; do
  check "$f" 'PIPELINE-STATE.md' "$(basename "$f") menciona PIPELINE-STATE.md"
  check "$f" 'Continuar de onde parei' "$(basename "$f") pergunta continuar/arquivar"
  check "$f" '\.pipeline-history/' "$(basename "$f") documenta arquivamento"
  check "$f" 'PIPELINE-STATE.md.corrompido' "$(basename "$f") trata estado malformado"
  check "$f" 'Estado do pipeline (PIPELINE-STATE.md)' "$(basename "$f") tem seção de estado"
  check "$f" 'contido dentro da fase atual' "$(basename "$f") escopa retrabalho à fase"
done

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/pipeline-state.test.sh`
Expected: 12 novas linhas `FAIL` (6 checks × 2 arquivos).

- [ ] **Step 3: Editar `agentes/ORQUESTRADOR.md` (parte 1 — início de sessão)**

old_string:
```
## Como você inicia uma sessão

Quando o Bruno chegar com uma solicitação, você SEMPRE:

1. Agradece e confirma que entendeu (em 1-2 linhas)
2. Apresenta o menu de etapas abaixo
3. Aguarda o Bruno marcar quais ativar

Se `agentes/TEAM.md` existir, use-o para pré-marcar o menu abaixo (em vez do
padrão fixo) antes de apresentá-lo ao Bruno.

**Menu padrão a apresentar:**
```

new_string:
```
## Como você inicia uma sessão

Antes de tudo, verifique se existe `agentes/PIPELINE-STATE.md` neste projeto:

- **Se existir:** leia e monte o mesmo resumo do comando `/orquestrador-status`
  (etapas de planejamento concluídas, fases concluídas/em andamento/pendentes,
  e a "próxima ação concreta"). Apresente esse resumo ao Bruno e pergunte:
  *"Continuar de onde parei (<próxima ação concreta>) ou arquivar e começar
  um pipeline novo?"*
  - Se continuar: pule o menu de etapas abaixo e dispare diretamente a
    próxima ação concreta descrita no arquivo, reconstruindo o contexto
    necessário a partir dos resumos já salvos ali — não do histórico da
    conversa, que pode não existir mais depois de um `/clear`.
  - Se começar do zero: arquive o estado atual em
    `agentes/.pipeline-history/<slug-da-tarefa-antiga>-<data>.md` (nunca
    apague) antes de seguir com o fluxo normal abaixo.
  - Se o arquivo existir mas estiver malformado ou incompleto (seções
    faltando, formato irreconhecível): avise que não conseguiu interpretar o
    estado, renomeie para `agentes/PIPELINE-STATE.md.corrompido-<data>`
    (preserva o conteúdo bruto, nunca sobrescreve) e siga com o fluxo normal
    abaixo.
- **Se não existir:** siga o fluxo normal abaixo.

Quando o Bruno chegar com uma solicitação nova (ou você tiver decidido
começar do zero acima), você SEMPRE:

1. Agradece e confirma que entendeu (em 1-2 linhas)
2. Apresenta o menu de etapas abaixo
3. Aguarda o Bruno marcar quais ativar
4. Assim que o menu for confirmado, cria `agentes/PIPELINE-STATE.md` com o
   cabeçalho (resumo da tarefa, data, perfil ativo) e a seção "Planejamento"
   vazia — as etapas vão sendo marcadas conforme completam (ver "Estado do
   pipeline" abaixo)

Se `agentes/TEAM.md` existir, use-o para pré-marcar o menu abaixo (em vez do
padrão fixo) antes de apresentá-lo ao Bruno.

**Menu padrão a apresentar:**
```

- [ ] **Step 4: Editar `agentes/ORQUESTRADOR.md` (parte 2 — gravação e nova seção)**

old_string:
```
Ao final de cada subagente, incorpore o resultado ao "log do contexto acumulado"
antes de montar o prompt da próxima etapa.

## Loop de Retrabalho

Se REVISOR ou SEGURANÇA encontrar problemas:
1. Apresenta os problemas ao Bruno
2. Pergunta: "Refazer automaticamente ou revisar manualmente?"
3. Se refazer: volta para a etapa correspondente com o feedback como contexto adicional

---
```

new_string:
```
Ao final de cada subagente, incorpore o resultado ao "log do contexto acumulado"
antes de montar o prompt da próxima etapa, e atualize `agentes/PIPELINE-STATE.md`
com um resumo condensado da etapa (2-3 linhas) — ver "Estado do pipeline"
abaixo. Se a etapa concluída for Dev/QA/Revisor de uma fase, marque a fase
correspondente e, quando o Revisor (ou QA/Dev, na ausência dele) aprovar,
marque a fase como concluída e atualize a "próxima ação concreta" para a
fase seguinte (ou para Segurança/encerramento, se era a última).

## Estado do pipeline (PIPELINE-STATE.md)

Formato completo e regras gerais em `agentes/PIPELINE.md` (seção "Fases de
execução e estado do pipeline"). Resumo do que cabe a você, Orquestrador:

- **Criar** o arquivo assim que o menu de etapas for confirmado (ver "Como
  você inicia uma sessão").
- **Atualizar** depois de cada subagente retornar (parágrafo acima).
- **Arquivar** em `agentes/.pipeline-history/<slug>-<data>.md` quando o
  pipeline inteiro terminar: todas as fases concluídas (se houver) e a
  última etapa ativa do perfil tiver rodado (Segurança, se ativa; senão
  Revisor; senão a última etapa do perfil escolhido).
- **Nunca** sobrescrever um estado aberto de uma tarefa diferente sem
  perguntar (ver "Como você inicia uma sessão").

## Loop de Retrabalho

Se REVISOR ou SEGURANÇA encontrar problemas:
1. Apresenta os problemas ao Bruno
2. Pergunta: "Refazer automaticamente ou revisar manualmente?"
3. Se refazer: volta para a etapa correspondente com o feedback como contexto adicional

Quando há fases, esse loop fica contido dentro da fase atual — não reabre
fases já concluídas.

---
```

- [ ] **Step 5: Editar `gemini/skills/orquestrador/SKILL.md` (parte 1 — início de sessão)**

old_string:
```
## Como você inicia uma sessão

Quando o usuário chegar com uma solicitação, você SEMPRE:

1. Confirma que entendeu (em 1-2 linhas)
2. Apresenta o menu de etapas abaixo
3. Aguarda o usuário marcar quais ativar

Se `agentes/CONTEXTO.md` existir, leia e use como pano de fundo (nunca leia o `agentes/CONTEXTO.md` de outro projeto). Se `agentes/TEAM.md` existir, use como pré-seleção padrão do menu de etapas abaixo, em vez do padrão fixo.

**Menu padrão a apresentar:**
```

new_string:
````
## Como você inicia uma sessão

Antes de tudo, verifique se existe `agentes/PIPELINE-STATE.md` neste
projeto. Formato do arquivo (mesma ideia de `CONTEXTO.md`/`TEAM.md`: dado de
projeto, markdown legível):

```markdown
# Estado do Pipeline — <resumo curto da tarefa original>

Iniciado em: <data>
Perfil ativo: <perfil> (<lista de etapas ativas>)

## Planejamento
- [x] 1. Analista — <resumo condensado, 2-3 linhas>

## Fases
- [x] Fase 1 — <nome> — concluída (Dev → QA → Revisor aprovado)
- [ ] Fase 2 — <nome> — EM ANDAMENTO (próxima ação: <ação concreta>)

## Próxima ação concreta
<frase única, acionável>
```

("Fase" é diferente de "Etapa": fase só existe dentro da execução, usada
quando o Arquiteto/TL dividem uma feature grande em entregas independentes,
cada uma com seu próprio ciclo Dev→QA→Revisor. Segurança roda uma vez só,
no final, para todas as fases.)

- **Se existir:** monte um resumo (etapas concluídas, fases
  concluídas/em andamento/pendentes, próxima ação concreta) e pergunte:
  *"Continuar de onde parei (<próxima ação concreta>) ou arquivar e começar
  um pipeline novo?"* Se continuar, pule o menu e dispare direto a próxima
  ação, reconstruindo o contexto a partir dos resumos salvos — não do
  histórico da conversa. Se começar do zero, arquive o estado atual em
  `agentes/.pipeline-history/<slug>-<data>.md` (nunca apague) antes de
  seguir. Se o arquivo estiver malformado, avise, renomeie para
  `PIPELINE-STATE.md.corrompido-<data>` e siga com o fluxo normal.
- **Se não existir:** siga o fluxo normal abaixo.

Quando o usuário chegar com uma solicitação nova (ou você tiver decidido
começar do zero acima), você SEMPRE:

1. Confirma que entendeu (em 1-2 linhas)
2. Apresenta o menu de etapas abaixo
3. Aguarda o usuário marcar quais ativar
4. Assim que o menu for confirmado, cria `agentes/PIPELINE-STATE.md` com o
   cabeçalho e a seção "Planejamento" vazia

Se `agentes/CONTEXTO.md` existir, leia e use como pano de fundo (nunca leia o `agentes/CONTEXTO.md` de outro projeto). Se `agentes/TEAM.md` existir, use como pré-seleção padrão do menu de etapas abaixo, em vez do padrão fixo.

**Menu padrão a apresentar:**
````

- [ ] **Step 6: Editar `gemini/skills/orquestrador/SKILL.md` (parte 2 — gravação e nova seção)**

old_string:
```
- Mantém um **log do contexto acumulado** entre etapas
- No final: apresenta resumo de tudo que foi feito
```

new_string:
```
- Mantém um **log do contexto acumulado** entre etapas, e atualiza `agentes/PIPELINE-STATE.md` (resumo condensado) depois de cada subagente retornar — ver "Estado do pipeline" abaixo
- No final: apresenta resumo de tudo que foi feito
```

old_string:
```
## Loop de Retrabalho

Se REVISOR ou SEGURANÇA encontrar problemas:
1. Apresenta os problemas ao Bruno
2. Pergunta: "Refazer automaticamente ou revisar manualmente?"
3. Se refazer: volta para a etapa correspondente com o feedback como contexto adicional
```

new_string:
```
## Estado do pipeline (PIPELINE-STATE.md)

- **Cria** o arquivo assim que o menu de etapas for confirmado.
- **Atualiza** depois de cada subagente retornar (ver bullet acima).
- **Arquiva** em `agentes/.pipeline-history/<slug>-<data>.md` quando o
  pipeline inteiro terminar (todas as fases concluídas, se houver, e a
  última etapa ativa do perfil já rodou).
- **Nunca** sobrescreve um estado aberto de tarefa diferente sem perguntar.

## Loop de Retrabalho

Se REVISOR ou SEGURANÇA encontrar problemas:
1. Apresenta os problemas ao Bruno
2. Pergunta: "Refazer automaticamente ou revisar manualmente?"
3. Se refazer: volta para a etapa correspondente com o feedback como contexto adicional

Quando há fases, esse loop fica contido dentro da fase atual — não reabre
fases já concluídas.
```

- [ ] **Step 7: Rodar e confirmar que passa**

Run: `bash tests/pipeline-state.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 8: Rodar a suíte completa (crítico — este é o arquivo mais tocado)**

Run: `for t in tests/*.test.sh docs-cleanup.test.sh; do bash "$t" || echo "FALHOU: $t"; done`
Expected: nenhuma linha `FALHOU`. Prestar atenção especial em
`tests/context-feedback.test.sh`, `tests/gemini-orquestrador-paridade.test.sh`,
`tests/subagentes-modelo.test.sh` e `tests/team-md.test.sh` — todos tocam
`ORQUESTRADOR.md`/`gemini/skills/orquestrador/SKILL.md`.

- [ ] **Step 9: Commit**

```bash
git add agentes/ORQUESTRADOR.md gemini/skills/orquestrador/SKILL.md tests/pipeline-state.test.sh
git commit -m "docs: Orquestrador detecta, grava e arquiva o estado do pipeline"
```

---

### Task 5: `agentes/DEV.md`, `QA.md`, `REVISOR.md` + espelhos Gemini — escopo por fase

**Files:**
- Modify: `agentes/DEV.md`, `agentes/QA.md`, `agentes/REVISOR.md`
- Modify: `gemini/skills/dev/SKILL.md`, `gemini/skills/qa/SKILL.md`, `gemini/skills/revisor/SKILL.md`
- Modify: `tests/pipeline-state.test.sh`

**Interfaces:**
- Consumes: conceito de fase (Tasks 1-4); cabeçalho `## Fase N — {nome}` do plano do TL (Task 3).

- [ ] **Step 1: Escrever o teste (vai falhar)**

Editar `tests/pipeline-state.test.sh`:

old_string:
```
exit $fail
```

new_string:
```
# Task 5 — DEV/QA/REVISOR: escopo por fase
for f in "$ROOT/agentes/DEV.md" "$ROOT/gemini/skills/dev/SKILL.md" \
         "$ROOT/agentes/QA.md" "$ROOT/gemini/skills/qa/SKILL.md"; do
  check "$f" 'Escopo por fase' "$(basename "$(dirname "$f")")/$(basename "$f") escopa trabalho por fase"
done
for f in "$ROOT/agentes/REVISOR.md" "$ROOT/gemini/skills/revisor/SKILL.md"; do
  check "$f" 'Revisar por fase' "$(basename "$(dirname "$f")")/$(basename "$f") escopa revisão por fase"
done

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/pipeline-state.test.sh`
Expected: 6 novas linhas `FAIL`.

- [ ] **Step 3: Editar `agentes/DEV.md`**

old_string:
```
- **Nomenclatura e comentários sempre em inglês**: variáveis, funções, classes, arquivos, pastas, comentários e schema de banco (tabelas/colunas) — nunca em português, mesmo com o Bruno pedindo em português (a comunicação com ele continua em português normalmente). Isso tem prioridade sobre "seguir convenções do projeto" quando o projeto legado tem nomenclatura em português: não migra o código existente em massa por conta própria, só sinaliza a inconsistência. Exceção: strings visíveis ao usuário final (UI, mensagens de erro exibidas) seguem o idioma do produto, não esta regra.

## Quando o plano está errado
```

new_string:
```
- **Nomenclatura e comentários sempre em inglês**: variáveis, funções, classes, arquivos, pastas, comentários e schema de banco (tabelas/colunas) — nunca em português, mesmo com o Bruno pedindo em português (a comunicação com ele continua em português normalmente). Isso tem prioridade sobre "seguir convenções do projeto" quando o projeto legado tem nomenclatura em português: não migra o código existente em massa por conta própria, só sinaliza a inconsistência. Exceção: strings visíveis ao usuário final (UI, mensagens de erro exibidas) seguem o idioma do produto, não esta regra.
- **Escopo por fase**: se o plano do TL foi dividido em fases, você implementa só a fase indicada no seu disparo — não a feature inteira de uma vez.

## Quando o plano está errado
```

- [ ] **Step 4: Editar `gemini/skills/dev/SKILL.md`**

old_string:
```
- **Nomenclatura e comentários sempre em inglês**: variáveis, funções, classes, arquivos, pastas, comentários e schema de banco (tabelas/colunas) — nunca em português, mesmo com o usuário pedindo em português (a comunicação com ele continua em português normalmente). Isso tem prioridade sobre "seguir convenções do projeto" quando o projeto legado tem nomenclatura em português: não migra o código existente em massa por conta própria, só sinaliza a inconsistência. Exceção: strings visíveis ao usuário final (UI, mensagens de erro exibidas) seguem o idioma do produto, não esta regra.

## Quando o plano está errado
```

new_string:
```
- **Nomenclatura e comentários sempre em inglês**: variáveis, funções, classes, arquivos, pastas, comentários e schema de banco (tabelas/colunas) — nunca em português, mesmo com o usuário pedindo em português (a comunicação com ele continua em português normalmente). Isso tem prioridade sobre "seguir convenções do projeto" quando o projeto legado tem nomenclatura em português: não migra o código existente em massa por conta própria, só sinaliza a inconsistência. Exceção: strings visíveis ao usuário final (UI, mensagens de erro exibidas) seguem o idioma do produto, não esta regra.
- **Escopo por fase**: se o plano do TL foi dividido em fases, você implementa só a fase indicada no seu disparo — não a feature inteira de uma vez.

## Quando o plano está errado
```

- [ ] **Step 5: Editar `agentes/QA.md`**

old_string:
```
5. **Nomes de teste sempre em inglês**: `describe`/`it`/`test`, nomes de fixtures e mocks — mesmo que o relatório para o Bruno seja em português. Exceção: nomes de cenário BDD copiados de um `.feature` que a etapa BDD tenha escrito em português permanecem como estão (não é o QA quem decide o idioma do BDD).

## Quando você reprova
```

new_string:
```
5. **Nomes de teste sempre em inglês**: `describe`/`it`/`test`, nomes de fixtures e mocks — mesmo que o relatório para o Bruno seja em português. Exceção: nomes de cenário BDD copiados de um `.feature` que a etapa BDD tenha escrito em português permanecem como estão (não é o QA quem decide o idioma do BDD).
6. **Escopo por fase**: se a feature foi dividida em fases, você testa só a fase indicada no seu disparo.

## Quando você reprova
```

- [ ] **Step 6: Editar `gemini/skills/qa/SKILL.md`**

old_string:
```
5. **Nomes de teste sempre em inglês**: `describe`/`it`/`test`, nomes de fixtures e mocks — mesmo que o relatório para o usuário seja em português. Exceção: nomes de cenário BDD copiados de um `.feature` que a etapa BDD tenha escrito em português permanecem como estão.

## Quando você reprova
```

new_string:
```
5. **Nomes de teste sempre em inglês**: `describe`/`it`/`test`, nomes de fixtures e mocks — mesmo que o relatório para o usuário seja em português. Exceção: nomes de cenário BDD copiados de um `.feature` que a etapa BDD tenha escrito em português permanecem como estão.
6. **Escopo por fase**: se a feature foi dividida em fases, você testa só a fase indicada no seu disparo.

## Quando você reprova
```

- [ ] **Step 7: Editar `agentes/REVISOR.md`**

old_string:
```
5. **Emitir veredito** claro: Aprovado / Aprovado com ressalvas / Reprovado com motivo

## Como você fala
```

new_string:
```
5. **Emitir veredito** claro: Aprovado / Aprovado com ressalvas / Reprovado com motivo
6. **Revisar por fase**: se a feature foi dividida em fases, você revisa só a fase indicada no seu disparo — o veredito final da feature inteira só é dado depois que todas as fases estiverem aprovadas

## Como você fala
```

- [ ] **Step 8: Editar `gemini/skills/revisor/SKILL.md`**

old_string:
```
5. **Emitir veredito** claro: Aprovado / Aprovado com ressalvas / Reprovado

## Como você fala
```

new_string:
```
5. **Emitir veredito** claro: Aprovado / Aprovado com ressalvas / Reprovado
6. **Revisar por fase**: se a feature foi dividida em fases, você revisa só a fase indicada no seu disparo — o veredito final da feature inteira só é dado depois que todas as fases estiverem aprovadas

## Como você fala
```

- [ ] **Step 9: Rodar e confirmar que passa**

Run: `bash tests/pipeline-state.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 10: Rodar a suíte completa**

Run: `for t in tests/*.test.sh docs-cleanup.test.sh; do bash "$t" || echo "FALHOU: $t"; done`
Expected: nenhuma linha `FALHOU`.

- [ ] **Step 11: Commit**

```bash
git add agentes/DEV.md agentes/QA.md agentes/REVISOR.md \
        gemini/skills/dev/SKILL.md gemini/skills/qa/SKILL.md gemini/skills/revisor/SKILL.md \
        tests/pipeline-state.test.sh
git commit -m "docs: Dev/QA/Revisor escopam o trabalho à fase indicada no disparo"
```

---

### Task 6: `commands/orquestrador-status.md` + espelho Gemini — novo comando (só leitura)

**Files:**
- Create: `commands/orquestrador-status.md`
- Create: `gemini/skills/orquestrador-status/SKILL.md`
- Modify: `tests/pipeline-state.test.sh`

**Interfaces:**
- Consumes: `agentes/PIPELINE-STATE.md` (formato definido na Task 1; escrito pelo Orquestrador na Task 4).

- [ ] **Step 1: Escrever o teste (vai falhar)**

Editar `tests/pipeline-state.test.sh`:

old_string:
```
exit $fail
```

new_string:
```
# Task 6 — comando /orquestrador-status (só leitura)
check "$ROOT/commands/orquestrador-status.md" 'PIPELINE-STATE.md' "orquestrador-status.md lê o estado"
check "$ROOT/commands/orquestrador-status.md" 'só leitura' "orquestrador-status.md é documentado como só leitura"
check "$ROOT/gemini/skills/orquestrador-status/SKILL.md" 'name: orquestrador-status' "orquestrador-status/SKILL.md tem frontmatter correto"
check "$ROOT/gemini/skills/orquestrador-status/SKILL.md" 'PIPELINE-STATE.md' "orquestrador-status/SKILL.md lê o estado"
check "$ROOT/gemini/skills/orquestrador-status/SKILL.md" 'só leitura' "orquestrador-status/SKILL.md é documentado como só leitura"

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/pipeline-state.test.sh`
Expected: 5 novas linhas `FAIL` (arquivos ainda não existem — `grep` numa checagem de arquivo inexistente também conta como falha do `check`, o script não deve quebrar por causa disso porque `check` usa `grep -q -- "$pattern" "$file"` que retorna erro se o arquivo não existe, capturado pelo `if`).

- [ ] **Step 3: Criar `commands/orquestrador-status.md`**

```markdown
---
description: Mostra o estado atual do pipeline em andamento neste projeto — etapas concluídas, fases concluídas/em andamento/pendentes, e a próxima ação concreta. Não altera nada.
---

Leia `agentes/PIPELINE-STATE.md` neste projeto.

- Se não existir: informe ao Bruno que não há nenhum pipeline em aberto
  neste projeto.
- Se existir: mostre um resumo com:
  1. Etapas de planejamento concluídas (com o resumo condensado de cada uma)
  2. Fases: quais concluídas, qual está em andamento, quais pendentes (se a
     feature foi dividida em fases — ver `agentes/PIPELINE.md`)
  3. A "próxima ação concreta" registrada no arquivo

Este comando é só leitura — nunca grava, atualiza ou arquiva o estado.
```

- [ ] **Step 4: Criar `gemini/skills/orquestrador-status/SKILL.md`**

```markdown
---
name: orquestrador-status
description: Mostra o estado atual do pipeline em andamento neste projeto — etapas concluídas, fases concluídas/em andamento/pendentes, e a próxima ação concreta. Não altera nada. Ativa quando o usuário escrever "orquestrador-status".
---

# Agente: Orquestrador — status do pipeline

Leia `agentes/PIPELINE-STATE.md` neste projeto.

- Se não existir: informe que não há nenhum pipeline em aberto neste
  projeto.
- Se existir: mostre um resumo com:
  1. Etapas de planejamento concluídas (com o resumo condensado de cada uma)
  2. Fases: quais concluídas, qual está em andamento, quais pendentes (se a
     feature foi dividida em fases)
  3. A "próxima ação concreta" registrada no arquivo

Este comando é só leitura — nunca grava, atualiza ou arquiva o estado.
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `bash tests/pipeline-state.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 6: Rodar a suíte completa (inclui paridade Gemini)**

Run: `for t in tests/*.test.sh docs-cleanup.test.sh; do bash "$t" || echo "FALHOU: $t"; done`
Expected: nenhuma linha `FALHOU`.

- [ ] **Step 7: Commit**

```bash
git add commands/orquestrador-status.md gemini/skills/orquestrador-status/SKILL.md tests/pipeline-state.test.sh
git commit -m "feat: adiciona comando /orquestrador-status (só leitura)"
```

---

### Task 7: `README.md` + `claude/skills/init-project/SKILL.md` — documentação e proteção do instalador

**Files:**
- Modify: `README.md`
- Modify: `claude/skills/init-project/SKILL.md`
- Modify: `tests/pipeline-state.test.sh`

**Interfaces:**
- Consumes: comando `/orquestrador-status` (Task 6); conceito de fases (Tasks 1-4).

- [ ] **Step 1: Escrever o teste (vai falhar)**

Editar `tests/pipeline-state.test.sh`:

old_string:
```
exit $fail
```

new_string:
```
# Task 7 — README.md e init-project/SKILL.md
check "$ROOT/README.md" '/orquestrador-status' "README documenta o comando novo"
check "$ROOT/README.md" 'agentes/PIPELINE-STATE.md' "README documenta o arquivo de estado"
check "$ROOT/claude/skills/init-project/SKILL.md" 'PIPELINE-STATE.md' "init-project protege PIPELINE-STATE.md"
check "$ROOT/claude/skills/init-project/SKILL.md" '\.pipeline-history/' "init-project protege .pipeline-history/"

exit $fail
```

- [ ] **Step 2: Rodar e confirmar que falha**

Run: `bash tests/pipeline-state.test.sh`
Expected: 4 novas linhas `FAIL`.

- [ ] **Step 3: Editar `README.md`**

old_string:
````
| `[B3]` | Bug de segurança | 1, 6, 7, 8, 9, 10 |

## Sincronizar em outra máquina
````

new_string:
````
| `[B3]` | Bug de segurança | 1, 6, 7, 8, 9, 10 |

### Retomando um pipeline em andamento

Se uma feature for grande, Arquiteto/TL podem dividir o plano em **fases**
(cada uma com seu próprio ciclo Dev → QA → Revisor). O progresso fica salvo
automaticamente em `agentes/PIPELINE-STATE.md` a cada etapa/fase concluída —
o que permite dar `/clear` a qualquer momento sem perder a posição.

```
/orquestrador-status
```

mostra o que já foi feito e a próxima ação concreta, sem alterar nada.
Rodar `/orquestrador` de novo detecta o estado aberto e pergunta se você
quer continuar de onde parou ou começar um pipeline novo.

## Sincronizar em outra máquina
````

- [ ] **Step 4: Editar `claude/skills/init-project/SKILL.md`**

old_string:
```
6. Em todos os casos, o CONTEÚDO de `agentes/CONTEXTO.md` e `agentes/TEAM.md`
   nunca é modificado, sobrescrito ou gerado pelo processo — são dados do
   projeto, não do template. No fluxo do passo 4 eles são temporariamente
   movidos para o backup e depois restaurados (cópia, não edição) para a
   pasta viva com o conteúdo exatamente igual ao original; isso é apenas
   reposicionamento de arquivo, não "tocar" no conteúdo. Nenhum outro arquivo
   do projeto (README.md, `.planning/`, etc.) é afetado.
```

new_string:
```
6. Em todos os casos, o CONTEÚDO de `agentes/CONTEXTO.md`, `agentes/TEAM.md`,
   `agentes/PIPELINE-STATE.md` e `agentes/.pipeline-history/` nunca é
   modificado, sobrescrito ou gerado pelo processo — são dados do projeto,
   não do template (`PIPELINE-STATE.md` e `.pipeline-history/` sequer
   existem antes de o Orquestrador rodar). No fluxo do passo 4, `CONTEXTO.md`
   e `TEAM.md` são temporariamente movidos para o backup e depois
   restaurados (cópia, não edição) para a pasta viva com o conteúdo
   exatamente igual ao original; isso é apenas reposicionamento de arquivo,
   não "tocar" no conteúdo. Nenhum outro arquivo do projeto (README.md,
   `.planning/`, etc.) é afetado.
```

- [ ] **Step 5: Rodar e confirmar que passa**

Run: `bash tests/pipeline-state.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 6: Rodar a suíte completa**

Run: `for t in tests/*.test.sh docs-cleanup.test.sh; do bash "$t" || echo "FALHOU: $t"; done`
Expected: nenhuma linha `FALHOU`.

- [ ] **Step 7: Commit**

```bash
git add README.md claude/skills/init-project/SKILL.md tests/pipeline-state.test.sh
git commit -m "docs: documenta /orquestrador-status e protege PIPELINE-STATE.md no instalador"
```

---

### Task 8: Verificação final

**Files:**
- Nenhum arquivo novo — só validação.

- [ ] **Step 1: Rodar a suíte inteira do zero**

Run: `cd /Users/bruno.andrade/projetos/pessoal/agentes-pipeline && for t in tests/*.test.sh docs-cleanup.test.sh; do echo "== $t =="; bash "$t" || echo "FALHOU: $t"; done`
Expected: todo teste imprime só linhas `PASS`, nenhuma linha `FALHOU` ao final.

- [ ] **Step 2: Conferir a lista de arquivos tocados no total**

Run: `git log --oneline -8` e `git diff --stat HEAD~7` (ajustar o número de commits conforme quantas tasks geraram commit)
Expected: `agentes/{PIPELINE,ARQUITETO,TL,ORQUESTRADOR,DEV,QA,REVISOR}.md`,
`gemini/skills/{arquiteto,tl,orquestrador,dev,qa,revisor,orquestrador-status}/SKILL.md`,
`commands/orquestrador-status.md`, `README.md`,
`claude/skills/init-project/SKILL.md`, `tests/pipeline-state.test.sh`.

- [ ] **Step 3: Se algo faltar ou algum teste antigo tiver quebrado, corrigir inline e recommitar antes de encerrar**

Sem passo de commit aqui — esta task é só um gate de verificação; se tudo já
passou nas tasks anteriores, não há nada novo para commitar.
