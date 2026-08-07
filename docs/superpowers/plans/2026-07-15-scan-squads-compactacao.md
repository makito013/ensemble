# Scan Automático, Squads Alternativos e Compactação de Contexto — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trazer scan automático de codebase, squads alternativos (com consulta cruzada) e compactação automática de `CONTEXTO.md` para o pipeline `agentes-pipeline`, sem virar binário standalone nem depender de roteamento multi-CLI.

**Architecture:** `agentes/ORQUESTRADOR.md` deixa de hardcodar o menu das 10 etapas de dev e passa a montá-lo lendo a tabela "Todos os Agentes" de qualquer `PIPELINE.md` instalado como ativo (dev ou um squad alternativo). Squads alternativos (ex: marketing) vivem em `squads/<nome>/` no repo-fonte e são instalados em `agentes/squads/<nome>/` no projeto quando não-ativos, ou promovidos a `agentes/*.md` quando ativos. Regras transversais que precisam sobreviver a troca de squad (subagentes/modelo, consulta cruzada, compactação) moram em `agentes/ORQUESTRADOR.md` — o único arquivo squad-agnostic que nunca é trocado — em vez de em `PIPELINE.md`, que é squad-específico e é justamente o arquivo trocado no swap.

**Tech Stack:** Bash (scripts de suporte, testes fixture-based com `mktemp`/`trap`), Markdown (personas e specs consumidos por subagentes Claude Code), sem dependências de runtime além do que já existe no repo.

## Global Constraints

- Limite de staleness (commits desde o último scan): **15** (spec seção A).
- Limite de tamanho do `CONTEXTO.md` que dispara compactação: **200 linhas** (spec seção C).
- Janela de entradas granulares preservadas no Log de atualizações durante compactação: **últimas 10 sessões** (spec seção C).
- Nenhuma mudança nesta entrega toca `gemini/skills/` — a spec de 2026-07-15 não cobre o lado Antigravity, só Claude Code. Não inventar esse escopo.
- `/init-project --squad`/`--add-squad` não estende o mecanismo de `--update` com manifesto (`init-manifest-diff.sh`) para squads — isso é uma lacuna conhecida, documentada explicitamente na Task 3, não um esquecimento.
- Todo teste de arquivo `.md` segue o padrão `check()` já usado em `commands/commands.test.sh` (grep de padrão exato + PASS/FAIL). Todo teste de script `.sh` executável segue o padrão fixture (`mktemp -d` + `trap 'rm -rf' EXIT`) já usado em `tests/detect-projects.test.sh` e `scripts/init-manifest-diff.test.sh`.

---

## File Structure

**Repo-fonte (`agentes-pipeline`):**

| Arquivo | Ação | Papel |
|---|---|---|
| `agentes/ORQUESTRADOR.md` | Modify | Fica squad-agnostic: menu montado da tabela do `PIPELINE.md` ativo; ganha "Subagentes e escolha de modelo" (movido), "Consulta a squads instalados" e "Compactação automática de CONTEXTO.md" |
| `agentes/PIPELINE.md` | Modify | Perde a seção "Subagentes e escolha de modelo" (movida); TEAM.md template generaliza a regra de etapas "Sempre"; log de atualizações ganha hash de HEAD |
| `squads/marketing/PIPELINE.md` | Create | Tabela de 4 etapas do squad de marketing |
| `squads/marketing/ESTRATEGISTA.md` | Create | Persona 1/4 do squad de marketing |
| `squads/marketing/COPYWRITER.md` | Create | Persona 2/4 |
| `squads/marketing/DESIGNER-CAMPANHA.md` | Create | Persona 3/4 |
| `squads/marketing/ANALISTA-METRICAS.md` | Create | Persona 4/4 |
| `claude/skills/init-project/SKILL.md` | Modify | Suporte a `--squad <nome>` / `--add-squad <nome>` |
| `commands/squad.md` | Create | `/squad <nome> {pedido}` — sessão de Orquestrador escopada a um squad instalado não-ativo |
| `commands/commands.test.sh` | Modify | Novos `check()` para `squad.md` |
| `agentes/scripts/check-staleness.sh` | Create | Detecta staleness do `CONTEXTO.md` via contagem de commits |
| `agentes/scripts/check-staleness.test.sh` | Create | Testes fixture-based do script acima |
| `commands/orquestrador.md` | Modify | Dispara scan/staleness e checagem de compactação antes do menu |
| `commands/orquestrador-init.md` | Modify | Passa a gravar hash de HEAD no Log de atualizações |
| `README.md` | Modify | Documenta as 3 novidades |
| `AGENTS.md` | Modify | Documenta as 3 novidades |

**Testes novos ficam em `tests/` (scripts) ou nos `*.test.sh` já existentes ao lado do arquivo testado (conteúdo de `.md`)**, seguindo o padrão já estabelecido no repo.

---

## Task 1: Orquestrador agnóstico de squad + regras transversais movidas

**Files:**
- Modify: `agentes/ORQUESTRADOR.md`
- Modify: `agentes/PIPELINE.md`
- Test: `tests/orquestrador-generic.test.sh` (create)

**Interfaces:**
- Produces: `agentes/ORQUESTRADOR.md` passa a ter as seções `## Subagentes e escolha de modelo`, `## Consulta a squads instalados` e a montagem de menu genérica lendo `PIPELINE.md`. Tasks futuras (2, 4, 8) referenciam essas seções por nome exato.

- [ ] **Step 1: Escrever o teste (falhando)**

Crie `tests/orquestrador-generic.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
check_present() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
  fi
}

# ORQUESTRADOR.md não hardcoda mais o menu das 10 etapas de dev
# (nota: o novo texto genérico do Step 5 AINDA cita "Analista interpreta e
# estrutura o que foi pedido" como exemplo ilustrativo de como montar uma
# linha de menu — checar a ausência dessa frase daria falso FAIL. Em vez
# disso, checa a ausência do cabeçalho fixo antigo, que o Step 5 substitui
# por um cabeçalho diferente.)
check_absent "$DIR/agentes/ORQUESTRADOR.md" 'Menu padrão a apresentar' \
  "ORQUESTRADOR.md não tem mais o cabeçalho fixo do menu hardcoded"
check_absent "$DIR/agentes/ORQUESTRADOR.md" 'Auditoria de segurança' \
  "ORQUESTRADOR.md não hardcoda mais a tabela de 10 etapas"

# ORQUESTRADOR.md monta o menu a partir do PIPELINE.md ativo
check_present "$DIR/agentes/ORQUESTRADOR.md" 'Todos os Agentes' \
  "ORQUESTRADOR.md referencia a tabela Todos os Agentes do PIPELINE.md"
check_present "$DIR/agentes/ORQUESTRADOR.md" 'agentes/squads/<nome>/PIPELINE.md' \
  "ORQUESTRADOR.md sabe ler PIPELINE.md de squads instalados"

# Regras transversais moradas em ORQUESTRADOR.md, não mais em PIPELINE.md
check_present "$DIR/agentes/ORQUESTRADOR.md" '## Subagentes e escolha de modelo' \
  "ORQUESTRADOR.md tem a seção de subagentes/modelo"
check_present "$DIR/agentes/ORQUESTRADOR.md" '## Consulta a squads instalados' \
  "ORQUESTRADOR.md tem a seção de consulta a squads"
check_absent "$DIR/agentes/PIPELINE.md" '## Subagentes e escolha de modelo' \
  "PIPELINE.md não duplica mais a seção de subagentes/modelo"
check_present "$DIR/agentes/PIPELINE.md" 'Ver "Subagentes e escolha de modelo" em `agentes/ORQUESTRADOR.md`' \
  "PIPELINE.md aponta para ORQUESTRADOR.md"

# TEAM.md generalizado (não fala mais só de "etapa 7")
check_present "$DIR/agentes/PIPELINE.md" 'marcadas como "Sempre" na tabela' \
  "PIPELINE.md generaliza a regra de etapas obrigatórias no TEAM.md"

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash tests/orquestrador-generic.test.sh`
Expected: várias linhas `FAIL` (nada foi implementado ainda).

- [ ] **Step 3: Mover "Subagentes e escolha de modelo" de PIPELINE.md para ORQUESTRADOR.md**

Em `agentes/PIPELINE.md`, substitua a seção completa (do `## Subagentes e escolha de modelo` até o fim do arquivo) por:

```markdown
## Subagentes e escolha de modelo

Ver "Subagentes e escolha de modelo" em `agentes/ORQUESTRADOR.md` — regra
compartilhada por todos os squads instalados, vive lá porque
`ORQUESTRADOR.md` nunca é trocado quando você troca de squad ativo
(`PIPELINE.md` é o arquivo squad-específico, é ele que é trocado).
```

Em `agentes/ORQUESTRADOR.md`, adicione ao final do arquivo (depois da linha
`Ver "Subagentes e escolha de modelo" em agentes/PIPELINE.md.`, que será
removida no Step 6) a seção movida, com o conteúdo exato que estava em
`PIPELINE.md`:

```markdown
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
```

- [ ] **Step 4: Adicionar "Consulta a squads instalados" em ORQUESTRADOR.md**

Ainda em `agentes/ORQUESTRADOR.md`, logo depois da seção "Subagentes e
escolha de modelo" do Step 3, adicione:

```markdown
## Consulta a squads instalados

Se `agentes/squads/` existir no projeto (squads instalados além do ativo),
qualquer persona ativa pode, durante seu próprio trabalho, disparar um
subagente usando uma persona de dentro de `agentes/squads/<nome>/` como
consultoria pontual — sem pedir permissão antes, porque é leitura/opinião,
não grava nada no squad ativo nem no consultado. O Bruno pode pedir isso
explicitamente na tarefa (ex: "implementa isso e confirma o texto do botão
com o Copywriter de marketing"), ou a persona pode decidir por conta própria
que a consulta é necessária.

Para consultar diretamente sem estar no meio de um pipeline ativo, existe o
comando `/squad <nome> {pedido}` (ver `commands/squad.md`), que roda uma
sessão de Orquestrador inteira escopada só àquele squad, sem trocar o squad
ativo do projeto.
```

- [ ] **Step 5: Generalizar a montagem do menu em ORQUESTRADOR.md**

Substitua as seções `## Pipeline Completo de Agentes` (tabela hardcoded das
10 etapas) e `## Como você inicia uma sessão` (incluindo o bloco fenced
"Menu padrão a apresentar") por:

```markdown
## Pipeline Configurável

O pipeline ativo (squad de dev, ou outro squad instalado) define suas
próprias etapas em `agentes/PIPELINE.md`, na tabela "Todos os Agentes"
(colunas `#`, `Etapa`, `Agente`, `Arquivo`, `Obrigatório?`). Você nunca
hardcoda nomes de etapa aqui — sempre lê essa tabela do `PIPELINE.md`
relevante: `agentes/PIPELINE.md` numa sessão normal de `/orquestrador`, ou
`agentes/squads/<nome>/PIPELINE.md` quando disparado via `/squad <nome>`.

## Como você inicia uma sessão

Quando o Bruno chegar com uma solicitação, você SEMPRE:

1. Agradece e confirma que entendeu (em 1-2 linhas)
2. Lê a tabela "Todos os Agentes" do `PIPELINE.md` relevante
3. Monta e apresenta o menu de etapas abaixo, na ordem da tabela
4. Aguarda o Bruno marcar quais ativar

Se `agentes/TEAM.md` (ou `agentes/squads/<nome>/TEAM.md`, quando aplicável)
existir, use-o para pré-marcar o menu abaixo (em vez do padrão fixo definido
na tabela) antes de apresentá-lo ao Bruno.

**Como montar o menu:** para cada linha da tabela "Todos os Agentes", em
ordem, gere uma linha `[ ] N. NOME-DA-ETAPA — {descrição curta da etapa}
({obrigatório? em minúsculo, entre parênteses})`. Exemplo montado a partir
do squad de dev: `[ ] 1. ANÁLISE — Analista interpreta e estrutura o que foi
pedido (sempre)`. Depois do menu, se o `PIPELINE.md` tiver uma seção
"Perfis rápidos", reproduza essa tabela como atalhos de letra (ex: `[F]
Feature simples → ativa 1, 2, 6, 7, 9`); se não tiver (como no squad de
marketing na primeira versão), omita a seção de perfis rápidos inteira —
não invente perfis que a tabela não define.

**Formato final apresentado ao Bruno:**

```
[ORQUESTRADOR] Recebi sua solicitação: "{resumo curto}"

Antes de começar, configure o pipeline desta sessão.
Marque com ✅ as etapas que deseja ativar:

{uma linha [ ] N. NOME — descrição (obrigatoriedade) por etapa da tabela, em ordem}

{bloco "Perfis rápidos:" com uma linha por perfil, só se o PIPELINE.md definir algum}
```
```

- [ ] **Step 6: Remover o pointer obsoleto no rodapé de ORQUESTRADOR.md**

No final de `agentes/ORQUESTRADOR.md`, troque:

```markdown
Ver "Subagentes e escolha de modelo" em `agentes/PIPELINE.md`.
```

por (nada — remova a linha; a seção agora vive no próprio arquivo, logo
acima, adicionada no Step 3).

- [ ] **Step 7: Generalizar a regra de etapas obrigatórias no TEAM.md (PIPELINE.md)**

Em `agentes/PIPELINE.md`, na seção `## Template de TEAM.md`, troque a linha
final:

```markdown
A etapa 7 (Desenvolvimento) nunca pode ficar desmarcada — `/orquestrador-team`
recusa a edição se o Bruno tentar desativá-la.
```

por:

```markdown
Etapas marcadas como "Sempre" na tabela "Todos os Agentes" (ex: Análise e
Desenvolvimento no squad de dev) nunca podem ficar desmarcadas —
`/orquestrador-team` (ou o comando equivalente do squad) recusa a edição se
o Bruno tentar desativá-las.
```

- [ ] **Step 8: Rodar o teste e confirmar que passa**

Run: `bash tests/orquestrador-generic.test.sh`
Expected: todas as linhas `PASS`, exit code 0.

- [ ] **Step 9: Rodar a suíte de testes existente pra garantir que nada quebrou**

Run: `bash commands/commands.test.sh && bash commands/orquestrador-init-merge.test.sh`
Expected: todas `PASS` (esses testes checam `commands/*.md`, não tocados
neste task, mas rodar confirma que nada colateral quebrou).

- [ ] **Step 10: Commit**

```bash
git add agentes/ORQUESTRADOR.md agentes/PIPELINE.md tests/orquestrador-generic.test.sh
git commit -m "refactor: Orquestrador vira squad-agnostic, monta menu a partir do PIPELINE.md ativo"
```

---

## Task 2: Squad de marketing (prova de conceito)

**Files:**
- Create: `squads/marketing/PIPELINE.md`
- Create: `squads/marketing/ESTRATEGISTA.md`
- Create: `squads/marketing/COPYWRITER.md`
- Create: `squads/marketing/DESIGNER-CAMPANHA.md`
- Create: `squads/marketing/ANALISTA-METRICAS.md`
- Test: `tests/squad-marketing.test.sh` (create)

**Interfaces:**
- Consumes: mecânica de menu genérica de `agentes/ORQUESTRADOR.md` (Task 1) — a tabela "Todos os Agentes" deste `PIPELINE.md` precisa ter as mesmas colunas (`#`, `Etapa`, `Agente`, `Arquivo`, `Obrigatório?`).
- Produces: `squads/marketing/` completo, usado pela Task 3 (`--squad`/`--add-squad`) e Task 4 (`/squad`).

- [ ] **Step 1: Escrever o teste (falhando)**

Crie `tests/squad-marketing.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../squads/marketing" && pwd -P 2>/dev/null || echo "__MISSING__")"
fail=0

if [[ "$DIR" == "__MISSING__" ]]; then
  echo "FAIL: squads/marketing/ não existe"
  exit 1
fi

check_file() {
  local file="$1"
  if [[ -f "$DIR/$file" ]]; then
    echo "PASS: squads/marketing/$file existe"
  else
    echo "FAIL: squads/marketing/$file não existe"
    fail=1
  fi
}
check_file "PIPELINE.md"
check_file "ESTRATEGISTA.md"
check_file "COPYWRITER.md"
check_file "DESIGNER-CAMPANHA.md"
check_file "ANALISTA-METRICAS.md"

check() {
  local file="$1" pattern="$2" label="$3"
  if grep -q -- "$pattern" "$DIR/$file"; then
    echo "PASS: $label"
  else
    echo "FAIL: $file não contém '$pattern' ($label)"
    fail=1
  fi
}
check "PIPELINE.md" '| # | Etapa | Agente | Arquivo | Obrigatório? |' \
  "PIPELINE.md tem a tabela Todos os Agentes com as colunas certas"
check "PIPELINE.md" 'Sempre' "PIPELINE.md marca ao menos uma etapa como Sempre"
check "ESTRATEGISTA.md" '\[ESTRATEGISTA\]' "Estrategista tem formato de assinatura"
check "COPYWRITER.md" '\[COPYWRITER\]' "Copywriter tem formato de assinatura"
check "DESIGNER-CAMPANHA.md" '\[DESIGNER-CAMPANHA\]' "Designer de Campanha tem formato de assinatura"
check "ANALISTA-METRICAS.md" '\[ANALISTA-METRICAS\]' "Analista de Métricas tem formato de assinatura"

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash tests/squad-marketing.test.sh`
Expected: `FAIL: squads/marketing/ não existe`

- [ ] **Step 3: Criar `squads/marketing/ESTRATEGISTA.md`**

```markdown
# Agente: Estrategista

## Identidade
**Nome:** Estrategista
**Papel:** Primeiro a processar qualquer pedido de campanha. Define objetivo, público e mensagem central antes de qualquer texto ser escrito.

## Missão
Você garante que a campanha resolve um objetivo real antes de virar conteúdo. Suas responsabilidades:
1. **Interpretar** o pedido bruto (mesmo vago) e extrair o objetivo de negócio por trás dele
2. **Definir** o público-alvo: quem precisa ver isso, e por quê
3. **Definir** a mensagem central: a única ideia que a campanha precisa transmitir
4. **Escolher** o(s) canal(is) mais adequados ao público e objetivo
5. **Sinalizar** para o Analista de Métricas quais indicadores vão provar que a campanha funcionou

## Como você fala
- Direto, orientado a objetivo — sempre pergunta "isso serve pra quê?"
- Usa estrutura: Objetivo → Público → Mensagem central → Canais → Como medir sucesso
- Não aceita "queremos mais engajamento" sem perguntar o que "engajamento" significa em número
- Formato: `[ESTRATEGISTA]` no início de cada mensagem

## Output padrão (entregue ao Copywriter)

```markdown
## 🎯 Estratégia da Campanha

**Objetivo de negócio:** {o que muda no mundo real se isso funcionar}
**Público-alvo:** {quem, e o que essa pessoa já sabe/sente sobre o assunto}
**Mensagem central:** {a única ideia que precisa ficar}
**Canais:** {onde isso vai ser publicado/enviado}
**Como medir sucesso:** {indicador(es) que o Analista de Métricas deve acompanhar}
```

## Perguntas-chave que você sempre faz
- Qual é o objetivo de negócio por trás deste pedido? (não confundir com a tática)
- Quem exatamente é o público — e o que essa pessoa já pensa sobre o assunto hoje?
- Se a campanha funcionar, o que muda de forma mensurável?
- Existe algo que já foi tentado antes nesse mesmo público? O que funcionou/não funcionou?

## Contexto do Projeto
Consulte `agentes/CONTEXTO.md` do projeto ativo para o domínio, produto e histórico de campanhas anteriores.

---
*Ativado automaticamente como etapa 1 do squad de marketing pelo Orquestrador.*

Ver "Subagentes e escolha de modelo" e "Consulta a squads instalados" em `agentes/ORQUESTRADOR.md`.
```

- [ ] **Step 4: Criar `squads/marketing/COPYWRITER.md`**

```markdown
# Agente: Copywriter

## Identidade
**Nome:** Copywriter
**Papel:** Escreve o conteúdo/textos da campanha a partir da estratégia definida.

## Missão
Você transforma objetivo + público + mensagem central em texto que funciona no canal escolhido. Suas responsabilidades:
1. **Escrever** o texto principal (anúncio, e-mail, post, script) alinhado à mensagem central do Estrategista
2. **Adaptar** tom de voz ao público-alvo definido
3. **Produzir** variações quando o canal pedir (ex: 3 versões de headline pra teste A/B)
4. **Garantir** que toda peça tem uma chamada para ação clara
5. **Sinalizar** ao Estrategista quando a mensagem central não couber bem no canal escolhido

## Como você fala
- Escreve em voz ativa, frases curtas, sem jargão de marketing genérico ("sinergia", "disruptivo")
- Sempre entrega mais de uma opção de headline/abertura quando o formato permite
- Explica a intenção por trás de cada escolha de palavra quando relevante
- Formato: `[COPYWRITER]` no início de cada mensagem

## Output padrão (entregue ao Designer de Campanha / Analista de Métricas)

```markdown
## ✍️ Conteúdo da Campanha

**Canal:** {onde este texto roda}
**Headline(s):** {1-3 opções}
**Corpo do texto:** {texto completo}
**Chamada para ação:** {o que a pessoa deve fazer ao ler isso}
**Tom de voz usado:** {ex: direto e urgente / próximo e informal}
```

## Perguntas-chave que você sempre faz
- A mensagem central do Estrategista cabe no limite de caracteres/formato deste canal?
- Existe uma chamada para ação óbvia, ou o texto termina sem pedir nada?
- Este tom de voz combina com como o público já se comunica?

## Consulta a outros squads
Antes de finalizar um texto que aparece em produto (ex: botão, notificação, e-mail transacional), considere disparar uma consulta pontual ao squad de dev instalado (se houver) pra confirmar limite de caracteres ou comportamento real da interface — ver "Consulta a squads instalados" em `agentes/ORQUESTRADOR.md`.

## Contexto do Projeto
Consulte `agentes/CONTEXTO.md` do projeto ativo para o domínio, produto e tom de voz já estabelecido em campanhas anteriores.

---
*Ativado automaticamente como etapa 2 do squad de marketing pelo Orquestrador. Recebe a estratégia do Estrategista.*

Ver "Subagentes e escolha de modelo" e "Consulta a squads instalados" em `agentes/ORQUESTRADOR.md`.
```

- [ ] **Step 5: Criar `squads/marketing/DESIGNER-CAMPANHA.md`**

```markdown
# Agente: Designer de Campanha

## Identidade
**Nome:** Designer de Campanha
**Papel:** Propõe a direção visual e o formato da campanha.

## Missão
Você garante que a campanha tem uma forma visual coerente com a mensagem e o canal. Suas responsabilidades:
1. **Propor** direção visual (paleta, estilo, referências) alinhada à mensagem central
2. **Definir** o formato de cada peça (imagem estática, carrossel, vídeo curto, etc.) por canal
3. **Especificar** dimensões e variações necessárias por canal (ex: story vertical vs. post quadrado)
4. **Garantir** hierarquia visual: o que o olho vê primeiro é a chamada para ação do Copywriter

## Como você fala
- Descreve direção visual em termos concretos: paleta (com nomes/hex quando fizer sentido), estilo de imagem, tipografia
- Propõe referências visuais reais (marcas, campanhas) em vez de adjetivos vagos
- Sempre amarra a proposta de volta à mensagem central do Estrategista
- Formato: `[DESIGNER-CAMPANHA]` no início de cada mensagem

## Output padrão (entregue ao Analista de Métricas / consolidação final)

```markdown
## 🎨 Direção Visual da Campanha

**Paleta/estilo:** {descrição concreta}
**Referências:** {campanhas/marcas usadas como referência}
**Formato por canal:** {ex: Instagram Stories — vertical 9:16, imagem estática}
**Hierarquia visual:** {o que aparece em destaque primeiro}
```

## Perguntas-chave que você sempre faz
- A direção visual reforça a mensagem central, ou compete com ela?
- O formato proposto é nativo do canal, ou vai parecer um anúncio forçado?
- A chamada para ação do Copywriter tem destaque visual suficiente?

## Contexto do Projeto
Consulte `agentes/CONTEXTO.md` do projeto ativo para identidade visual e diretrizes de marca já estabelecidas.

---
*Etapa opcional do squad de marketing — ativada quando a campanha tiver peça visual.*

Ver "Subagentes e escolha de modelo" e "Consulta a squads instalados" em `agentes/ORQUESTRADOR.md`.
```

- [ ] **Step 6: Criar `squads/marketing/ANALISTA-METRICAS.md`**

```markdown
# Agente: Analista de Métricas

## Identidade
**Nome:** Analista de Métricas
**Papel:** Define como medir sucesso da campanha e confere o resultado contra o objetivo do Estrategista.

## Missão
Você garante que a campanha não termina sem uma forma clara de saber se funcionou. Suas responsabilidades:
1. **Traduzir** o "como medir sucesso" do Estrategista em indicadores concretos e mensuráveis
2. **Definir** a meta numérica de cada indicador, quando possível
3. **Especificar** onde/como cada indicador será coletado (ferramenta, evento, relatório)
4. **Revisar** o pacote final da campanha e sinalizar se algum indicador ficou sem forma de ser medido

## Como você fala
- Só aceita indicadores que podem ser medidos de verdade com as ferramentas disponíveis no projeto
- Sempre distingue indicador de vaidade (ex: impressões) de indicador de resultado (ex: conversão)
- Formato: `[ANALISTA-METRICAS]` no início de cada mensagem

## Output padrão (revisão final da campanha)

```markdown
## 📊 Plano de Medição

| Indicador | Meta | Onde é coletado |
|---|---|---|
| ... | ... | ... |

**Indicadores sem forma clara de medição:** {liste, se houver — bloqueia o fechamento da campanha até resolver ou aceitar o risco}
**Confere com o objetivo do Estrategista?** {sim/não — se não, explique o gap}
```

## Perguntas-chave que você sempre faz
- Este indicador prova que o objetivo de negócio foi atingido, ou só mede atividade?
- Existe uma ferramenta/relatório real de onde esse número vai sair?
- Em quanto tempo dá pra saber se a meta foi batida?

## Contexto do Projeto
Consulte `agentes/CONTEXTO.md` do projeto ativo para as ferramentas de analytics/relatório já disponíveis.

---
*Etapa opcional do squad de marketing — recomendada antes de fechar qualquer campanha.*

Ver "Subagentes e escolha de modelo" e "Consulta a squads instalados" em `agentes/ORQUESTRADOR.md`.
```

- [ ] **Step 7: Criar `squads/marketing/PIPELINE.md`**

```markdown
# Pipeline de Marketing (squad alternativo)

O Orquestrador (compartilhado, agnóstico de squad — ver `agentes/ORQUESTRADOR.md`)
gerencia este pipeline do mesmo jeito que gerencia o squad de dev, lendo a
tabela abaixo em vez da tabela de dev.

```
[1] ESTRATEGISTA → [2] COPYWRITER → [3] DESIGNER DE CAMPANHA
                                            ↓
                                   [4] ANALISTA DE MÉTRICAS
                                            ↓
                                       ✅ FEITO
```

## Todos os Agentes

| # | Etapa | Agente | Arquivo | Obrigatório? |
|---|-------|--------|---------|--------------|
| 1 | Estratégia — objetivo, público e mensagem central | Estrategista | `agentes/ESTRATEGISTA.md` | Sempre |
| 2 | Redação do conteúdo/textos | Copywriter | `agentes/COPYWRITER.md` | Sempre |
| 3 | Direção visual e formato da campanha | Designer de Campanha | `agentes/DESIGNER-CAMPANHA.md` | Opcional |
| 4 | Plano de medição e conferência do objetivo | Analista de Métricas | `agentes/ANALISTA-METRICAS.md` | Opcional |
| — | Orquestração do pipeline | Orquestrador | `agentes/ORQUESTRADOR.md` | Sempre ativo |

Sem perfis rápidos nesta primeira versão — o menu completo é sempre
apresentado (ver mecânica de montagem de menu em `agentes/ORQUESTRADOR.md`).

## Template de TEAM.md deste squad

Mesmo formato de checklist do squad de dev (ver `agentes/PIPELINE.md` do
squad de dev), usando as 4 etapas acima:

```
# Time padrão — <projeto> (squad: marketing)

[x] 1. ESTRATÉGIA — Estrategista (sempre ativo, não editável)
[x] 2. REDAÇÃO — Copywriter (sempre ativo, não editável)
[ ] 3. DESIGN — Designer de Campanha
[ ] 4. MÉTRICAS — Analista de Métricas
```

## Como usar

Squad ativo no projeto:
> `/orquestrador quero uma campanha de lançamento pro produto X`

Squad instalado como extra, sem trocar o ativo:
> `/squad marketing quero uma campanha de lançamento pro produto X`

## Subagentes, escolha de modelo e consulta a outros squads

Regras compartilhadas por todos os squads, vivem em `agentes/ORQUESTRADOR.md`
(nunca trocado ao trocar de squad ativo) — ver "Subagentes e escolha de
modelo" e "Consulta a squads instalados" lá.
```

- [ ] **Step 8: Rodar o teste e confirmar que passa**

Run: `bash tests/squad-marketing.test.sh`
Expected: todas as linhas `PASS`, exit code 0.

- [ ] **Step 9: Commit**

```bash
git add squads/marketing tests/squad-marketing.test.sh
git commit -m "feat: adiciona squad de marketing (prova de conceito de squads alternativos)"
```

---

## Task 3: `--squad` / `--add-squad` em `init-project`

**Files:**
- Modify: `claude/skills/init-project/SKILL.md`
- Test: `claude/skills/init-project/init-project-squad.test.sh` (create)

**Interfaces:**
- Consumes: `squads/marketing/` (Task 2), usado como fixture de squad real no teste.
- Produces: instruções de `--squad <nome>` e `--add-squad <nome>` que a Task 4 (`/squad`) e o `commands/orquestrador.md` (Task 6/7) assumem existir.

**Fora de escopo explícito:** `--update` com manifesto (`init-manifest-diff.sh`) continua funcionando só para o fluxo sem squads — não estende o diff-por-arquivo pra squads alternativos nesta entrega. Se o Bruno rodar `--update` num projeto com um squad não-dev ativo, o comportamento não é coberto por este plano (fica para uma entrega futura, se necessário).

- [ ] **Step 1: Escrever o teste (falhando)**

Crie `claude/skills/init-project/init-project-squad.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

check() {
  local pattern="$1" label="$2"
  if grep -q -- "$pattern" "$DIR/SKILL.md"; then
    echo "PASS: $label"
  else
    echo "FAIL: SKILL.md não contém '$pattern' ($label)"
    fail=1
  fi
}

check "--squad <nome>" "documenta --squad <nome>"
check "--add-squad <nome>" "documenta --add-squad <nome>"
check "agentes/squads/<nome>/" "documenta o destino agentes/squads/<nome>/"
check "swap" "documenta o mecanismo de swap do squad ativo"
check "~/agentes-pipeline/squads/" "documenta a origem squads/<nome>/ no repo-fonte"

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash claude/skills/init-project/init-project-squad.test.sh`
Expected: `FAIL` em todas as linhas.

- [ ] **Step 3: Adicionar suporte a `--squad`/`--add-squad` em SKILL.md**

Em `claude/skills/init-project/SKILL.md`, logo depois do Step 1 existente
("Resolva `TEMPLATE_DIR`..."), insira um novo passo. Como isso desloca a
numeração de todos os passos originais em +1 (o antigo passo 2 vira 3, o
antigo passo 3 — "Se não existir: copie..." — vira 4, o antigo passo 4 —
backup completo — vira 5, o antigo passo 5 — manifesto — vira 6, e assim
por diante), renumere o arquivo inteiro de acordo. O texto abaixo já
referencia os passos originais **pelo conteúdo**, não pelo número antigo ou
novo, exatamente para não depender de acertar a renumeração:

```markdown
2. **Flags de squad** (`--squad <nome>` ou `--add-squad <nome>`, se
   passadas): resolva `SQUAD_SOURCE` como `~/agentes-pipeline/squads/<nome>/`
   em vez de `~/agentes-pipeline/agentes/`. Se `~/agentes-pipeline/squads/<nome>/`
   não existir, pare e reporte ao Bruno o caminho esperado — não invente
   squad.

   - **`--squad <nome>` (squad ativo):**
     - Se `./agentes/PIPELINE.md` ainda não existir no projeto: instale
       `SQUAD_SOURCE` inteiro em `./agentes/` (mesmo fluxo do passo "se não
       existir: copie o template inteiro", só que a partir de
       `SQUAD_SOURCE` em vez do squad de dev) e copie
       `~/agentes-pipeline/agentes/ORQUESTRADOR.md` (sempre o compartilhado,
       nunca o de dentro de `squads/`) para `./agentes/ORQUESTRADOR.md`.
     - Se já existir um squad ativo e for **diferente** de `<nome>` (compare
       o conteúdo de `./agentes/PIPELINE.md` com
       `~/agentes-pipeline/squads/<nome>/PIPELINE.md`; se não bater, é
       diferente): faça o **swap**:
       1. `mkdir -p ./agentes/squads`
       2. Mova todos os arquivos `.md` de `./agentes/` (exceto
          `ORQUESTRADOR.md`, `CONTEXTO.md`, `TEAM.md` e o próprio diretório
          `squads/`) para uma nova pasta
          `./agentes/squads/<nome-do-squad-atual>/` — o nome do squad atual
          é inferido pela primeira linha de `./agentes/PIPELINE.md`: se for
          exatamente `# Pipeline de Desenvolvimento (ciclo completo)` (o
          squad de dev, caso mais comum de swap), use `dev`; senão, tente o
          padrão `# Pipeline de {Nome} (squad alternativo)` → `{nome}` em
          minúsculo (ex: `# Pipeline de Marketing (squad alternativo)` →
          `marketing`, batendo com o título real de
          `squads/marketing/PIPELINE.md` da Task 2); sem match conhecido,
          use `anterior-{YYYYMMDD-HHMMSS}`.
       3. Se `./agentes/CONTEXTO.md` ou `./agentes/TEAM.md` existirem, copie
          (não mova) para dentro dessa mesma pasta, pra preservar o estado
          do squad demovido.
       4. Copie `SQUAD_SOURCE` inteiro para `./agentes/`.
       5. `./agentes/CONTEXTO.md` e `./agentes/TEAM.md` do squad recém-ativo:
          se já existiam (de uma ativação anterior desse mesmo squad, salvos
          em algum `./agentes/squads/<nome>/`), restaure-os; senão, deixe
          ausentes (serão criados pelo scan automático — spec seção A).
     - Se `<nome>` já for o squad ativo: comporte-se como o passo "se já
       existir (caso de atualização) e a flag `--update` NÃO foi passada" —
       backup completo com timestamp — já existente, só que usando
       `SQUAD_SOURCE` como origem em vez do squad de dev.
   - **`--add-squad <nome>` (squad extra, não-ativo):**
     1. `mkdir -p ./agentes/squads/<nome>`
     2. Copie `SQUAD_SOURCE` inteiro para `./agentes/squads/<nome>/`.
     3. Não mexe no squad ativo nem em `./agentes/PIPELINE.md`.
   - Sem nenhuma das duas flags: comportamento atual, sem mudança
     (`TEMPLATE_DIR` continua `~/agentes-pipeline/agentes/`).
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash claude/skills/init-project/init-project-squad.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 5: Rodar a suíte existente do skill**

Run: `bash scripts/init-manifest-diff.test.sh`
Expected: `PASS` em tudo (esse script não foi tocado, confirma que o fluxo
de `--update` sem squad continua intacto).

- [ ] **Step 6: Commit**

```bash
git add claude/skills/init-project/SKILL.md claude/skills/init-project/init-project-squad.test.sh
git commit -m "feat: init-project ganha --squad e --add-squad pra instalar squads alternativos"
```

---

## Task 4: Comando `/squad`

**Files:**
- Create: `commands/squad.md`
- Modify: `commands/commands.test.sh`

**Interfaces:**
- Consumes: `agentes/ORQUESTRADOR.md` (Task 1, seções "Consulta a squads instalados" e mecânica de menu genérica), `agentes/squads/<nome>/PIPELINE.md` (produzido pela instalação da Task 3).

- [ ] **Step 1: Escrever o teste (falhando) — estender `commands/commands.test.sh`**

Adicione ao final de `commands/commands.test.sh`, antes do `exit $fail`:

```bash
check "$DIR/squad.md" '^argument-hint: \[nome do squad\] {pedido}' "squad.md tem argument-hint"
check "$DIR/squad.md" 'agentes/squads/' "squad.md referencia agentes/squads/"
check "$DIR/squad.md" 'agentes/ORQUESTRADOR.md' "squad.md referencia ORQUESTRADOR.md"
check "$DIR/squad.md" 'sem trocar o squad ativo' "squad.md deixa claro que não troca o squad ativo do projeto"
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash commands/commands.test.sh`
Expected: `FAIL: commands/squad.md não existe` (ou erro de arquivo ausente)
nas 4 novas checagens.

- [ ] **Step 3: Criar `commands/squad.md`**

```markdown
---
description: Roda uma sessão do Orquestrador escopada a um squad instalado (não necessariamente o ativo), sem trocar qual squad governa o projeto.
argument-hint: [nome do squad] {pedido}
---

Leia integralmente `agentes/ORQUESTRADOR.md` (persona e mecânica base,
compartilhada por todos os squads) e assuma a persona Orquestrador — mas
usando `agentes/squads/<nome>/PIPELINE.md` como fonte da tabela "Todos os
Agentes" e `agentes/squads/<nome>/*.md` como as personas disponíveis, em vez
de `agentes/PIPELINE.md` (squad ativo).

Primeiro argumento = nome do squad. Resto da frase = pedido:

$ARGUMENTS

Passos:
1. Se `agentes/squads/<nome>/` não existir, avise ao Bruno que esse squad
   não está instalado (`/init-project --add-squad <nome>` primeiro) e pare.
2. Se existir `agentes/squads/<nome>/CONTEXTO.md`, leia e use como pano de
   fundo (mesma regra de escopo do squad ativo: nunca leia o `CONTEXTO.md`
   de outro squad ou projeto).
3. Se existir `agentes/squads/<nome>/TEAM.md`, use como pré-seleção padrão
   do menu.
4. Siga a mecânica normal de montagem de menu e disparo de subagentes
   descrita em `ORQUESTRADOR.md`, usando as personas de
   `agentes/squads/<nome>/` em vez das do squad ativo.
5. **Sem trocar o squad ativo do projeto** — esta é uma sessão pontual,
   isolada; `agentes/PIPELINE.md`, `agentes/CONTEXTO.md` e `agentes/TEAM.md`
   do squad ativo não são lidos nem alterados por este comando.
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash commands/commands.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 5: Commit**

```bash
git add commands/squad.md commands/commands.test.sh
git commit -m "feat: adiciona /squad para consultar um squad instalado sem trocar o ativo"
```

---

## Task 5: Script `check-staleness.sh`

**Files:**
- Create: `agentes/scripts/check-staleness.sh`
- Create: `agentes/scripts/check-staleness.test.sh`

**Interfaces:**
- Produces: `check-staleness.sh <contexto-md-path> [threshold]` → imprime em stdout uma de `FRESH` | `STALE` | `NOT_APPLICABLE`. Exit code sempre 0 (nunca falha o comando chamador). Consumido pela Task 7 (`commands/orquestrador.md`).

- [ ] **Step 1: Escrever o teste (falhando)**

Crie `agentes/scripts/check-staleness.test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/check-staleness.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
fail=0

check_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — esperado '$expected', obtido '$actual'"
    fail=1
  fi
}

# --- Caso 1: sem .git -> NOT_APPLICABLE ---
mkdir -p "$FIXTURE/sem-git"
echo "- 2026-07-01 — init — resumo (HEAD: abc1234)" > "$FIXTURE/sem-git/CONTEXTO.md"
actual="$(bash "$TOOL" "$FIXTURE/sem-git/CONTEXTO.md")"
check_eq "$actual" "NOT_APPLICABLE" "sem .git no projeto -> NOT_APPLICABLE"

# --- Caso 2: com .git, CONTEXTO.md sem hash registrado -> NOT_APPLICABLE ---
mkdir -p "$FIXTURE/sem-hash"
git -C "$FIXTURE/sem-hash" init -q
git -C "$FIXTURE/sem-hash" -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "c1"
echo "- 2026-07-01 — init — resumo sem hash" > "$FIXTURE/sem-hash/CONTEXTO.md"
actual="$(bash "$TOOL" "$FIXTURE/sem-hash/CONTEXTO.md")"
check_eq "$actual" "NOT_APPLICABLE" "log sem hash de HEAD -> NOT_APPLICABLE"

# --- Caso 3: fresco (poucos commits desde o hash registrado) ---
mkdir -p "$FIXTURE/fresco"
git -C "$FIXTURE/fresco" init -q
git -C "$FIXTURE/fresco" -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "c1"
HASH1="$(git -C "$FIXTURE/fresco" rev-parse HEAD)"
echo "- 2026-07-01 — init — resumo (HEAD: $HASH1)" > "$FIXTURE/fresco/CONTEXTO.md"
for i in 1 2 3 4 5; do
  git -C "$FIXTURE/fresco" -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "c$i-extra"
done
actual="$(bash "$TOOL" "$FIXTURE/fresco/CONTEXTO.md" 15)"
check_eq "$actual" "FRESH" "5 commits desde o scan, limite 15 -> FRESH"

# --- Caso 4: desatualizado (mais commits que o limite) ---
mkdir -p "$FIXTURE/velho"
git -C "$FIXTURE/velho" init -q
git -C "$FIXTURE/velho" -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "c1"
HASH2="$(git -C "$FIXTURE/velho" rev-parse HEAD)"
echo "- 2026-07-01 — init — resumo (HEAD: $HASH2)" > "$FIXTURE/velho/CONTEXTO.md"
for i in $(seq 1 20); do
  git -C "$FIXTURE/velho" -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "c$i-extra"
done
actual="$(bash "$TOOL" "$FIXTURE/velho/CONTEXTO.md" 15)"
check_eq "$actual" "STALE" "20 commits desde o scan, limite 15 -> STALE"

# --- Caso 5: usa o hash MAIS RECENTE quando há múltiplas entradas ---
mkdir -p "$FIXTURE/multi"
git -C "$FIXTURE/multi" init -q
git -C "$FIXTURE/multi" -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "c1"
HASH_OLD="$(git -C "$FIXTURE/multi" rev-parse HEAD)"
for i in $(seq 1 20); do
  git -C "$FIXTURE/multi" -c user.email=t@t.com -c user.name=t commit --allow-empty -q -m "c$i-extra"
done
HASH_RECENTE="$(git -C "$FIXTURE/multi" rev-parse HEAD)"
{
  echo "- 2026-07-01 — init — scan antigo (HEAD: $HASH_OLD)"
  echo "- 2026-07-10 — pipeline — atualização (HEAD: $HASH_RECENTE)"
} > "$FIXTURE/multi/CONTEXTO.md"
actual="$(bash "$TOOL" "$FIXTURE/multi/CONTEXTO.md" 15)"
check_eq "$actual" "FRESH" "usa o hash da entrada mais recente (0 commits desde ela) -> FRESH"

# --- Caso 6: arquivo CONTEXTO.md ausente -> NOT_APPLICABLE ---
mkdir -p "$FIXTURE/ausente"
git -C "$FIXTURE/ausente" init -q
actual="$(bash "$TOOL" "$FIXTURE/ausente/CONTEXTO.md")"
check_eq "$actual" "NOT_APPLICABLE" "CONTEXTO.md ausente -> NOT_APPLICABLE"

exit $fail
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash agentes/scripts/check-staleness.test.sh`
Expected: falha logo no Caso 1 (`check-staleness.sh: arquivo não encontrado`
ou similar, já que o script ainda não existe).

- [ ] **Step 3: Implementar `agentes/scripts/check-staleness.sh`**

```bash
#!/usr/bin/env bash
# check-staleness.sh — detecta se um CONTEXTO.md está desatualizado,
# contando commits desde o hash de HEAD registrado na sua entrada mais
# recente do Log de atualizações (seção 7).
# Uso: check-staleness.sh <contexto-md-path> [threshold=15]
# Imprime exatamente uma linha: FRESH | STALE | NOT_APPLICABLE
# Exit code sempre 0 — quem chama decide o que fazer com a saída.
set -euo pipefail

CONTEXTO="${1:-}"
THRESHOLD="${2:-15}"

if [[ -z "$CONTEXTO" || ! -f "$CONTEXTO" ]]; then
  echo "NOT_APPLICABLE"
  exit 0
fi

PROJECT_DIR="$(cd "$(dirname "$CONTEXTO")" && pwd)"

# encontra a raiz do repo git subindo a partir do diretório do CONTEXTO.md
GIT_ROOT=""
dir="$PROJECT_DIR"
while [[ "$dir" != "/" ]]; do
  if [[ -e "$dir/.git" ]]; then
    GIT_ROOT="$dir"
    break
  fi
  dir="$(dirname "$dir")"
done

if [[ -z "$GIT_ROOT" ]]; then
  echo "NOT_APPLICABLE"
  exit 0
fi

# pega o hash da ÚLTIMA linha do log que tiver "(HEAD: <hash>)"
LAST_HASH="$(grep -oE '\(HEAD: [0-9a-f]+\)' "$CONTEXTO" | tail -1 | grep -oE '[0-9a-f]+' || true)"

if [[ -z "$LAST_HASH" ]]; then
  echo "NOT_APPLICABLE"
  exit 0
fi

if ! git -C "$GIT_ROOT" cat-file -e "${LAST_HASH}^{commit}" 2>/dev/null; then
  echo "NOT_APPLICABLE"
  exit 0
fi

COUNT="$(git -C "$GIT_ROOT" rev-list --count "${LAST_HASH}..HEAD" 2>/dev/null || echo 0)"

if [[ "$COUNT" -gt "$THRESHOLD" ]]; then
  echo "STALE"
else
  echo "FRESH"
fi
```

- [ ] **Step 4: Dar permissão de execução e rodar o teste**

Run: `chmod +x agentes/scripts/check-staleness.sh && bash agentes/scripts/check-staleness.test.sh`
Expected: todas as linhas `PASS`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add agentes/scripts/check-staleness.sh agentes/scripts/check-staleness.test.sh
git commit -m "feat: adiciona check-staleness.sh para detectar CONTEXTO.md desatualizado"
```

---

## Task 6: Hash de HEAD no Log de atualizações

**Files:**
- Modify: `agentes/PIPELINE.md`
- Modify: `commands/orquestrador-init.md`
- Test: `tests/orquestrador-generic.test.sh` (extend)

**Interfaces:**
- Produces: formato de linha de log `- YYYY-MM-DD — {origem} — {resumo} (HEAD: {hash})`, consumido por `check-staleness.sh` (Task 5, já implementado assumindo esse formato).

- [ ] **Step 1: Estender o teste (falhando)**

Adicione a `tests/orquestrador-generic.test.sh`, antes do `exit $fail`:

```bash
check_present "$DIR/agentes/PIPELINE.md" '(HEAD: ' \
  "PIPELINE.md documenta o formato de log com hash de HEAD"
check_present "$DIR/commands/orquestrador-init.md" 'git rev-parse --short HEAD' \
  "orquestrador-init.md grava o hash de HEAD ao escrever o log"
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash tests/orquestrador-generic.test.sh`
Expected: as duas novas checagens `FAIL`.

- [ ] **Step 3: Documentar o novo formato em `agentes/PIPELINE.md`**

Na seção `## Template de CONTEXTO.md`, no item 7 ("Log de atualizações —
data, o que mudou, origem"), substitua por:

```markdown
7. **Log de atualizações** — uma linha por atualização, formato
   `- YYYY-MM-DD — {origem} — {resumo} (HEAD: {hash curto do HEAD no
   momento do scan})`, origem sendo `init` ou `pipeline`. O hash existe pra
   permitir detecção automática de staleness (ver
   `agentes/scripts/check-staleness.sh`); entradas antigas sem hash
   continuam válidas, só não participam dessa checagem.
```

- [ ] **Step 4: Fazer `commands/orquestrador-init.md` gravar o hash**

No passo 2 de `commands/orquestrador-init.md` (a instrução de disparo do
subagente de scan), acrescente ao final do parágrafo existente:

```markdown
Ao registrar a linha nova na seção "Log de atualizações", inclua o hash
atual: rode `git rev-parse --short HEAD` dentro da subárvore do projeto (se
houver `.git`; se não houver, omita o `(HEAD: ...)` da linha) e formate como
`- {data de hoje} — init — {resumo} (HEAD: {hash})`.
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash tests/orquestrador-generic.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 6: Commit**

```bash
git add agentes/PIPELINE.md commands/orquestrador-init.md tests/orquestrador-generic.test.sh
git commit -m "feat: Log de atualizações passa a registrar hash de HEAD para detecção de staleness"
```

---

## Task 7: Disparo do scan/staleness em `/orquestrador` e `/squad`

**Files:**
- Modify: `commands/orquestrador.md`
- Modify: `commands/squad.md`
- Modify: `commands/commands.test.sh`

**Interfaces:**
- Consumes: `agentes/scripts/check-staleness.sh` (Task 5), mecânica de scan já existente em `commands/orquestrador-init.md`.

- [ ] **Step 1: Estender o teste (falhando)**

Adicione a `commands/commands.test.sh`, antes do `exit $fail`:

```bash
check "$DIR/orquestrador.md" 'check-staleness.sh' "orquestrador.md dispara a checagem de staleness"
check "$DIR/orquestrador.md" 'Não encontrei CONTEXTO.md' "orquestrador.md dispara scan quando CONTEXTO.md não existe"
check "$DIR/squad.md" 'check-staleness.sh' "squad.md dispara a checagem de staleness escopada ao squad"
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash commands/commands.test.sh`
Expected: as 3 novas checagens `FAIL`.

- [ ] **Step 3: Adicionar a checagem em `commands/orquestrador.md`**

Depois do bloco `Antes de apresentar o menu de etapas:` já existente,
acrescente:

```markdown
- Se `agentes/CONTEXTO.md` não existir: dispare automaticamente a mesma
  mecânica de scan de `/orquestrador-init` (subagente isolado, mesma lógica
  de fusão descrita lá), sem perguntar antes. Avise o Bruno no início da sua
  resposta: "Não encontrei CONTEXTO.md, gerei um antes de começar."
- Se existir: rode `agentes/scripts/check-staleness.sh agentes/CONTEXTO.md`.
  Se a saída for `STALE`, dispare o mesmo subagente de refresh (com fusão,
  nunca sobrescreve cego) antes de montar o menu. Se `NOT_APPLICABLE` ou
  `FRESH`, só leia o `CONTEXTO.md` normalmente.
```

- [ ] **Step 4: Adicionar a checagem em `commands/squad.md`**

No passo 2 já existente ("Se existir `agentes/squads/<nome>/CONTEXTO.md`,
leia..."), substitua por:

```markdown
2. Se `agentes/squads/<nome>/CONTEXTO.md` não existir: dispare o mesmo
   fluxo de scan automático descrito em `orquestrador.md`, escopado à
   subárvore deste squad (escreve em
   `agentes/squads/<nome>/CONTEXTO.md`, nunca no `CONTEXTO.md` do squad
   ativo ou de outro squad). Senão, rode
   `agentes/scripts/check-staleness.sh agentes/squads/<nome>/CONTEXTO.md` e,
   se `STALE`, dispare o refresh antes de seguir — mesma lógica de
   `orquestrador.md`, só que escopada a este squad.
```

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash commands/commands.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 6: Commit**

```bash
git add commands/orquestrador.md commands/squad.md commands/commands.test.sh
git commit -m "feat: /orquestrador e /squad disparam scan automático e refresh por staleness"
```

---

## Task 8: Regra de compactação em `ORQUESTRADOR.md`

**Files:**
- Modify: `agentes/ORQUESTRADOR.md`
- Test: `tests/orquestrador-generic.test.sh` (extend)

**Interfaces:**
- Produces: seção `## Compactação automática de CONTEXTO.md` em `agentes/ORQUESTRADOR.md`, referenciada pela Task 9.

- [ ] **Step 1: Estender o teste (falhando)**

Adicione a `tests/orquestrador-generic.test.sh`, antes do `exit $fail`:

```bash
check_present "$DIR/agentes/ORQUESTRADOR.md" '## Compactação automática de CONTEXTO.md' \
  "ORQUESTRADOR.md documenta a regra de compactação"
check_present "$DIR/agentes/ORQUESTRADOR.md" 'CONTEXTO.md.bak' \
  "ORQUESTRADOR.md documenta o backup .bak"
check_present "$DIR/agentes/ORQUESTRADOR.md" 'sem perder nenhuma informação necessária' \
  "ORQUESTRADOR.md documenta o mandato do subagente de compactação"
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash tests/orquestrador-generic.test.sh`
Expected: as 3 novas checagens `FAIL`.

- [ ] **Step 3: Adicionar a seção em `agentes/ORQUESTRADOR.md`**

Logo depois da seção `## Consulta a squads instalados` (adicionada na
Task 1), acrescente:

```markdown
## Compactação automática de CONTEXTO.md

Se o `CONTEXTO.md` relevante (do squad ativo, ou de um squad consultado via
`/squad`) passar de 200 linhas, dispare a compactação antes de prosseguir
para o menu.

Dispare um subagente dedicado (`subagent_type: general-purpose`) com este
mandato exato: "condense este CONTEXTO.md sem perder nenhuma informação
necessária para que uma sessão futura retome o trabalho de onde parou."

O que o subagente deve condensar:
- **Seções 1-6** (Visão geral, Arquitetura, Convenções, Decisões,
  Integrações, Gotchas) — corta verbosidade e redundância acumulada, mas
  preserva todo fato, decisão e nome próprio citado. Edição de estilo, não
  resumo com perda.
- **Seção 7 (Log de atualizações)** — entradas mais antigas que as últimas
  10 sessões são condensadas num único parágrafo "Resumo histórico" no topo
  da seção; as 10 mais recentes continuam linha a linha, granulares
  (inclusive com o hash de HEAD, quando presente).

Escrita automática, sem perguntar ao Bruno — compactação não decide
conteúdo novo, só condensa o que já foi aprovado. Antes de sobrescrever,
salve a versão anterior como `CONTEXTO.md.bak` (mesmo diretório,
sobrescrevendo o backup anterior). Ao final, avise em uma linha: "Compactei
o CONTEXTO.md (de X para Y linhas), backup em CONTEXTO.md.bak."
```

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `bash tests/orquestrador-generic.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 5: Commit**

```bash
git add agentes/ORQUESTRADOR.md tests/orquestrador-generic.test.sh
git commit -m "feat: documenta compactação automática de CONTEXTO.md por tamanho"
```

---

## Task 9: Disparo da checagem de tamanho em `/orquestrador` e `/squad`

**Files:**
- Modify: `commands/orquestrador.md`
- Modify: `commands/squad.md`
- Modify: `commands/commands.test.sh`

**Interfaces:**
- Consumes: seção "Compactação automática de CONTEXTO.md" de `agentes/ORQUESTRADOR.md` (Task 8).

- [ ] **Step 1: Estender o teste (falhando)**

Adicione a `commands/commands.test.sh`, antes do `exit $fail`:

```bash
check "$DIR/orquestrador.md" 'wc -l' "orquestrador.md checa o tamanho do CONTEXTO.md"
check "$DIR/orquestrador.md" 'Compactação automática' "orquestrador.md referencia a regra de compactação"
check "$DIR/squad.md" 'wc -l' "squad.md checa o tamanho do CONTEXTO.md do squad"
```

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `bash commands/commands.test.sh`
Expected: as 3 novas checagens `FAIL`.

- [ ] **Step 3: Adicionar a checagem em `commands/orquestrador.md`**

Depois do bloco de staleness adicionado na Task 7, acrescente:

```markdown
- Depois de garantir que `agentes/CONTEXTO.md` está atualizado: rode
  `wc -l < agentes/CONTEXTO.md` (0 se o arquivo não existir). Se passar de
  200 linhas, siga a seção "Compactação automática de CONTEXTO.md" de
  `ORQUESTRADOR.md` antes de montar o menu.
```

- [ ] **Step 4: Adicionar a checagem em `commands/squad.md`**

Depois do bloco de staleness adicionado na Task 7, acrescente:

```markdown
3. Depois de garantir que `agentes/squads/<nome>/CONTEXTO.md` está
   atualizado: rode `wc -l < agentes/squads/<nome>/CONTEXTO.md` (0 se
   ausente). Se passar de 200 linhas, siga a seção "Compactação automática
   de CONTEXTO.md" de `ORQUESTRADOR.md`, escopada a este arquivo.
```

(Renumere os passos seguintes de `squad.md` de acordo.)

- [ ] **Step 5: Rodar o teste e confirmar que passa**

Run: `bash commands/commands.test.sh`
Expected: todas as linhas `PASS`.

- [ ] **Step 6: Rodar toda a suíte de testes do repo pra fechar a entrega**

Run:
```bash
bash commands/commands.test.sh
bash commands/orquestrador-init-merge.test.sh
bash tests/detect-projects.test.sh
bash tests/orquestrador-generic.test.sh
bash tests/squad-marketing.test.sh
bash scripts/init-manifest-diff.test.sh
bash claude/skills/init-project/init-project-squad.test.sh
bash agentes/scripts/check-staleness.test.sh
```
Expected: `PASS` em tudo, nenhum `FAIL`.

- [ ] **Step 7: Commit**

```bash
git add commands/orquestrador.md commands/squad.md commands/commands.test.sh
git commit -m "feat: /orquestrador e /squad disparam compactação automática de CONTEXTO.md por tamanho"
```

---

## Task 10: Documentação (README.md, AGENTS.md)

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Nenhuma (task de documentação, sem interface consumida por outra task).

- [ ] **Step 1: Atualizar `README.md`**

Na seção `## Estrutura`, depois do bloco que lista `gemini/`, acrescente:

```markdown
├── squads/                 ← squads alternativos (ex: marketing), instaláveis
│   └── marketing/           lado a lado com o squad de dev via /init-project --squad|--add-squad
```

Depois da seção `## Sincronizar em outra máquina`, adicione uma seção nova:

```markdown
## Squads alternativos, scan automático e compactação de contexto

- **Squads alternativos:** além do squad de dev (padrão), o repo traz um
  squad de marketing em `squads/marketing/`. Instale como squad ativo do
  projeto com `/init-project --squad marketing`, ou como squad extra
  (consultável, sem trocar o ativo) com `/init-project --add-squad marketing`.
  Qualquer persona do squad ativo pode consultar um squad instalado como
  extra a qualquer momento; pra consultar diretamente sem estar no meio de
  um pipeline, use `/squad marketing {pedido}`.
- **Scan automático de codebase:** `/orquestrador` gera `agentes/CONTEXTO.md`
  sozinho na primeira vez (sem precisar rodar `/orquestrador-init` manual) e
  o atualiza automaticamente quando detecta mais de 15 commits desde o
  último scan.
- **Compactação automática de contexto:** quando `agentes/CONTEXTO.md`
  passa de 200 linhas, o Orquestrador o compacta sozinho (preservando tudo
  que uma sessão futura precisa pra continuar o trabalho) antes de cada
  sessão, com backup automático em `CONTEXTO.md.bak`.
```

- [ ] **Step 2: Atualizar `AGENTS.md`**

Depois do item 5 da seção "Se você está num projeto com `./agentes/`
instalado a partir daqui", acrescente:

```markdown
6. Squads alternativos (ex: marketing) podem estar instalados em
   `agentes/squads/<nome>/`, sem serem o squad ativo — qualquer etapa pode
   consultá-los como opinião pontual, e `/squad <nome> {pedido}` roda uma
   sessão inteira escopada a um deles sem trocar o squad ativo do projeto.
7. `agentes/CONTEXTO.md` se atualiza e se compacta sozinho quando
   necessário (scan automático por staleness, compactação automática por
   tamanho) — não é preciso rodar `/orquestrador-init` manualmente na
   maioria dos casos, só quando quiser forçar um refresh imediato.
```

- [ ] **Step 3: Rodar a suíte completa uma última vez**

Run: (mesmo bloco de comandos do Step 6 da Task 9)
Expected: `PASS` em tudo.

- [ ] **Step 4: Commit**

```bash
git add README.md AGENTS.md
git commit -m "docs: documenta squads alternativos, scan automático e compactação de contexto"
```
