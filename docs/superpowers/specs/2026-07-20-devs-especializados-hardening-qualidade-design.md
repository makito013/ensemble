# Devs especializados por domínio + hardening de Revisor/QA

Data: 2026-07-20
Repositório: `agentes-pipeline`

## Problema

Feats recentes saíram com "código de junior": bugs/lógica errada que passou
batido, código feio mas funcional (nomes ruins, duplicação, funções
gigantes) e decisões estruturais ruins (padrões do projeto ignorados,
acoplamento errado). Isso aconteceu mesmo em sessões com o pipeline completo
ativo — QA e Revisor rodando —, então não é falta de etapa.

Investigando a causa raiz em `agentes/REVISOR.md`: os critérios de aprovação
já classificam "code smell" e "cobertura abaixo do ideal" como ⚠️ ressalva
— não como bloqueio. Ou seja, mesmo quando o Revisor encontra o problema, a
própria régua do agente permite aprovar do mesmo jeito. Isso explica os três
sintomas relatados: a régua de aprovação é frouxa demais pra code smell
estrutural, e não existe nenhuma exigência de evidência real (rodar
lint/teste de fato) antes de declarar algo "concluído".

Motivação inicial: o Bruno usou o Compozy (compozy.com), que orquestra 40+
agentes especializados por domínio num pipeline PRD→TechSpec→Tasks→Execution,
e quis avaliar trazer esse conceito de especialização para o pipeline atual
de 11 personas. Decisão tomada durante o brainstorm: especializar o Dev por
domínio (não replicar o Compozy inteiro — ver seção "Fora de escopo").

## Mudança

### A. Etapa 7 (Dev) passa a ter 3 personas em vez de 1

- `agentes/DEV-BACKEND.md` (novo) e `agentes/DEV-FRONTEND.md` (novo) —
  personas especializadas.
- `agentes/DEV.md` (existente) **permanece como fallback** para tarefas que
  não são claramente backend nem frontend (infra, CLI, scripts, docs-as-code,
  ou algo ambíguo). Nada é forçado numa caixa que não serve.
- O Orquestrador infere o domínio a partir do que Analista/Arquiteto já
  produziram (ex: "cria endpoint X" → backend; "tela Y consome Z" →
  frontend; ambos → os dois) e mostra a detecção no mesmo menu que já
  apresenta hoje: `[x] 7. DESENVOLVIMENTO — Dev-Backend + Dev-Frontend
  (detectado)`. O Bruno pode corrigir ali mesmo, sem fluxo de pergunta novo.
- Quando a feature toca os dois domínios: disparo **sequencial** — Dev-Backend
  primeiro, Dev-Frontend depois recebendo o output do backend como contexto
  (contrato de API já decidido). Evita o frontend assumir um contrato que o
  backend ainda não fechou, e evita conflito de edição simultânea nos mesmos
  arquivos.
- A numeração do pipeline (1-10) não muda — a especialização é um detalhe de
  *como* a etapa 7 executa, não uma etapa nova. `TEAM.md` e os perfis rápidos
  (`[P]`, `[F]`, etc.) continuam funcionando sem alteração estrutural.
- Mecânica de disparo continua igual: `Agent`/`Task`,
  `subagent_type: general-purpose`, só troca qual arquivo de persona é
  injetado no prompt.

### B. Conteúdo dos dois Devs especializados

Ambos herdam a estrutura do `DEV.md` atual (mesma missão geral, mesmo
formato de entrega, mesma regra "Quando o plano está errado"). Cada um ganha
um checklist extra de senioridade específico do domínio, que vira parte
obrigatória do "O que você entrega":

**`DEV-BACKEND.md`** (tag `[DEV-BACKEND]`):
- Tratamento de erro por camada (nunca expõe stack trace/detalhe interno pro
  cliente; distingue erro de cliente vs. servidor)
- Validação e sanitização de toda entrada externa
- Idempotência/concorrência em operações que podem repetir ou rodar em
  paralelo (locks, chave única, transação)
- Autorização checada explicitamente (autenticado ≠ autorizado)
- Evita N+1 e queries redundantes em loop
- Contrato de API definido/documentado antes da implementação, breaking
  changes sinalizados

**`DEV-FRONTEND.md`** (tag `[DEV-FRONTEND]`):
- Todos os estados de UI tratados: loading, erro, vazio, sucesso (não só o
  caminho feliz)
- Erros de API tratados explicitamente, nunca assume que a chamada sempre
  funciona
- Feedback em ações assíncronas (evita duplo-clique gerar duas submissões)
- Acessibilidade básica (labels, navegação por teclado, contraste) quando
  aplicável ao projeto
- Estado sem duplicação/dessincronização, efeitos colaterais explícitos
- Segue padrões visuais do projeto / output do Designer, se essa etapa
  estiver ativa

### C. Princípios de código sênior (compartilhado entre DEV.md, DEV-BACKEND.md, DEV-FRONTEND.md)

Bloco novo, igual nos três arquivos:
- Nomes revelam intenção; funções pequenas, uma responsabilidade cada
- Sem redundância: lógica repetida vira função/módulo comum — mas sem
  abstração especulativa pra caso hipotético (YAGNI)
- Sem código morto, sem comentário explicando o óbvio, direto ao ponto
- Roda o linter/formatter configurado no projeto (eslint, ou o que o
  `CONTEXTO.md`/config do projeto indicar) antes de declarar concluído, e
  corrige os apontamentos — não só o que quebra o build
- Relatório de entrega ganha uma linha obrigatória: **"Lint: X erros, Y
  warnings"** (ou "sem linter configurado no projeto" — nunca omitida)

### D. Hardening de `REVISOR.md` e `QA.md`

**`REVISOR.md`** — critérios de aprovação reescritos:

Bloqueadores (❌ reprova), adicionando aos 3 que já existem (requisito
obrigatório não implementado / bug crítico / violação grave de arquitetura):
- Relatório de lint do Dev ausente, ou o Revisor roda o lint e encontra
  erro/warning não reportado (evidência falsa = reprovação automática, não
  ressalva)
- Code smell **estrutural**: duplicação de lógica de negócio, função com
  responsabilidades misturadas, tratamento de erro ausente/genérico em fluxo
  crítico, nome que esconde o comportamento real da função

Ressalvas (⚠️, não bloqueia) — fica mais estreito, só cosmético:
- Nome subótimo em ponto não crítico, formatação sem impacto funcional, TODO
  documentado e justificado, cobertura parcial em código não crítico

Nova seção no relatório do Revisor: **"Verificação independente"** — o
Revisor roda ele mesmo o lint/teste do projeto (não confia só no que o Dev
reportou) e registra se bateu com o que foi declarado.

**`QA.md`** — um critério de reprovação a mais, além dos 3 existentes (bug
crítico / cobertura <80% / BDD P0 falhou):
- Caso de borda que o TL classificou como crítico na "Estratégia de testes"
  ficou sem cobertura (hoje isso só aparecia como "risco" anotado, sem
  travar nada)

### Replicação dual-formato (Claude + Antigravity)

O repo mantém duas cópias sincronizadas — `agentes/*.md` (Claude) e
`gemini/skills/*/SKILL.md` (Antigravity) — garantidas por
`tests/gemini-orquestrador-paridade.test.sh` e `tests/gemini-skills.test.sh`.
Toda mudança acima precisa ser espelhada:

- Novos: `gemini/skills/dev-backend/SKILL.md`, `gemini/skills/dev-frontend/SKILL.md`
- Modificados: `gemini/skills/dev/SKILL.md`, `gemini/skills/revisor/SKILL.md`,
  `gemini/skills/qa/SKILL.md`, `gemini/skills/orquestrador/SKILL.md`
- `agentes/PIPELINE.md`: tabela de agentes atualizada — etapa 7 passa a
  listar os 3 arquivos de Dev
- `README.md`: as duas listas de estrutura de pastas ganham as entradas novas
- `tests/gemini-orquestrador-paridade.test.sh`: ganha um `check` novo para a
  frase-chave da lógica de detecção de domínio
- `tests/gemini-skills.test.sh`: precisa ser lido durante a implementação
  para confirmar que os 2 arquivos novos satisfazem o pareamento
  `agentes/*.md` ↔ `gemini/skills/*/SKILL.md` que ele garante

## Fora de escopo

- **Agente `VERIFICADOR.md` dedicado** (equivalente ao `cy-final-verify` do
  Compozy) — avaliado durante o brainstorm e descartado a favor de embutir a
  exigência de evidência (linha de lint obrigatória + verificação
  independente do Revisor) dentro dos agentes existentes, sem criar etapa
  nova.
- **Terceiro domínio de Dev (Infra/DevOps)** — só Backend e Frontend por
  agora; infra cai no fallback `DEV.md` genérico.
- **Roteamento multi-provider** (Claude, Codex, Gemini, Ollama no mesmo
  pipeline) — discutido antes do brainstorm como diferença estrutural do
  Compozy, mas não faz parte deste design; o pipeline continua rodando
  inteiramente dentro de uma ferramenta host por vez.
- Qualquer instalação/uso do Compozy em si — foi desinstalado da máquina do
  Bruno durante esta sessão (binário, cask e tap via Homebrew).

## Teste manual

Depois de aplicado:
1. Rodar `/orquestrador` com uma tarefa claramente backend (ex: "criar
   endpoint de X") e confirmar que o menu detecta e sugere só Dev-Backend.
2. Rodar com uma tarefa full-stack (ex: "endpoint novo + tela que o
   consome") e confirmar disparo sequencial: Dev-Backend conclui, Dev-Frontend
   recebe o contrato definido como contexto.
3. Confirmar que o relatório de ambos os Devs tem a linha "Lint: ..." sempre
   presente.
4. Forçar um code smell estrutural proposital (ex: função com 3
   responsabilidades misturadas) e confirmar que o Revisor bloqueia
   (❌ reprovado), não aprova com ressalva.
5. Rodar `tests/gemini-orquestrador-paridade.test.sh` e
   `tests/gemini-skills.test.sh` e confirmar que passam com os arquivos
   novos/modificados.
