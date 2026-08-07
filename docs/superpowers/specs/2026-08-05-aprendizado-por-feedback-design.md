# Aprendizado por Feedback + Despoluição de Personas + Teto de Convergência

Data: 2026-08-05
Repositório: `agentes-pipeline` (fonte dos templates `agentes/`, `commands/` e `gemini/skills/`)

## Objetivo

Bruno observou que os agentes do pipeline ainda liberam tarefas com problema,
e levantou duas hipóteses: mais validação (idas e vindas) ou limpeza de
contexto longo. Investigação prévia (ver conversa que originou este spec)
encontrou:

1. **Correções que Bruno faz durante uma sessão evaporam.** Se ele diz "isso
   está errado, sempre faça X" no meio de um pipeline, isso vive só na
   conversa daquela sessão — na próxima vez que o mesmo agente rodar (mesmo
   projeto, ou projeto novo), o erro se repete, porque a persona (`agentes/*.md`)
   nunca é atualizada com o que foi aprendido.
2. **Contaminação real de contexto nas próprias personas.** `ARQUITETO.md`,
   `TL.md`, `PO.md` e `DESIGNER.md` têm seções hardcoded com o modelo mental
   de um projeto anterior específico (tablet/iPad, PTY, escritório
   isométrico) — isso primeia todo Arquiteto/TL disparado em **qualquer**
   projeto novo com um contexto errado. O lado `gemini/skills/` já está limpo
   disso; só o lado Claude ficou pra trás.
3. **Loops de reprovação sem teto.** `ORQUESTRADOR.md` descreve o ciclo
   "Revisor/QA reprova → Dev refaz" sem limite de voltas nem critério de
   quando escalar pro Bruno em vez de tentar de novo.

Este spec cobre três mecanismos relacionados mas independentes entre si:

- **A. Despoluição de personas** — remove o resíduo de projeto anterior,
  com teste negativo pra não regredir.
- **B. Teto de convergência** — limite de voltas nos loops de
  reprovação + regra anti-oscilação.
- **C. Aprendizado por feedback** — mecanismo novo: no fim da sessão, o
  Orquestrador lista as regras de comportamento que identificou terem sido
  decididas por Bruno durante o pipeline, e para cada uma pergunta se grava
  como regra **local** (só este projeto) ou **global** (fila pendente até
  ser sincronizada com o repo-fonte).

**Fora de escopo:** evidência executável (exigir comando+exit code em vez de
opinião do LLM) e verificação adversarial em paralelo — duas abordagens
adicionais identificadas na mesma investigação, tratadas como specs
futuras, a serem avaliadas depois que os mecanismos deste spec estiverem
rodando por um tempo. Também fora de escopo: terminar a implementação dos
planos `2026-07-20` (hardening Revisor/QA) e `2026-07-15`
(squads/compactação) — já escritos, nunca executados, mas é dívida
separada, não parte deste desenho.

---

## A. Despoluição de personas

### O que remove

| Arquivo | Seções removidas |
|---|---|
| `agentes/ARQUITETO.md` | `## Modelo Mental do Sistema` (Tablet/Gateway/PTY) e `## Contexto do Projeto` (escritório isométrico) |
| `agentes/TL.md` | Perguntas-chave específicas de iPad/Safari Mobile/PTY via SSH reverso, e o `## Contexto do Projeto` correspondente |
| `agentes/PO.md` | Menções a "o Bruno no tablet, na rua" e o `## Contexto do Projeto` (Escritório Virtual) |
| `agentes/DESIGNER.md` | iPad, isométrico, Habbo Hotel, landscape vs portrait |

Onde a seção removida tinha uma função legítima (dar ao agente contexto do
projeto atual), a instrução passa a apontar para `agentes/CONTEXTO.md` — que
já existe, é por projeto, e é atualizado pelo próprio scan/pipeline. Nenhuma
persona volta a ter contexto de projeto **fixo no arquivo**.

O lado `gemini/skills/{arquiteto,tl,po,designer}/SKILL.md` já está limpo
dessas seções — serve de referência direta do texto final esperado do lado
Claude, não precisa ser reescrito do zero.

### Teste de regressão

Novo `tests/personas-sem-contexto-fixo.test.sh`, com uma função
`check_absent()` (inversa da `check()` já usada no repo): falha se qualquer
um destes termos aparecer em qualquer `agentes/*.md` — `Contexto do Projeto`,
`Modelo Mental do Sistema`, `iPad`, `PTY`, `isométrico`, `Habbo`. Isso é o
que impede a próxima edição de reintroduzir o mesmo tipo de resíduo.

---

## B. Teto de convergência dos loops de reprovação

### Regras novas em `agentes/ORQUESTRADOR.md`

- **Máximo 2 voltas por fase** (contando: 1ª tentativa reprovada + 1
  retrabalho). Se a 2ª tentativa também for reprovada, o Orquestrador **não**
  dispara uma 3ª automaticamente — apresenta a Bruno: o que ainda falha, o
  que mudou entre as duas tentativas, e uma hipótese de por que não converge
  (critério ambíguo, especificação incompleta, ou implementação
  genuinamente errada). Bruno decide: tentar de novo com orientação extra,
  ajustar o critério, ou aceitar como está.
- **Regra anti-oscilação:** se a reprovação da 2ª tentativa cita o **mesmo
  motivo** da 1ª (ainda que o Dev alegue ter corrigido), o Orquestrador
  escala imediatamente em vez de contar como "só mais uma volta" — é sinal
  de critério mal especificado, não de implementação ruim, e insistir só
  gasta uma volta a mais no mesmo impasse.
- **Contagem registrada por fase no `PIPELINE-STATE.md`:** quantas voltas
  aconteceram e qual gate (QA ou Revisor) identificou o problema em cada
  uma. Isso não muda o comportamento do pipeline, mas cria o dado que falta
  hoje pra decidir, depois de um tempo de uso, se vale a pena investir nas
  abordagens fora de escopo (evidência executável / verificação
  adversarial).

### Sinergia com o mecanismo C

Uma escalada por "mesmo motivo repetido" é candidata natural a virar regra
de aprendizado (seção C): geralmente expõe uma instrução que faltava na
persona, não um erro pontual do Dev. O Orquestrador, ao escalar por
anti-oscilação, já anota essa ocorrência como candidata a "regra
identificada" para o resumo de fim de sessão — não é um mecanismo à parte,
é o mesmo detector da seção C reagindo a mais um tipo de sinal.

---

## C. Aprendizado por feedback

### C.1 Detecção de regra candidata (durante a sessão)

O Orquestrador é quem conversa com Bruno ao vivo — os subagentes de cada
etapa são isolados e não veem a conversa diretamente (`ORQUESTRADOR.md`,
mecânica de disparo). Então a detecção é responsabilidade do Orquestrador,
rodando em paralelo ao mecanismo já existente de "Atualização de contexto
sugerida" (que continua servindo só para fatos do projeto, indo para
`CONTEXTO.md` — nada muda ali).

Sempre que a fala de Bruno tiver um padrão de correção comportamental
dirigida a uma etapa/agente — "sempre faça X", "nunca faça Y", "da próxima
vez...", "isso está errado, deveria...", ou uma escalada por anti-oscilação
(seção B) — o Orquestrador registra em memória (não grava nada ainda):

- o texto da regra, em forma imperativa e reutilizável (ex: "Sempre
  responder em inglês nos relatórios de entrega");
- qual persona ela afeta (`DEV-FRONTEND.md`, `REVISOR.md`, etc.);
- o gatilho (correção explícita vs. escalada por anti-oscilação).

Falsos positivos aqui são aceitáveis e esperados — nada é gravado sem
confirmação explícita, regra a regra, no fechamento da sessão (C.2). O
detector erra para o lado de "propor demais", nunca "gravar sem perguntar".

### C.2 Apresentação e decisão no fim da sessão

No resumo final que o Orquestrador já apresenta hoje, se houver pelo menos
uma regra candidata, ele lista todas juntas:

> *"Identifiquei estas regras que você decidiu seguir nesta sessão:*
> *1. Sempre responder em inglês nos relatórios do Dev-Frontend (persona:
> DEV-FRONTEND.md)*
> *2. Revisor sempre conferir X antes de aprovar (persona: REVISOR.md)*
> *Para cada uma: gravar como regra local deste projeto, gravar como
> pendência global (revisão no repo-fonte antes de valer pra outros
> projetos), ou ignorar?"*

Bruno responde regra a regra (ex: "1: global, 2: local"). Se nenhuma regra
foi identificada na sessão, este bloco não aparece — sem ruído.

### C.3 Escrita local

Regra marcada "local" é adicionada a uma seção fixa `## Aprendizados` no(s)
arquivo(s) de persona **instalados naquele projeto** — sempre em `.agents/`
(pasta oculta, é onde o `/init-project` instala hoje, não `agentes/` visível,
que é só o nome da pasta de templates no repo-fonte): `.agents/<PERSONA>.md`
e, se existir, `.agents/skills/<persona>/SKILL.md` (mesma regra, adaptada à
convenção de cada lado — sem a linha-ponteiro no lado Gemini, como já é o
padrão).

Formato:

```markdown
## Aprendizados
- 2026-08-05: Sempre responder em inglês nos relatórios de entrega.
```

Posicionamento: a seção é inserida **antes** da linha final
`` Ver "Subagentes e escolha de modelo" em `.agents/PIPELINE.md`. `` — nunca
depois — para não quebrar o teste existente (`tests/subagentes-modelo.test.sh`)
que exige essa linha como a última do arquivo. Se a seção `## Aprendizados`
ainda não existir no arquivo, é criada nesse ponto; se já existir, a regra é
só mais um bullet datado.

### C.4 Fila de pendências global

Regra marcada "global" é adicionada a um arquivo novo, local ao projeto
onde a sessão rodou: `.agents/.aprendizados-globais-pendentes.md`, agrupado
por persona-alvo:

```markdown
## DEV-FRONTEND.md
- 2026-08-05 (projeto: nome-do-projeto): Sempre responder em inglês nos
  relatórios de entrega.

## REVISOR.md
- 2026-08-05 (projeto: nome-do-projeto): ...
```

Esse arquivo é dado de projeto (mesma categoria de `CONTEXTO.md`/
`PIPELINE-STATE.md`) — nunca tocado pelo instalador, nem no fluxo normal nem
no `--update`.

### C.5 Sincronização com o repo-fonte

Novo comando `.claude/commands/aprendizados-sync.md` (`/aprendizados-sync
<caminho-do-projeto>`) — **local a este repo-fonte, fora de `commands/`**.
`commands/*.md` é copiado por inteiro para `.claude/commands/` de todo
projeto instalado (confirmado em `claude/skills/init-project/SKILL.md`, sem
filtro de nome) — colocar o comando ali faria ele aparecer, sem sentido, em
qualquer projeto. Como este comando só faz sentido rodando aqui no
repo-fonte (`agentes-pipeline`), ele vive direto em `.claude/commands/`
deste repo, nunca em `commands/`, e por isso nunca é distribuído:

1. Lê `<caminho-do-projeto>/.agents/.aprendizados-globais-pendentes.md`.
2. Apresenta cada regra pendente a Bruno, uma de cada vez, com a persona
   alvo — ele pode aprovar como está, editar o texto, ou descartar.
3. Regra aprovada é aplicada em `agentes/<PERSONA>.md` (fonte) na mesma
   seção `## Aprendizados` (C.3), e espelhada em
   `gemini/skills/<persona>/SKILL.md`.
4. Depois de processadas todas as regras do arquivo, ele é limpo (as
   entradas aplicadas são removidas; se alguma foi descartada, também sai da
   fila — decisão final, não fica reaparecendo).
5. Se o arquivo não existir ou estiver vazio, o comando informa e não faz
   nada.

Formato do argumento posicional (`$ARGUMENTS`) segue a mesma convenção de
`commands/orquestrador-init.md`. **Sem espelho Antigravity nesta versão** —
é uma ferramenta de manutenção do repo-fonte operada por Bruno diretamente
em Claude Code; o mecanismo que precisa rodar em qualquer sessão (detecção +
decisão, C.1/C.2) já é espelhado no `gemini/skills/orquestrador/SKILL.md`
normalmente. Se no futuro Bruno operar o repo-fonte também via Antigravity,
um espelho pode ser adicionado então (YAGNI por ora).

### Por que fila local + sync manual, e não escrita direta cross-repo

Uma sessão de Orquestrador rodando dentro de outro projeto não tem acesso
de escopo ao repo-fonte (`agentes-pipeline` pode nem estar no mesmo disco).
Gravar direto exigiria a sessão abrir um segundo diretório na mesma
conversa — mudança de mecânica de execução que este spec evita
propositalmente (mesma razão pela qual squads/compactação, spec de
2026-07-15, também não mexe na arquitetura de disparo de subagentes). A
fila local + comando de sync dedicado mantém cada sessão escopada a um
único projeto, e concentra toda escrita no repo-fonte no momento em que
Bruno já está com atenção nisso (rodando o sync), não no meio de outra
tarefa.

---

## D. Arquivos alterados

**Novos:**
- `tests/personas-sem-contexto-fixo.test.sh`
- `.claude/commands/aprendizados-sync.md` (local a este repo, não distribuído)
- `tests/aprendizado-feedback.test.sh`
- `tests/teto-convergencia.test.sh`

**Modificados:**
- `agentes/ARQUITETO.md`, `agentes/TL.md`, `agentes/PO.md`, `agentes/DESIGNER.md` — remoção das seções contaminadas (seção A)
- `agentes/ORQUESTRADOR.md` — teto de convergência + regra anti-oscilação (seção B); detecção de regra candidata + bloco de decisão no resumo final (seção C.1/C.2)
- `agentes/PIPELINE.md` — documenta contagem de voltas por fase no formato do `.agents/PIPELINE-STATE.md` (o formato é descrito aqui, o arquivo em si é dado de projeto instalado, não arquivo fixo do repo); documenta a seção `## Aprendizados` como convenção de arquivo de persona
- Espelhos correspondentes em `gemini/skills/{orquestrador,arquiteto,tl,po,designer}/SKILL.md`
- `README.md` — documenta `/aprendizados-sync`, a seção `## Aprendizados` nas personas, e o teto de convergência
- `claude/skills/init-project/SKILL.md` — adiciona `.agents/.aprendizados-globais-pendentes.md` à lista de dado de projeto nunca tocado pelo instalador

---

## E. Testes

Seguindo o padrão do repo (`tests/*.test.sh`, `check()`/`check_absent()` com
grep, sem framework dedicado):

- `tests/personas-sem-contexto-fixo.test.sh` — `check_absent()` para os
  termos listados na seção A, nos 4 arquivos afetados (e, por segurança,
  varrendo todo `agentes/*.md`).
- `tests/teto-convergencia.test.sh` — `ORQUESTRADOR.md` documenta o limite
  de 2 voltas, a regra anti-oscilação e o campo de contagem no formato do
  `PIPELINE-STATE.md`.
- `tests/aprendizado-feedback.test.sh` — `ORQUESTRADOR.md` documenta a
  detecção de regra candidata e o bloco de decisão no resumo final;
  `commands/aprendizados-sync.md` e seu espelho existem com o conteúdo
  esperado; `agentes/PIPELINE.md` documenta a seção `## Aprendizados` como
  convenção.
- Reaproveitar o padrão de `tests/gemini-orquestrador-paridade.test.sh` para
  garantir paridade do novo comando entre os dois lados.

---

## Ordem de implementação

1. Seção A (despoluição de personas) — independente das outras duas, zero
   risco, maior ganho imediato de qualidade de contexto.
2. Seção B (teto de convergência) — mudança isolada em `ORQUESTRADOR.md` +
   formato do `PIPELINE-STATE.md`.
3. Seção C (aprendizado por feedback) — depende conceitualmente de B (a
   sinergia de anti-oscilação alimentando candidatas), então vem depois:
   3.1. Detecção + bloco de decisão no resumo final (`ORQUESTRADOR.md`)
   3.2. Escrita local (seção `## Aprendizados` nas personas + regra de
        posicionamento antes da linha-ponteiro)
   3.3. Fila global (`agentes/.aprendizados-globais-pendentes.md`)
   3.4. `commands/aprendizados-sync.md` + espelho Gemini
4. Espelhos Gemini de tudo acima.
5. `README.md` e `claude/skills/init-project/SKILL.md`.
6. Testes novos + suíte completa existente.
