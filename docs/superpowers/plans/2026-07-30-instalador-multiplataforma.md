# Instalador multiplataforma (install.sh / install.ps1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir os passos manuais de "clonar em path fixo + `ln -s`" do setup de máquina por dois scripts idempotentes (`install.sh` Mac/Linux, `install.ps1` Windows) que funcionam com o repo clonado em qualquer pasta, e documentar isso no README.

**Architecture:** Cada script descobre a própria localização (`REPO_DIR`), cria/verifica dois links de pasta (`~/agentes-pipeline` → `REPO_DIR`, sempre fixo; e `$TARGET/skills/init-project` → `REPO_DIR/claude/skills/init-project`, onde `$TARGET` é um parâmetro opcional — `--target`/`-Target` — que default pra `~/.claude` e permite escolher outro perfil de configuração do Claude Code, ex.: `~/.claude-work`) e, best-effort, clona o plugin Superpowers-Antigravity se `git` estiver disponível e ele ainda não existir. Mac/Linux usa `ln -s` (symlink); Windows usa `New-Item -ItemType Junction` (não exige admin nem Developer Mode). Ambos são idempotentes e recusam sobrescrever um destino que já existe como algo diferente do link esperado.

**Tech Stack:** Bash (`install.sh`), PowerShell 5.1+ (`install.ps1`), teste em bash puro (`install.test.sh`, sem framework, mesmo estilo de `claude/continuidade/install.test.sh`).

## Global Constraints

- Os scripts vivem na raiz do repo: `./install.sh`, `./install.ps1`.
- Não exigem que o repo esteja clonado em `~/agentes-pipeline` — funcionam de qualquer pasta.
- Parâmetro opcional `--target <pasta>` (bash) / `-Target <pasta>` (PowerShell) escolhe o perfil de configuração do Claude Code onde o skill `init-project` é linkado (ex.: `~/.claude-work`, `~/.claude-podesubir`). Default quando omitido: `~/.claude` (`$HOME/.claude` ou `$env:USERPROFILE\.claude`). Não valida uma lista fixa de perfis — aceita qualquer path.
- O link de `~/agentes-pipeline` e o clone do plugin Antigravity são por máquina (não dependem de `--target`); só o link do skill é por perfil. Rodar o script várias vezes com `--target` diferente (uma vez por perfil) é o fluxo esperado para quem usa múltiplos perfis, e não afeta os links já feitos em outros perfis.
- Idempotentes: rodar de novo não duplica nem quebra nada.
- Se um destino de link já existe e não é o link esperado (pasta real ou link pra outro lugar), o script avisa e sai com código de erro — nunca sobrescreve/apaga silenciosamente.
- Não automatizam `/plugin install superpowers@claude-plugins-official` (comando só existe dentro do chat do Claude Code) nem `npm install -g @google/antigravity` (decisão explícita de não mexer em pacote global do sistema) — só avisam sobre esses dois passos no resumo final.
- `install.sh` tem teste automatizado (`install.test.sh`); `install.ps1` não (mesma situação do `claude/continuidade/install.ps1` hoje — sem ambiente Windows na esteira de CI deste repo), verificação é manual durante a implementação.
- Mensagens de saída em português, mesmo tom direto dos scripts existentes (`claude/continuidade/install.sh`).

---

## Task 1: `install.sh` + `install.test.sh` (Mac/Linux)

**Files:**
- Create: `install.sh`
- Create: `install.test.sh`

**Interfaces:**
- Produces: um script `install.sh` executável via `bash install.sh [--target <pasta>]`, que:
  - lê `$HOME` do ambiente (testável via override de `HOME`)
  - aceita `--target <pasta>` opcional; default `$HOME/.claude` — define onde o skill `init-project` é linkado (`$TARGET/skills/init-project`)
  - lê `AGENTES_PIPELINE_SKIP_ANTIGRAVITY` do ambiente (se setada com qualquer valor não-vazio, pula a etapa do plugin Antigravity — hook interno só para teste, não documentado no README)
  - imprime linhas `OK: ...`, `ERRO: ...` ou `AVISO: ...` no stdout
  - sai com código `0` se tudo certo, `1` se algum link estava em conflito, `2` se `--target` foi passado sem valor ou com uma flag desconhecida

- [ ] **Step 1: Escrever `install.test.sh` (vai falhar — `install.sh` ainda não existe)**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="$SCRIPT_DIR/install.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

FAKE_HOME="$FIXTURE/home"
mkdir -p "$FAKE_HOME"

fail=0

run_installer() {
  HOME="$FAKE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 bash "$INSTALLER"
}

# --- primeira execução: cria os dois links ---
OUT1="$(run_installer)"

PIPELINE_LINK="$FAKE_HOME/agentes-pipeline"
SKILL_LINK="$FAKE_HOME/.claude/skills/init-project"

if [[ -L "$PIPELINE_LINK" ]] && [[ "$(cd "$PIPELINE_LINK" && pwd -P)" == "$SCRIPT_DIR" ]]; then
  echo "PASS: ~/agentes-pipeline linkado pro repo"
else
  echo "FAIL: ~/agentes-pipeline não foi linkado corretamente"
  fail=1
fi

if [[ -L "$SKILL_LINK" ]] && [[ "$(cd "$SKILL_LINK" && pwd -P)" == "$SCRIPT_DIR/claude/skills/init-project" ]]; then
  echo "PASS: skill init-project linkado pro repo (perfil padrão ~/.claude)"
else
  echo "FAIL: skill init-project não foi linkado corretamente"
  fail=1
fi

if echo "$OUT1" | grep -q "AGENTES_PIPELINE_SKIP_ANTIGRAVITY"; then
  echo "PASS: etapa do Antigravity respeitou a flag de skip"
else
  echo "FAIL: saída não confirma que a etapa do Antigravity foi pulada: $OUT1"
  fail=1
fi

if echo "$OUT1" | grep -q "plugin install superpowers@claude-plugins-official"; then
  echo "PASS: lembrete do plugin Superpowers impresso"
else
  echo "FAIL: lembrete do plugin Superpowers não apareceu na saída"
  fail=1
fi

# --- segunda execução: idempotente, sem duplicar nem falhar ---
OUT2="$(run_installer)"
if echo "$OUT2" | grep -q "já linkado corretamente"; then
  echo "PASS: segunda execução reconhece os links já corretos"
else
  echo "FAIL: segunda execução não reportou idempotência: $OUT2"
  fail=1
fi

# --- caso de conflito: ~/agentes-pipeline já existe como pasta real ---
CONFLICT_HOME="$FIXTURE/home-conflict"
mkdir -p "$CONFLICT_HOME/agentes-pipeline"
echo "dado do usuário" > "$CONFLICT_HOME/agentes-pipeline/nao-mexer.txt"

set +e
HOME="$CONFLICT_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 bash "$INSTALLER" > "$FIXTURE/out-conflict.txt" 2>&1
CONFLICT_EXIT=$?
set -e

if [[ "$CONFLICT_EXIT" -ne 0 ]]; then
  echo "PASS: instalador sai com erro quando ~/agentes-pipeline é uma pasta real conflitante"
else
  echo "FAIL: instalador deveria ter saído com erro no caso de conflito"
  fail=1
fi

if [[ -f "$CONFLICT_HOME/agentes-pipeline/nao-mexer.txt" ]]; then
  echo "PASS: pasta conflitante não foi tocada"
else
  echo "FAIL: pasta conflitante foi apagada/alterada"
  fail=1
fi

if grep -q "ERRO" "$FIXTURE/out-conflict.txt"; then
  echo "PASS: mensagem de erro do conflito impressa"
else
  echo "FAIL: mensagem de erro do conflito ausente: $(cat "$FIXTURE/out-conflict.txt")"
  fail=1
fi

# --- --target: linka num perfil diferente do padrão, sem mexer no padrão ---
PROFILE_HOME="$FIXTURE/home-profiles"
mkdir -p "$PROFILE_HOME"

HOME="$PROFILE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" --target "$PROFILE_HOME/.claude-work" > "$FIXTURE/out-target1.txt"

WORK_SKILL_LINK="$PROFILE_HOME/.claude-work/skills/init-project"
DEFAULT_SKILL_LINK="$PROFILE_HOME/.claude/skills/init-project"

if [[ -L "$WORK_SKILL_LINK" ]] && [[ "$(cd "$WORK_SKILL_LINK" && pwd -P)" == "$SCRIPT_DIR/claude/skills/init-project" ]]; then
  echo "PASS: --target linka o skill no perfil informado (.claude-work)"
else
  echo "FAIL: --target não linkou o skill no perfil informado"
  fail=1
fi

if [[ -e "$DEFAULT_SKILL_LINK" ]]; then
  echo "FAIL: --target mexeu no perfil padrão (.claude), não deveria"
  fail=1
else
  echo "PASS: --target não criou nada no perfil padrão"
fi

# --- segundo perfil: coexiste com o primeiro, sem conflito ---
HOME="$PROFILE_HOME" AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1 \
  bash "$INSTALLER" --target "$PROFILE_HOME/.claude-podesubir" > "$FIXTURE/out-target2.txt"

PODESUBIR_SKILL_LINK="$PROFILE_HOME/.claude-podesubir/skills/init-project"

if [[ -L "$WORK_SKILL_LINK" ]] && [[ -L "$PODESUBIR_SKILL_LINK" ]]; then
  echo "PASS: dois perfis diferentes coexistem, cada um com seu link"
else
  echo "FAIL: instalar um segundo perfil afetou o primeiro"
  fail=1
fi

# --- --target sem valor: erro de uso, exit code 2 ---
set +e
bash "$INSTALLER" --target > "$FIXTURE/out-usage.txt" 2>&1
USAGE_EXIT=$?
set -e

if [[ "$USAGE_EXIT" -eq 2 ]]; then
  echo "PASS: --target sem valor sai com exit code 2"
else
  echo "FAIL: --target sem valor deveria sair com exit code 2, saiu com $USAGE_EXIT"
  fail=1
fi

if [[ "$fail" -eq 0 ]]; then
  echo "TODOS OS TESTES PASSARAM"
  exit 0
else
  echo "ALGUM TESTE FALHOU"
  exit 1
fi
```

- [ ] **Step 2: Rodar o teste e confirmar que falha (install.sh não existe ainda)**

Run: `bash install.test.sh`
Expected: erro do tipo `bash: install.sh: No such file or directory` (ou `FAIL` nas primeiras verificações) — não `TODOS OS TESTES PASSARAM`.

- [ ] **Step 3: Escrever `install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "uso: install.sh [--target <pasta-de-perfil>]" >&2
  echo "  ex: install.sh --target ~/.claude-work" >&2
  exit 2
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

TARGET="$HOME/.claude"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || usage
      TARGET="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

PIPELINE_HOME="$HOME/agentes-pipeline"
SKILL_LINK="$TARGET/skills/init-project"
SKILL_TARGET="$REPO_DIR/claude/skills/init-project"
ANTIGRAVITY_PLUGIN_DIR="$HOME/.gemini/config/plugins/superpowers"
ANTIGRAVITY_PLUGIN_URL="https://github.com/roundpilot/superpowers-antigravity"

FAIL=0

ensure_link() {
  local target="$1" link="$2" label="$3"
  mkdir -p "$(dirname "$link")"

  if [[ -L "$link" ]]; then
    local resolved=""
    resolved="$(cd "$link" 2>/dev/null && pwd -P || true)"
    local target_resolved
    target_resolved="$(cd "$target" && pwd -P)"
    if [[ "$resolved" == "$target_resolved" ]]; then
      echo "OK: $label já linkado corretamente ($link -> $target)"
    else
      echo "ERRO: $label existe em $link mas aponta pra outro lugar (${resolved:-link quebrado}, esperado $target_resolved). Resolva manualmente antes de rodar de novo."
      FAIL=1
    fi
  elif [[ -e "$link" ]]; then
    echo "ERRO: $label existe em $link mas não é um link (é uma pasta/arquivo real). Resolva manualmente (mova ou remova) antes de rodar de novo."
    FAIL=1
  else
    ln -s "$target" "$link"
    echo "OK: $label linkado ($link -> $target)"
  fi
}

ensure_link "$REPO_DIR" "$PIPELINE_HOME" "~/agentes-pipeline"
ensure_link "$SKILL_TARGET" "$SKILL_LINK" "skill init-project ($TARGET)"

if [[ -n "${AGENTES_PIPELINE_SKIP_ANTIGRAVITY:-}" ]]; then
  echo "OK: etapa do plugin Superpowers-Antigravity pulada (AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1)"
elif command -v git >/dev/null 2>&1; then
  if [[ -d "$ANTIGRAVITY_PLUGIN_DIR" ]]; then
    echo "OK: plugin Superpowers-Antigravity já presente em $ANTIGRAVITY_PLUGIN_DIR"
  else
    mkdir -p "$(dirname "$ANTIGRAVITY_PLUGIN_DIR")"
    git clone "$ANTIGRAVITY_PLUGIN_URL" "$ANTIGRAVITY_PLUGIN_DIR"
    echo "OK: plugin Superpowers-Antigravity clonado em $ANTIGRAVITY_PLUGIN_DIR"
  fi
else
  echo "AVISO: git não encontrado no PATH — pulei a instalação do plugin Superpowers-Antigravity. Instale git e rode este script de novo, ou clone manualmente: git clone $ANTIGRAVITY_PLUGIN_URL $ANTIGRAVITY_PLUGIN_DIR"
fi

echo ""
echo "Lembretes (não automatizáveis por este script):"
echo "  - Dentro do Claude Code, rode: /plugin install superpowers@claude-plugins-official"
if ! command -v agy >/dev/null 2>&1; then
  echo "  - Antigravity CLI não encontrado no PATH. Instale com: npm install -g @google/antigravity"
fi

exit "$FAIL"
```

Tornar executável:

Run: `chmod +x install.sh install.test.sh`

- [ ] **Step 4: Rodar o teste de novo e confirmar que passa**

Run: `bash install.test.sh`
Expected: todas as linhas `PASS:`, termina com `TODOS OS TESTES PASSARAM` e exit code `0`.

- [ ] **Step 5: Commit**

```bash
git add install.sh install.test.sh
git commit -m "feat: adiciona install.sh (Mac/Linux) para bootstrap de máquina"
```

---

## Task 2: `install.ps1` (Windows)

**Files:**
- Create: `install.ps1`

**Interfaces:**
- Produces: um script `install.ps1` executável via `.\install.ps1 [-Target <pasta>]`, mesmo contrato de saída/exit code do `install.sh` (Task 1), usando `$env:USERPROFILE` no lugar de `$HOME` e `$env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY` no lugar da env var bash. `-Target` é opcional, default `$env:USERPROFILE\.claude` — define onde o skill `init-project` é linkado (`$Target\skills\init-project`).

- [ ] **Step 1: Escrever `install.ps1`**

```powershell
param(
    [string]$Target = (Join-Path $env:USERPROFILE ".claude")
)

$ErrorActionPreference = "Stop"

$RepoDir = $PSScriptRoot
$PipelineHome = Join-Path $env:USERPROFILE "agentes-pipeline"
$SkillLink = Join-Path $Target "skills\init-project"
$SkillTarget = Join-Path $RepoDir "claude\skills\init-project"
$AntigravityPluginDir = Join-Path $env:USERPROFILE ".gemini\config\plugins\superpowers"
$AntigravityPluginUrl = "https://github.com/roundpilot/superpowers-antigravity"

$script:Fail = $false

function Resolve-FullPath([string]$Path) {
    (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
}

function Ensure-Junction {
    param(
        [string]$LinkTarget,
        [string]$Link,
        [string]$Label
    )

    $linkParent = Split-Path -Parent $Link
    if (-not (Test-Path -LiteralPath $linkParent)) {
        New-Item -ItemType Directory -Force -Path $linkParent | Out-Null
    }

    if (Test-Path -LiteralPath $Link) {
        $item = Get-Item -LiteralPath $Link -Force
        if ($item.LinkType -eq "Junction") {
            $currentTarget = (@($item.Target)[0]).TrimEnd('\')
            $targetResolved = Resolve-FullPath $LinkTarget
            if ($currentTarget -eq $targetResolved) {
                Write-Output "OK: $Label ja linkado corretamente ($Link -> $LinkTarget)"
            } else {
                Write-Output "ERRO: $Label existe em $Link mas aponta pra outro lugar ($currentTarget, esperado $targetResolved). Resolva manualmente antes de rodar de novo."
                $script:Fail = $true
            }
        } else {
            Write-Output "ERRO: $Label existe em $Link mas nao e uma junction (e uma pasta/arquivo real). Resolva manualmente (mova ou remova) antes de rodar de novo."
            $script:Fail = $true
        }
        return
    }

    New-Item -ItemType Junction -Path $Link -Target $LinkTarget | Out-Null
    Write-Output "OK: $Label linkado ($Link -> $LinkTarget)"
}

Ensure-Junction -LinkTarget $RepoDir -Link $PipelineHome -Label "~/agentes-pipeline"
Ensure-Junction -LinkTarget $SkillTarget -Link $SkillLink -Label "skill init-project ($Target)"

if ($env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY) {
    Write-Output "OK: etapa do plugin Superpowers-Antigravity pulada (AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1)"
} else {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        if (Test-Path -LiteralPath $AntigravityPluginDir) {
            Write-Output "OK: plugin Superpowers-Antigravity ja presente em $AntigravityPluginDir"
        } else {
            $pluginParent = Split-Path -Parent $AntigravityPluginDir
            New-Item -ItemType Directory -Force -Path $pluginParent | Out-Null
            & git clone $AntigravityPluginUrl $AntigravityPluginDir
            Write-Output "OK: plugin Superpowers-Antigravity clonado em $AntigravityPluginDir"
        }
    } else {
        Write-Output "AVISO: git nao encontrado no PATH - pulei a instalacao do plugin Superpowers-Antigravity. Instale git e rode este script de novo, ou clone manualmente: git clone $AntigravityPluginUrl $AntigravityPluginDir"
    }
}

Write-Output ""
Write-Output "Lembretes (nao automatizaveis por este script):"
Write-Output "  - Dentro do Claude Code, rode: /plugin install superpowers@claude-plugins-official"
$agyCmd = Get-Command agy -ErrorAction SilentlyContinue
if (-not $agyCmd) {
    Write-Output "  - Antigravity CLI nao encontrado no PATH. Instale com: npm install -g @google/antigravity"
}

if ($script:Fail) {
    exit 1
}
```

- [ ] **Step 2: Verificação manual — primeira execução (cria as duas junctions)**

Rodar `install.ps1` diretamente via `&` no processo atual é arriscado: se o
script chamar `exit` (caso de conflito, por exemplo), isso encerra a sessão
PowerShell atual, não só o script. Por isso toda verificação manual invoca
`install.ps1` como processo filho (`pwsh -NoProfile -File ...`), igual ao
Step 5 (conflito) — nunca com `&` direto.

Run (PowerShell):
```powershell
$fakeHome = Join-Path $env:TEMP "install-ps1-check-$([guid]::NewGuid())"
New-Item -ItemType Directory -Force -Path $fakeHome | Out-Null
$origProfile = $env:USERPROFILE
$env:USERPROFILE = $fakeHome
$env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY = "1"
pwsh -NoProfile -File "D:\projetos\Pessoal\Ia-Agents\install.ps1"
$env:USERPROFILE = $origProfile
Remove-Item Env:\AGENTES_PIPELINE_SKIP_ANTIGRAVITY
Get-Item (Join-Path $fakeHome "agentes-pipeline") | Select-Object LinkType,Target
Get-Item (Join-Path $fakeHome ".claude\skills\init-project") | Select-Object LinkType,Target
```
Expected: as duas linhas `OK: ... linkado (...)`, o lembrete do plugin Superpowers, `LinkType` = `Junction` nas duas, `Target` apontando pra `D:\projetos\Pessoal\Ia-Agents` e `D:\projetos\Pessoal\Ia-Agents\claude\skills\init-project` respectivamente.

- [ ] **Step 3: Verificação manual — segunda execução (idempotente)**

Run (PowerShell, reaproveitando `$fakeHome` do Step 2 — não remover ainda):
```powershell
$origProfile = $env:USERPROFILE
$env:USERPROFILE = $fakeHome
$env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY = "1"
pwsh -NoProfile -File "D:\projetos\Pessoal\Ia-Agents\install.ps1"
$exitCode = $LASTEXITCODE
$env:USERPROFILE = $origProfile
Remove-Item Env:\AGENTES_PIPELINE_SKIP_ANTIGRAVITY
$exitCode
```
Expected: as duas linhas dizem `OK: ... ja linkado corretamente (...)`, sem erro, `$exitCode` igual a `0`.

- [ ] **Step 4: Verificação manual — parâmetro `-Target` (múltiplos perfis)**

Run (PowerShell):
```powershell
$profileHome = Join-Path $env:TEMP "install-ps1-target-$([guid]::NewGuid())"
New-Item -ItemType Directory -Force -Path $profileHome | Out-Null
$origProfile = $env:USERPROFILE
$env:USERPROFILE = $profileHome
$env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY = "1"
pwsh -NoProfile -File "D:\projetos\Pessoal\Ia-Agents\install.ps1" -Target (Join-Path $profileHome ".claude-work")
pwsh -NoProfile -File "D:\projetos\Pessoal\Ia-Agents\install.ps1" -Target (Join-Path $profileHome ".claude-podesubir")
$env:USERPROFILE = $origProfile
Remove-Item Env:\AGENTES_PIPELINE_SKIP_ANTIGRAVITY
Test-Path (Join-Path $profileHome ".claude-work\skills\init-project")
Test-Path (Join-Path $profileHome ".claude-podesubir\skills\init-project")
Test-Path (Join-Path $profileHome ".claude\skills\init-project")
Remove-Item -Recurse -Force $profileHome -ErrorAction SilentlyContinue
```
Expected: as duas primeiras chamadas de `Test-Path` retornam `True` (cada perfil recebeu seu próprio link do skill, apontando pra `D:\projetos\Pessoal\Ia-Agents\claude\skills\init-project`), e a terceira retorna `False` (o perfil padrão `.claude` não foi tocado, já que nenhuma das duas chamadas usou o default).

- [ ] **Step 5: Verificação manual — caso de conflito**

Run (PowerShell):
```powershell
$conflictHome = Join-Path $env:TEMP "install-ps1-conflict-$([guid]::NewGuid())"
New-Item -ItemType Directory -Force -Path (Join-Path $conflictHome "agentes-pipeline") | Out-Null
Set-Content -Path (Join-Path $conflictHome "agentes-pipeline\nao-mexer.txt") -Value "dado do usuario"
$origProfile = $env:USERPROFILE
$env:USERPROFILE = $conflictHome
$env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY = "1"
& pwsh -NoProfile -File "D:\projetos\Pessoal\Ia-Agents\install.ps1"
$exitCode = $LASTEXITCODE
$env:USERPROFILE = $origProfile
Remove-Item Env:\AGENTES_PIPELINE_SKIP_ANTIGRAVITY
$exitCode
Test-Path (Join-Path $conflictHome "agentes-pipeline\nao-mexer.txt")
Remove-Item -Recurse -Force $fakeHome, $conflictHome -ErrorAction SilentlyContinue
```
Expected: `$exitCode` diferente de `0`, mensagem `ERRO: ...` impressa, e `Test-Path` do arquivo `nao-mexer.txt` continua `True` (pasta conflitante não foi tocada).

- [ ] **Step 6: Commit**

```bash
git add install.ps1
git commit -m "feat: adiciona install.ps1 (Windows) para bootstrap de máquina"
```

---

## Task 3: Atualizar README.md

**Files:**
- Modify: `README.md`

**Interfaces:**
- Nenhuma (documentação).

- [ ] **Step 1: Atualizar a seção "Setup — usuário novo (Claude Code)"**

Usando o Edit tool, substituir (texto atual, linhas 17-57 do README):

```
## Setup — usuário novo (Claude Code)

Se você acabou de receber este repositório e usa Claude Code, estes são os
**únicos passos** necessários para sair do zero funcionando. Rode nesta
ordem:

```bash
# 1. Clone o repositório EXATAMENTE neste caminho — o skill de instalação
#    resolve os templates a partir de ~/agentes-pipeline, fixo, não funciona
#    em outro lugar.
git clone <url-deste-repo> ~/agentes-pipeline

# 2. Instale o plugin Superpowers (dentro do Claude Code)
/plugin install superpowers@claude-plugins-official

# 3. Linke o skill de instalação para o seu ~/.claude pessoal
#    (symlink em vez de cópia: um "git pull" no repo já deixa o skill
#    atualizado, sem passo manual extra)
ln -s ~/agentes-pipeline/claude/skills/init-project ~/.claude/skills/init-project

# 4. Dentro do projeto onde você quer os agentes, rode /init-project
cd /caminho/do/seu/projeto
/init-project
```

Pronto — o projeto agora tem `./agentes/` (as 11 personas),
`./.claude/commands/orquestrador*.md` e `./.claude/skills/coding-standards/`
(convenção de código sempre em inglês, ativa em qualquer sessão do Claude Code
neste projeto — com ou sem o pipeline rodando). Para usar:

```
/orquestrador quero adicionar autenticação JWT ao projeto
```

Quer usar num segundo projeto? Repita só o passo 4 — os passos 1-3 são
únicos por máquina. Para atualizar o pipeline depois de um `git pull` num
projeto já instalado, veja [Atualizando o pipeline](#atualizando-o-pipeline).

Usa Antigravity/Gemini CLI em vez de Claude Code? Veja
[Pré-requisitos por ferramenta](#pré-requisitos-por-ferramenta) e
[Como instalar num projeto](#como-instalar-num-projeto) abaixo.
```

por:

```
## Setup — usuário novo (Claude Code)

Se você acabou de receber este repositório e usa Claude Code, estes são os
**únicos passos** necessários para sair do zero funcionando. Rode nesta
ordem:

```bash
# 1. Clone o repositório (qualquer pasta — não precisa mais ser um path fixo)
git clone <url-deste-repo> ~/agentes-pipeline
cd ~/agentes-pipeline

# 2. Rode o instalador da sua plataforma. Ele linka o repo em
#    ~/agentes-pipeline (se você clonou em outro lugar), linka o skill
#    de instalação em ~/.claude/skills/init-project, e prepara o plugin
#    Superpowers-Antigravity se você usar Antigravity/Gemini CLI.
./install.sh          # Mac/Linux
.\install.ps1          # Windows (PowerShell)

# 3. Instale o plugin Superpowers do Claude Code (dentro do Claude Code —
#    não dá pra automatizar isso via shell)
/plugin install superpowers@claude-plugins-official

# 4. Dentro do projeto onde você quer os agentes, rode /init-project
cd /caminho/do/seu/projeto
/init-project
```

Pronto — o projeto agora tem `./agentes/` (as 11 personas),
`./.claude/commands/orquestrador*.md` e `./.claude/skills/coding-standards/`
(convenção de código sempre em inglês, ativa em qualquer sessão do Claude Code
neste projeto — com ou sem o pipeline rodando). Para usar:

```
/orquestrador quero adicionar autenticação JWT ao projeto
```

Quer usar num segundo projeto? Repita só o passo 4 — os passos 1-3 são
únicos por máquina. Para atualizar o pipeline depois de um `git pull` num
projeto já instalado, veja [Atualizando o pipeline](#atualizando-o-pipeline).
Já rodou o instalador antes e só quer confirmar que os links continuam
corretos (ex.: depois de mover a pasta do repo)? Rode `./install.sh` ou
`.\install.ps1` de novo — é seguro, não duplica nada.

Usa mais de um perfil de configuração do Claude Code na mesma máquina (ex.:
`~/.claude-work`, além do `~/.claude` padrão — veja
[`claude/continuidade/`](claude/continuidade/README.md))? Rode o instalador
de novo passando `--target`/`-Target` pra cada perfil adicional:

```bash
./install.sh --target ~/.claude-work          # Mac/Linux
.\install.ps1 -Target ~/.claude-work           # Windows (PowerShell)
```

Usa Antigravity/Gemini CLI em vez de Claude Code? Veja
[Pré-requisitos por ferramenta](#pré-requisitos-por-ferramenta) e
[Como instalar num projeto](#como-instalar-num-projeto) abaixo.
```

- [ ] **Step 2: Adicionar `install.sh`/`install.ps1` na árvore da seção "Estrutura"**

Usando o Edit tool, substituir:

```
agentes-pipeline/
├── README.md               ← este arquivo
├── AGENTS.md               ← contexto para IA sem histórico de conversa
│
├── agentes/                ← templates instalados em projetos (formato Claude)
```

por:

```
agentes-pipeline/
├── README.md               ← este arquivo
├── AGENTS.md               ← contexto para IA sem histórico de conversa
├── install.sh               ← instalador de máquina (Mac/Linux)
├── install.ps1               ← instalador de máquina (Windows)
│
├── agentes/                ← templates instalados em projetos (formato Claude)
```

- [ ] **Step 3: Atualizar a subseção Antigravity de "Pré-requisitos por ferramenta"**

Usando o Edit tool, substituir:

```
Em seguida, instale o **Superpowers para Antigravity**:

```bash
git clone https://github.com/roundpilot/superpowers-antigravity \
  ~/.gemini/config/plugins/superpowers

# Ou via gerenciador de plugins (se disponível):
agy plugin install superpowers
```
```

por:

```
O plugin **Superpowers para Antigravity** é clonado automaticamente pelo
`./install.sh` / `.\install.ps1` (veja [Setup — usuário novo](#setup--usuário-novo-claude--claude-code)),
em `~/.gemini/config/plugins/superpowers`. Se preferir instalar manualmente:

```bash
git clone https://github.com/roundpilot/superpowers-antigravity \
  ~/.gemini/config/plugins/superpowers

# Ou via gerenciador de plugins (se disponível):
agy plugin install superpowers
```
```

- [ ] **Step 4: Atualizar a seção "Sincronizar em outra máquina"**

Usando o Edit tool, substituir (texto atual, linhas 214-249 do README):

```
## Sincronizar em outra máquina

Setup completo numa máquina nova:

```bash
# ── CLAUDE / CLAUDE CODE (ver passo a passo comentado em
#    "Setup — usuário novo" no topo deste README) ────────────
# 1. Instalar o plugin Superpowers no Claude Code
/plugin install superpowers@claude-plugins-official

# 2. Clonar este repositório
git clone <url-deste-repo> ~/agentes-pipeline

# 3. Linkar o skill de instalação
ln -s ~/agentes-pipeline/claude/skills/init-project ~/.claude/skills/init-project

# 4. Instalar os agentes num projeto
cd /caminho/do/projeto
/init-project


# ── ANTIGRAVITY (GEMINI CLI) ──────────────────────────────
# 1. Instalar o Antigravity CLI
npm install -g @google/antigravity

# 2. Instalar o plugin Superpowers
git clone https://github.com/roundpilot/superpowers-antigravity \
  ~/.gemini/config/plugins/superpowers

# 3. Clonar este repositório (se ainda não fez)
git clone <url-deste-repo> ~/agentes-pipeline

# 4. Instalar os skills num projeto
mkdir -p /caminho/do/projeto/.agents
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/
```
```

por:

```
## Sincronizar em outra máquina

Setup completo numa máquina nova:

```bash
# 1. Clonar este repositório (qualquer pasta)
git clone <url-deste-repo> ~/agentes-pipeline
cd ~/agentes-pipeline

# 2. Rodar o instalador — linka o repo, o skill init-project (Claude) e
#    o plugin Superpowers-Antigravity (se usar Antigravity/Gemini CLI).
#    Usa mais de um perfil do Claude Code? Rode de novo com
#    --target/-Target <pasta-do-perfil> pra cada perfil adicional.
./install.sh          # Mac/Linux
.\install.ps1          # Windows (PowerShell)

# ── CLAUDE / CLAUDE CODE ──────────────────────────────────
# 3. Instalar o plugin Superpowers no Claude Code
/plugin install superpowers@claude-plugins-official

# 4. Instalar os agentes num projeto
cd /caminho/do/projeto
/init-project


# ── ANTIGRAVITY (GEMINI CLI) ──────────────────────────────
# 3. Instalar o Antigravity CLI (se ainda não tiver)
npm install -g @google/antigravity

# 4. Instalar os skills num projeto
mkdir -p /caminho/do/projeto/.agents
cp -R ~/agentes-pipeline/gemini/skills /caminho/do/projeto/.agents/
```
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: documenta install.sh/install.ps1 no README"
```

---

## Self-Review Notes (already applied above)

- Cobertura do spec: link de `~/agentes-pipeline` (Task 1/2 Step 1), `--target`/`-Target` opcional com default `~/.claude` pro link do skill (Task 1 Step 1/3, Task 2 Step 1/4), clone condicional do plugin Antigravity (idem), lembretes não-automatizáveis (idem), idempotência (Task 1 Step 4, Task 2 Steps 2-3), proteção contra conflito (Task 1 Step 4, Task 2 Step 5), múltiplos perfis coexistindo sem conflito (Task 1 Step 1 cenário `--target`, Task 2 Step 4), README (Task 3, incluindo a nota de `--target` pra múltiplos perfis) — todos cobertos.
- Sem placeholders: todo código é literal, nenhum "TODO"/"implementar depois".
- Consistência de nomes: `AGENTES_PIPELINE_SKIP_ANTIGRAVITY` usado igual em `install.sh` (env var bash) e `install.ps1` (`$env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY`); `--target`/`-Target` com o mesmo default (`~/.claude`) e mesmo efeito (só o link do skill) nos dois scripts; mensagens `OK:`/`ERRO:`/`AVISO:` com o mesmo prefixo nos dois scripts, checadas pelo teste do Task 1 e pela verificação manual do Task 2. Renomeei o parâmetro interno de `Ensure-Junction` de `-Target` pra `-LinkTarget` no `install.ps1` pra não colidir em nome com o `-Target` de nível de script (perfil) — mesmo efeito, sem ambiguidade de leitura.
