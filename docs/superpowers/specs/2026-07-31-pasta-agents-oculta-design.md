# Pasta instalada oculta (`agentes/` → `.agents/`) + gitignore automático

Data: 2026-07-31
Repositório: `agentes-pipeline` (fonte dos templates `agentes/`, `commands/` e `gemini/skills/`)

## Objetivo

Hoje o `/init-project` instala as 11 personas + `PIPELINE.md` numa pasta
**visível** `./agentes/` dentro do projeto do usuário. Separadamente, o lado
Gemini/Antigravity já instala os skills numa pasta **oculta** `.agents/skills/`
(ver `gemini/README.md`). São duas convenções diferentes para a mesma ideia —
dados de ferramenta que não fazem parte do código do projeto — e isso é
inconsistente.

Este spec unifica as duas: o `/init-project` passa a instalar em `./.agents/`
(oculta), no mesmo lugar que o Gemini já usa. Como bônus imediato, uma pasta
oculta de ferramenta normalmente não deveria ser commitada — então o
`/init-project` também passa a adicionar automaticamente uma entrada no
`.gitignore` do projeto, **se um `.gitignore` já existir ali** (não cria um do
zero).

Projetos que já rodaram `/init-project` antes desta mudança têm uma
`./agentes/` visível com dados reais dentro (`CONTEXTO.md`, `TEAM.md`,
`.init-manifest.json`, possíveis backups) — a próxima execução do
`/init-project` nesses projetos migra automaticamente essa pasta pra
`./.agents/`, preservando tudo.

**Fora de escopo:**
- `install.sh` / `install.ps1` — continuam cuidando só de `~/agentes-pipeline`
  e do link do skill; não criam pasta nenhuma dentro de projetos de usuário.
- A pasta-fonte `agentes/` na raiz **deste** repositório (`agentes-pipeline`) —
  é o template versionado, fonte de verdade; não muda de nome. Só a cópia
  instalada dentro do projeto do usuário é que passa a se chamar `.agents/`.
- Instalação manual do lado Gemini puro (`gemini/README.md`, opções 1 e 3 —
  `mkdir -p .agents && cp -R .../gemini/skills .agents/`) — esses comandos já
  usam `.agents/`; não precisam mudar. Só ganham uma nota sugerindo adicionar
  `.agents/` ao `.gitignore` manualmente, já que não há skill automatizando
  esse fluxo.
- `agentes` na lista `IGNORE_DIRS` de `agentes/scripts/detect-projects.sh` e na
  lista equivalente do `orquestrador-init/SKILL.md` — permanece nas duas
  listas (ao lado de `.agents`) por compatibilidade com projetos ainda não
  migrados; não é removida.

---

## Estrutura unificada resultante

Depois da mudança, um projeto com Claude e Gemini instalados tem:

```
projeto/
├── .agents/
│   ├── PIPELINE.md          ← (era agentes/PIPELINE.md)
│   ├── ORQUESTRADOR.md       ← (era agentes/ORQUESTRADOR.md)
│   ├── ANALISTA.md, PO.md, ARQUITETO.md, ... (demais personas)
│   ├── CONTEXTO.md           ← dado do projeto, nunca gerado/sobrescrito
│   ├── TEAM.md                ← dado do projeto, nunca gerado/sobrescrito
│   ├── .init-manifest.json
│   └── skills/                ← inalterado, já existia (lado Gemini)
├── .claude/
│   ├── commands/orquestrador*.md
│   └── skills/coding-standards/
└── .gitignore                 ← ganha uma linha `.agents/`, se já existir
```

Não há colisão de nomes entre os arquivos de persona (raiz de `.agents/`) e os
skills Gemini (`.agents/skills/`), então a cópia é uma fusão simples — mesma
disciplina de "não apagar o que já está lá" que o `init-project` já usa hoje
para `.claude/commands/` e `.claude/skills/`.

## Critério de "já instalado" (lado Claude)

Como `.agents/` pode existir só por causa do Gemini (sem nenhum arquivo do
lado Claude dentro), checar apenas `-d ./.agents` não é suficiente pra decidir
se é instalação nova ou atualização. O critério passa a ser a presença de
`.agents/PIPELINE.md` especificamente (arquivo exclusivo do lado Claude):

- `.agents/PIPELINE.md` não existe → instalação nova (copia o template pra
  dentro de `.agents/`, criando a pasta se não existir, sem apagar
  `.agents/skills/` se já estiver lá).
- `.agents/PIPELINE.md` existe → fluxo de atualização (igual ao já
  documentado no `SKILL.md`: sem `--update` faz backup completo, com
  `--update` roda o `init-manifest-diff.sh apply`).

## Migração de `./agentes/` legado

Antes de aplicar o critério acima, o `/init-project` verifica:

1. **`./agentes/` (legado) existe E `.agents/PIPELINE.md` não existe** → migra:
   1. `mv ./agentes ./.agents` (ou, se `./.agents/` já existir por causa do
      Gemini — ex.: só tem `skills/` dentro — move o *conteúdo* de
      `./agentes/` pra dentro de `./.agents/` em vez de renomear a pasta
      inteira, preservando `skills/`).
   2. Se `.agents/.init-manifest.json` existir, reescreve as chaves do JSON
      trocando o prefixo `"agentes/` por `".agents/` (edição textual das
      chaves — **não** roda `init-manifest-diff.sh generate` de novo, porque
      `generate` calcula o hash a partir do estado local atual; se o usuário
      já tiver customizado algum arquivo, isso gravaria a customização como
      se fosse a baseline do template, e a próxima atualização real do
      template passaria a sobrescrever silenciosamente sem avisar — exatamente
      o bug que o comentário em `init-manifest-diff.sh` já documenta).
   3. Segue para o critério de "já instalado" normalmente (agora vai bater
      "já existe" via `.agents/PIPELINE.md`).
   4. Relata a migração no resumo final ("pasta `agentes/` migrada para
      `.agents/`").
2. **`./agentes/` (legado) E `.agents/PIPELINE.md` existem ao mesmo tempo**
   (ambos com instalação Claude completa — situação anômala, não deveria
   acontecer em uso normal): para com um erro explicando o conflito e os dois
   caminhos encontrados, sem tentar mesclar automaticamente. Mesmo padrão de
   erro que `install.sh` já usa pra link apontando pro lugar errado.
3. Nenhum dos dois → segue o fluxo normal (instalação nova em `.agents/`).

## Automação do `.gitignore`

Em toda execução do `/init-project` (instalação nova ou atualização, com ou
sem migração):

1. Se `./.gitignore` **não existir** na raiz do projeto: não faz nada (não
   cria o arquivo).
2. Se existir: procura uma linha exatamente igual a `.agents`, `.agents/`,
   `/.agents` ou `/.agents/`. Se nenhuma dessas variantes estiver presente,
   acrescenta ao final do arquivo:
   ```
   
   # agentes-pipeline (dados locais, não versionados)
   .agents/
   ```
   (uma linha em branco antes, se o arquivo não terminar já em branco, pra
   não colar na última linha existente).
3. Idempotente: execuções seguintes não duplicam a entrada.

## Testes

Atualizar os testes que hoje assumem `agentes/` como pasta instalada:
`tests/team-md.test.sh`, `tests/gemini-orquestrador-paridade.test.sh`,
`tests/contexto-md.test.sh`, `tests/coding-standards-skill.test.sh`,
`scripts/init-manifest-diff.test.sh`, `commands/commands.test.sh` (as
asserções que checam que `orquestrador*.md` referenciam `agentes/*.md`
passam a checar `.agents/*.md`).

`scripts/init-manifest-diff.sh` troca os prefixos de caminho hardcoded
`agentes/` por `.agents/` em `tracked_files()`, `template_path_of()` e nos
caminhos do manifesto (`$project_root/agentes/.init-manifest.json` →
`$project_root/.agents/.init-manifest.json`).

Casos novos a cobrir (na skill `init-project`, via cenários de teste
equivalentes aos já existentes para o fluxo de update):
- Instalação nova num projeto sem `.agents/` nem `agentes/`: cria
  `.agents/` com os 12 arquivos.
- Instalação nova num projeto que já tem `.agents/skills/` (só Gemini): cria
  as personas dentro de `.agents/` sem apagar `skills/`.
- Migração: projeto com `./agentes/` legado (com `CONTEXTO.md`, `TEAM.md`,
  `.init-manifest.json` preenchido) → depois do `/init-project`, `./agentes/`
  não existe mais, `.agents/CONTEXTO.md` e `.agents/TEAM.md` têm o conteúdo
  original preservado, e as chaves do manifest apontam para `.agents/*`.
- Conflito: `./agentes/` e `.agents/PIPELINE.md` presentes ao mesmo tempo →
  erro, nenhum arquivo é tocado.
- `.gitignore` já existe e não tem a entrada → ganha a entrada.
- `.gitignore` já existe e já tem a entrada (qualquer uma das 4 variantes) →
  não duplica.
- `.gitignore` não existe → não é criado.

## Documentação

Atualizar referências a `./agentes/` como caminho instalado (mantendo
referências à pasta-fonte `agentes/` do próprio repo intactas — inclusive a
tabela "Pasta"/"Estrutura" do `README.md`, que descreve os diretórios deste
próprio repositório, não o caminho instalado):
- `README.md` — só a linha do bloco "Setup" que descreve o resultado do
  `/init-project` ("Pronto — o projeto agora tem `./agentes/`...") passa a
  `./.agents/`; acrescenta uma nota curta sobre a migração automática e o
  `.gitignore`.
- `AGENTS.md` — as seções que descrevem o projeto **onde o pipeline está
  instalado** (intro compartilhada e "Se você está num projeto com
  `./agentes/` instalado") passam a `.agents/`; a seção "Se você está neste
  repositório (`agentes-pipeline`)", que fala de editar `agentes/*.md` como
  fonte, continua igual.
- `gemini/skills/orquestrador-init/SKILL.md` (linha que cita
  `agentes/PIPELINE.md` como fonte da regra de fronteira de projeto)
- `gemini/README.md` (tabela "Diferença entre `gemini/` e `agentes/`" —
  linha "Localização no projeto" passa a `.agents/` pros dois, com nota de
  que as personas ficam na raiz de `.agents/` e os skills em
  `.agents/skills/`)
- `commands/orquestrador.md`, `commands/orquestrador-init.md`,
  `commands/orquestrador-team.md`, `commands/orquestrador-fix.md` — todas as
  referências a `agentes/ORQUESTRADOR.md`, `agentes/PIPELINE.md`,
  `agentes/CONTEXTO.md`, `agentes/TEAM.md` e
  `agentes/scripts/detect-projects.sh` passam a `.agents/...`. Esses
  arquivos são copiados para `.claude/commands/` de projetos instalados, então
  o caminho aqui é o caminho **no projeto do usuário**, não deste repositório.
