# Orquestrador: comandos reais, memória de projeto e update inteligente

Data: 2026-07-03
Repositório: `agentes-pipeline` (fonte dos templates `agentes/` e `gemini/skills/`)

## Objetivo

Hoje o pipeline é acionado por um prefixo de texto (`"Orquestrador: ..."`) sem
memória entre sessões e sem forma de reconfigurar o time padrão. Este spec:

1. Substitui o gatilho de texto por comandos reais (`/orquestrador`,
   `/orquestrador-init`, `/orquestrador-fix`, `/orquestrador-team`) no lado
   Claude, com equivalentes por auto-descoberta no lado Antigravity/Gemini.
2. Dá ao Orquestrador uma memória de projeto persistente (`agentes/CONTEXTO.md`),
   escopada por projeto mesmo dentro de monorepos, alimentada tanto por uma
   varredura inicial quanto por realimentação dos subagentes durante o uso normal.
3. Permite configurar quais das 10 etapas do pipeline ficam ativas por padrão
   por projeto (`agentes/TEAM.md`).
4. Torna `init-project --update` capaz de atualizar sem esmagar customizações
   locais, via manifesto + diff por arquivo.

**Fora de escopo deste spec** (fica para um spec seguinte, que depende deste):
migrar o projeto `podesubir` (que já tem um orquestrador próprio, "Condutor",
mais maduro pro domínio deles) para usar este pipeline. Esse spec vai usar
`CONTEXTO.md` como destino da bagagem de domínio do Condutor — mas isso só faz
sentido depois que este spec aqui existir de verdade.

**Decidido e fora de escopo:** bloquear skills GSD durante sessões do
Orquestrador. O Bruno optou por desinstalar o GSD globalmente
(`npx @opengsd/gsd-core --claude --global --uninstall`) em vez de conviver com
ele, então não há necessidade de nenhuma diretiva anti-GSD nos arquivos do
pipeline.

## B. Comandos novos

**Claude** — 4 arquivos novos em `agentes-pipeline/commands/`, copiados para
`<projeto>/.claude/commands/` pelo `init-project`:

- `orquestrador.md` — substitui o gatilho de texto. `argument-hint: [descrição da tarefa]`
- `orquestrador-init.md` — `argument-hint: [pasta opcional]`
- `orquestrador-fix.md` — `argument-hint: {texto do bug}`
- `orquestrador-team.md` — `argument-hint: [ação opcional: listar|ativar N|desativar N]`

Cada comando é um gatilho fino: lê `agentes/ORQUESTRADOR.md` (+ o arquivo de
estado relevante, `CONTEXTO.md`/`TEAM.md`, se existirem) e injeta `$ARGUMENTS`
no fluxo descrito lá. A lógica pesada continua centralizada em
`ORQUESTRADOR.md` — os comandos não duplicam regras.

**Gemini/Antigravity** — sem `$ARGUMENTS` nem `.claude/commands/`; o padrão de
lá é auto-descoberta por `description:`. Viram 3 skills novas em
`gemini/skills/`: `orquestrador-init/`, `orquestrador-fix/`, `orquestrador-team/`,
cada uma com `description:` afinada pra disparar quando o usuário escrever
algo como "orquestrador-fix: {texto}" — o "argumento" é o resto da frase,
igual já funciona hoje com `[F]`/`[B1]`.

## C. Migração do gatilho

`AGENTS.md`, `agentes/ORQUESTRADOR.md`, `agentes/PIPELINE.md` e o `README.md`
raiz trocam a instrução de "ative quando a mensagem começar com 'Orquestrador:'"
para "ative via `/orquestrador` no Claude". Sem compatibilidade retroativa com
o prefixo de texto no lado Claude — troca explícita. No lado Antigravity nada
muda (lá já é por skill discovery, não por comando).

## D. Onde vivem `CONTEXTO.md` e `TEAM.md`

Local único pros dois formatos: **`<projeto>/agentes/CONTEXTO.md`** e
**`<projeto>/agentes/TEAM.md`**, mesmo em projetos que só usam Antigravity (sem
as 11 personas Claude instaladas) — nesse caso o comando cria só a pasta
`agentes/` com esses dois arquivos de estado, sem instalar as personas.

### Estrutura de `CONTEXTO.md`

Seções fixas, nesta ordem:

1. **Visão geral do projeto** — propósito, domínio, stack.
2. **Arquitetura** — camadas, padrões, decisões estruturais.
3. **Convenções de código** — estilo, nomenclatura, padrões observados no repo.
4. **Decisões importantes e histórico** — por que certas escolhas foram feitas.
5. **Integrações externas / dependências entre projetos** — ex: "consome os
   endpoints X e Y do serviço `ymci-backend`; contrato em `docs/api/...`".
   Existe justamente para o caso de monorepo onde um projeto secundário
   depende de 1-2 endpoints do produto principal, sem precisar importar o
   contexto inteiro do outro projeto.
6. **Áreas sensíveis / gotchas conhecidos** — coisas que quebram fácil, dívida técnica.
7. **Log de atualizações** — data, o que mudou, origem (`init` ou `pipeline`).

### Estrutura de `TEAM.md`

Checklist no mesmo formato do menu de `ORQUESTRADOR.md`, mas persistido:

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

## E. Regra de "o que é um projeto" (monorepo, sem pasta passada)

Validada contra a estrutura real de `~/projetos/podesubir` (17 repositórios
git reais, em profundidades 2 e 3 a partir da raiz — ver apêndice). Regra:

A partir de uma raiz de busca `R` (a pasta passada para `/orquestrador-init`,
ou o cwd se nenhuma for passada):

1. Se `R` contém `.git` diretamente → `R` é um projeto único. Fim, não desce.
2. Senão, busca em largura (BFS) a partir de `R`, respeitando:
   - **Ignora sempre**: `node_modules`, `.git`, `dist`, `build`, `vendor`,
     `.venv`, `__pycache__`, `.agents`, `.claude`, `agentes/`.
   - Em cada diretório visitado, verifica marcador de projeto: `.git`
     (marcador primário) ou, na ausência dele, `package.json`,
     `pyproject.toml`, `go.mod`, `Cargo.toml`, `composer.json`, `pom.xml` ou
     `Gemfile` diretamente dentro do diretório.
   - **`*.code-workspace` NÃO é marcador de projeto** — é só um agrupador
     multi-root do VS Code (é exatamente o que existe em
     `principal/principal.code-workspace` e
     `cadastro_simplificado/cadastro_simplificado.code-workspace`, uma pasta
     acima dos projetos de verdade). Presença dele não para a descida.
   - No momento em que um diretório bate com um marcador → é um projeto:
     registra e **para de descer** dentro dele (não entra nos subdiretórios
     daquele projeto — evita achar "sub-projetos" dentro de um repo).
   - Profundidade máxima de segurança: 6 níveis a partir de `R`. Se nada for
     encontrado até lá, reporta ao Bruno em vez de continuar cego.
3. Cada projeto encontrado recebe seu próprio `agentes/CONTEXTO.md`, escaneado
   só dentro da sua própria subárvore — nunca mistura contexto entre projetos.

Com pasta passada (`/orquestrador-init caminho/x`) e `caminho/x` não sendo,
ele mesmo, um projeto único pela regra 1, a mesma busca (regra 2) roda com
`R = caminho/x` — ou seja, dá pra apontar pra um agrupador tipo `gateways/` e
ele varre só os projetos daquele agrupador.

## F. Fluxo de `/orquestrador-init`

Para cada projeto detectado (E), o Orquestrador dispara um **subagente
isolado** (`general-purpose`, não fork — precisa rodar em paralelo entre
projetos sem herdar contexto de outro) que varre aquela subárvore e
escreve/atualiza `agentes/CONTEXTO.md` com as seções da seção D. Se
`CONTEXTO.md` já existe, o subagente funde (preserva o que ainda é válido,
atualiza o que mudou, registra no log) em vez de sobrescrever cegamente.

Resumo final ao Bruno: lista de projetos processados, quais eram novos vs.
atualizados, e qualquer aviso (ex: projeto sem marcador reconhecido).

## G. Realimentação de contexto durante o pipeline normal

Isso não pode ser só uma frase solta numa persona — subagentes não têm
memória, então a instrução precisa estar no **prompt de disparo** que o
Orquestrador monta a cada etapa (mecânica já descrita em `ORQUESTRADOR.md`,
seção "Como disparar cada etapa"). Ajuste nela: todo prompt de disparo passa a
pedir ao subagente que termine sua resposta com uma seção opcional
"Atualização de contexto sugerida" se ele aprendeu algo que muda o
entendimento do projeto (ex: durante a implementação de Y ele percebeu que X
mudou). No fim da sessão, o Orquestrador consolida essas sugestões e, se
houver alguma, **pergunta ao Bruno antes de gravar** em `CONTEXTO.md` — não
grava silenciosamente.

## H. Fluxo de `/orquestrador-fix {texto}`

1. Orquestrador lê `agentes/CONTEXTO.md` do projeto relevante, se existir.
2. Faz uma triagem do texto do bug (inline, ou via um subagente leve de
   triagem se o texto for complexo) e propõe um subconjunto de etapas
   pré-marcado no mesmo menu de sempre, com uma linha de justificativa curta
   (ex: "recomendo Analista, TL, Dev, QA, Revisor porque mexe em lógica
   compartilhada com o módulo de pagamentos").
3. Bruno aceita, adiciona ou remove qualquer etapa antes de confirmar — igual
   ao menu normal, só que pré-preenchido por recomendação em vez de por
   perfil-letra ([B1]/[B2]/[B3]).
4. Segue a mecânica de disparo normal a partir daí.

## I. Fluxo de `/orquestrador-team`

Lê/edita `agentes/TEAM.md`. Sem argumento: mostra o estado atual. Com
argumento (`ativar 3`, `desativar 8`, etc.): edita e confirma. Quando
`TEAM.md` existe, o menu do `/orquestrador` normal chega pré-marcado com esse
padrão em vez do padrão fixo atual do documento — o Bruno ainda pode mudar por
sessão, isso não muda.

## J. Subagentes e escalonamento de modelo (Sonnet/Opus)

Regra transversal, escrita **uma vez** em `agentes/PIPELINE.md` (seção nova:
"Subagentes e escolha de modelo") e referenciada por uma linha-ponteiro em
cada uma das 11 personas — evita duplicar o parágrafo 11 vezes.

Conteúdo da regra:

- Qualquer agente (inclusive o Orquestrador) pode disparar subagentes próprios
  para paralelizar partes independentes do seu próprio trabalho.
- Modelo padrão: Sonnet. Escalar para Opus quando perceber complexidade real
  (refatoração ampla, lógica ambígua exigindo raciocínio profundo, código
  security-sensitive, ou quando um subagente Sonnet já não deu conta).
- **Ressalva:** o override de modelo só funciona ao disparar um subagente
  novo (`subagent_type` diferente de fork) — um *fork* sempre roda no modelo
  de quem o disparou, o override é ignorado nesse caso. A escalação pra Opus
  só vale para subagentes "frescos", não para forks.

## K. `init-project --update` — merge inteligente

A peça mais arriscada; fica **por último** na ordem de implementação (ver
seção "Ordem de implementação" abaixo) — não bloqueia o resto.

- Novo `agentes/.init-manifest.json`, gravado/atualizado a cada
  instalação/update:

  ```json
  {
    "templateVersion": "<sha ou timestamp do template no momento>",
    "installedAt": "2026-07-03T12:00:00Z",
    "files": {
      "ANALISTA.md": "sha256:...",
      "PIPELINE.md": "sha256:...",
      "commands/orquestrador.md": "sha256:..."
    }
  }
  ```

- Em `--update`, para cada arquivo do conjunto de template (11 personas +
  `PIPELINE.md` + os 4 comandos): compara hash local vs. hash no manifesto vs.
  hash do template atual:
  - Local == manifesto (usuário nunca tocou) → sobrescreve com a versão nova.
  - Local ≠ manifesto e template não mudou → preserva, não mexe.
  - Local ≠ manifesto e template também mudou → **conflito**: não sobrescreve,
    grava `<arquivo>.new` ao lado e lista no resumo pra revisão manual.
  - Arquivo novo no template (não existe local) → instala.
- `CONTEXTO.md`, `TEAM.md` e o próprio `.init-manifest.json` nunca entram
  nesse diff — são dados do projeto, não do template.
- Sem `--update` (comando puro, sem flag): comportamento atual continua
  (backup completo do `agentes/` antigo + reinstala tudo).
- Projeto sem manifesto ainda (instalado antes desta mudança): `--update` cai
  automaticamente no comportamento de backup completo na primeira vez, e a
  partir daí passa a ter manifesto pras próximas atualizações.

## L. Limpeza de documentação

`README.md` e `gemini/README.md` param de referenciar `~/bin/init-project` no
fluxo Claude — esse script é de um formato antigo/inconsistente
(`.agents/skills/` a partir de `~/.gemini/config/skills`) que não bate com a
instalação atual via `agentes/`. O script em si fica intocado; só a referência
incorreta sai da documentação.

## Ordem de implementação

1. Infra de comandos (Claude `commands/` + Gemini skills novas) + migração do
   gatilho (B, C).
2. `TEAM.md` (estado mais simples) (I).
3. `CONTEXTO.md` + `/orquestrador-init` (D, E, F, G).
4. `/orquestrador-fix` (H).
5. Regra de subagentes/modelo em `PIPELINE.md` (J).
6. Limpeza de docs (L).
7. `init-project --update` com manifesto (K) — por último, valida o resto
   primeiro num projeto real antes de entrar na parte mais arriscada.

## Apêndice — projetos reais encontrados em `podesubir` (validação da regra E)

```
principal/ymci-backend
principal/ymci-backoffice
principal/ymci-guards-frontend
principal/ymci-frontend
principal/apps/podesubir-app
principal/apps/podesubir-guardapp
portal_light/portal-light-frontend
portal_light/portal-light-backend
cadastro_simplificado/api
cadastro_simplificado/front
gateways/access-gateway-advancis
gateways/access-gateway-true-safe
gateways/access-gateway-controlid
gateways/access-gateway-controlid-db
gateways/access-gateway-trilobit
gateways/access-gateway-genetec
gateways/access-gateway-hikicentral
gateways/access-gateway-hikivision
gateways/ymci-image-resizer
```

17 projetos, em profundidade 2 (a maioria) ou 3 (`principal/apps/*`) a partir
da raiz de `podesubir`. Nenhum tem marcador na raiz de `podesubir` nem nas
pastas agrupadoras (`principal/`, `gateways/`, `cadastro_simplificado/`,
`portal_light/`) — só nos repositórios de verdade. A regra E foi desenhada
especificamente para não parar nesses agrupadores.
