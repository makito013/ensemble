# Instalador multiplataforma (install.sh / install.ps1)

Data: 2026-07-30
Repositório: `agentes-pipeline` (fonte dos templates `agentes/`, `commands/` e `gemini/skills/`)

## Objetivo

O "Setup — usuário novo (Claude Code)" do README hoje exige 4 passos manuais,
dois dos quais são só de sistema de arquivos: clonar o repo **exatamente** em
`~/agentes-pipeline` (path fixo, porque o skill `init-project` resolve os
templates a partir daí) e criar um symlink de
`claude/skills/init-project` para `~/.claude/skills/init-project` via `ln -s`.

Isso não funciona bem no Windows: `ln -s` não existe no PowerShell, e o
equivalente (`New-Item -ItemType SymbolicLink`) exige privilégio de
administrador ou Developer Mode ativado — nenhum dos dois é garantido na
máquina do usuário. Além disso, exigir o clone num path exato é frágil (já
aconteceu do repo ser clonado em outro lugar, quebrando a suposição).

Este spec cobre dois scripts — `install.sh` (Mac/Linux) e `install.ps1`
(Windows) — que automatizam esses passos de forma idempotente e sem exigir
que o repo esteja em um path fixo, e além disso cobrem a parte hoje manual do
setup do Antigravity/Gemini CLI (clone do plugin Superpowers-Antigravity).

O Bruno também usa múltiplos perfis de configuração do Claude Code na mesma
máquina (`~/.claude`, `~/.claude-work`, `~/.claude-podesubir` — ver o
mecanismo já existente em `claude/continuidade/`, cujo `install.sh --target`
segue a mesma ideia). O link do skill `init-project` precisa poder ir pra
qualquer um desses perfis, não só `~/.claude`.

**Fora de escopo:**
- Instalar o plugin Superpowers do Claude Code (`/plugin install
  superpowers@claude-plugins-official`) — é um comando que só existe dentro
  do chat do Claude Code, não é scriptável via shell. O instalador só lembra
  o usuário de rodar isso.
- Instalar o Antigravity CLI em si (`npm install -g @google/antigravity`) —
  decisão explícita do Bruno de não automatizar instalação de pacote global
  do sistema; o instalador só avisa que falta, se `agy` não estiver no PATH.
- O passo por-projeto (`/init-project` no Claude, cópia de `gemini/skills/`
  no Antigravity) — continua manual/via skill, como já é hoje. Este spec é
  só sobre o setup de máquina que é pré-requisito pra esses passos.

---

## Comportamento (comum às duas plataformas)

Os scripts vivem na raiz do repo (`./install.sh`, `./install.ps1`) e são
executados de dentro do repo já clonado — em qualquer pasta, não precisa
mais ser `~/agentes-pipeline`. Aceitam um parâmetro opcional pra escolher o
perfil de configuração do Claude Code onde o skill `init-project` é linkado:

- `./install.sh` / `.\install.ps1` (sem parâmetro): perfil padrão, `~/.claude`.
- `./install.sh --target ~/.claude-work` / `.\install.ps1 -Target
  ~/.claude-work`: linka o skill dentro do perfil informado em vez do
  padrão. Serve pra qualquer perfil que o Bruno tenha (`~/.claude-work`,
  `~/.claude-podesubir`, etc.) — o script não valida uma lista fixa de
  nomes, só usa o path recebido.
- Rodar o script mais de uma vez, uma por perfil, é o fluxo esperado pra
  quem usa vários perfis (`./install.sh --target ~/.claude-work` depois
  `./install.sh --target ~/.claude-podesubir`, por exemplo) — cada chamada
  só mexe no link do skill daquele perfil; o link de `~/agentes-pipeline` e
  o plugin Antigravity (passos 2 e 4 abaixo) são por máquina, não por
  perfil, e ficam idempotentes entre chamadas.

Passos, em ordem:

1. **Descobrir `REPO_DIR`**: a pasta onde o próprio script está (caminho
   absoluto, resolvendo o script até sua localização real). **Resolver
   `TARGET`**: o valor de `--target`/`-Target` se informado, senão
   `~/.claude` (`$HOME/.claude` ou `$env:USERPROFILE\.claude`).
2. **Link de `~/agentes-pipeline` → `REPO_DIR`** (sempre `~/agentes-pipeline`
   fixo — não depende de `TARGET`):
   - Se não existe: cria o link.
   - Se já existe e já é um link apontando pra `REPO_DIR`: pula, reporta "já
     estava correto".
   - Se já existe e é uma pasta real (não link) ou um link pra **outro**
     lugar: **não sobrescreve** — imprime aviso explicando o conflito e o
     caminho encontrado, e para o script com código de saída não-zero. Isso
     evita apagar outra instalação ou dado do usuário.
3. **Link de `$TARGET/skills/init-project` → `REPO_DIR/claude/skills/init-project`**:
   mesma lógica de idempotência/proteção do passo 2.
4. **Plugin Superpowers-Antigravity**: se `git` estiver disponível no PATH e
   `~/.gemini/config/plugins/superpowers` não existir, clona
   `https://github.com/roundpilot/superpowers-antigravity` pra lá. Se já
   existe, pula. Se `git` não estiver disponível, avisa e segue (não é erro
   fatal — Antigravity é opcional).
5. **Resumo final**: imprime o que foi criado/pulado/já existia, e dois
   lembretes fixos:
   - Rodar `/plugin install superpowers@claude-plugins-official` dentro do
     Claude Code (não scriptável).
   - Se `agy` não for encontrado no PATH: rodar
     `npm install -g @google/antigravity` manualmente.

O script é **idempotente**: rodar de novo (ex.: depois de um `git pull`) não
duplica nem quebra nada, só reconfirma que está tudo correto.

---

## `install.sh` (Mac/Linux)

Bash (`#!/usr/bin/env bash`, `set -euo pipefail`), seguindo o mesmo estilo de
`claude/continuidade/install.sh` — inclusive o nome da flag: `--target
<pasta>` opcional (mesmo formato que `claude/continuidade/install.sh`
usa, mas opcional aqui em vez de obrigatório, com default `$HOME/.claude`).
`REPO_DIR` resolvido com `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`. Links
criados com `ln -s`. Verificação de link existente via `[[ -L "$path" ]]` +
comparação de `readlink`. `$(uname)` é usado só pra mensagens (symlink
funciona igual em Linux e macOS, não precisa de branch de comportamento).

## `install.ps1` (Windows)

PowerShell, com parâmetro opcional `-Target <pasta>` (default
`$env:USERPROFILE\.claude`). `REPO_DIR` resolvido a partir de
`$PSScriptRoot`. Links de pasta criados com `New-Item -ItemType Junction` —
não exige admin nem Developer Mode, ao contrário de symlink (`New-Item
-ItemType SymbolicLink`), que exigiria um dos dois. Verificação de link
existente via `(Get-Item $path).LinkType -eq 'Junction'` + comparação do
`.Target`. Clone do plugin Antigravity via `git.exe`, checando
disponibilidade com `Get-Command git -ErrorAction SilentlyContinue` antes.

## Testes

Segue o padrão já existente em `claude/continuidade/install.test.sh`: um
`install.test.sh` em bash na raiz do repo, que roda `install.sh` com `HOME`
apontado para uma pasta temporária (fixture) e verifica:
- Primeira execução, sem `--target` (perfil padrão): os dois links são
  criados corretamente, `$HOME/.claude/skills/init-project` apontando pro
  repo de verdade.
- Segunda execução (idempotência): não duplica nem falha, mesma saída
  "já correto".
- Caso de conflito: se `~/agentes-pipeline` já existe como pasta real (não
  link) antes de rodar, o script avisa e sai com erro, sem tocar na pasta.
- Com `--target`: rodar com `--target "$FAKE_HOME/.claude-work"` linka o
  skill dentro de `.claude-work/skills/init-project`, não em
  `.claude/skills/init-project` — e rodar de novo com um `--target`
  diferente (`.claude-podesubir`) não mexe no link já feito em
  `.claude-work`.

Sem teste automatizado para `install.ps1` — mesma situação do
`install.ps1` da continuidade hoje (`claude/continuidade/install.ps1`, sem
`.test.ps1` correspondente); verificação fica manual, já que não há
ambiente Windows na esteira de CI deste repo.

---

## README

A seção "Setup — usuário novo (Claude Code)" passa a ser:

```bash
git clone <url-deste-repo> ~/agentes-pipeline   # ou qualquer outra pasta
cd ~/agentes-pipeline

# Mac/Linux:
./install.sh
# Windows (PowerShell):
.\install.ps1
```

seguido só do lembrete de rodar `/plugin install
superpowers@claude-plugins-official` dentro do Claude Code, e depois
`/init-project` no projeto alvo. Uma nota junto explica o `--target`/
`-Target` pra quem usa mais de um perfil do Claude Code (`~/.claude-work`,
etc.): rodar o instalador de novo com `--target <pasta-do-perfil>` pra cada
perfil adicional.

As seções "Pré-requisitos por ferramenta" (parte do Antigravity) e
"Sincronizar em outra máquina" também são atualizadas para citar os scripts
em vez dos passos manuais de link/clone que eles substituem. A tabela de
"Estrutura" do README ganha uma linha para `install.sh` / `install.ps1` na
raiz.
