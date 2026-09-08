param(
    [string]$Target = (Join-Path $env:USERPROFILE ".claude"),
    [string]$Ai = ""
)

$ErrorActionPreference = "Stop"

function Resolve-RealPath([string]$Path) {
    $current = (Resolve-Path -LiteralPath $Path).Path
    while ($true) {
        $item = Get-Item -LiteralPath $current -Force
        if ($item.LinkType) {
            $current = (@($item.Target)[0])
        } else {
            break
        }
    }
    return $current.TrimEnd('\')
}

$RepoDir = Resolve-RealPath $PSScriptRoot
$PipelineHome = Join-Path $env:USERPROFILE "agentes-pipeline"
$SkillLink = Join-Path $Target "skills\init-project"
$SkillTarget = Join-Path $RepoDir "claude\skills\init-project"
$AntigravityPluginDir = Join-Path $env:USERPROFILE ".gemini\config\plugins\superpowers"
$AntigravityPluginUrl = "https://github.com/roundpilot/superpowers-antigravity"

# ai-targets config contract - see the header comment in install.sh for the
# full specification. Same file, same format, same canonical order; only
# `updatedBy` differs.
$AiConfigDir = Join-Path $env:USERPROFILE ".config\agentes-pipeline"
$AiConfigFile = Join-Path $AiConfigDir "ai-targets.json"
$AiTargetsKnown = @("claude", "antigravity", "codex", "cursor")   # canonical order
$script:AiTargets = @()

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

    $targetResolved = Resolve-FullPath $LinkTarget

    if (Test-Path -LiteralPath $Link) {
        $item = Get-Item -LiteralPath $Link -Force
        if ($item.LinkType -eq "Junction") {
            $currentTarget = (@($item.Target)[0]).TrimEnd('\')
            if ($currentTarget -eq $targetResolved) {
                Write-Output "OK: $Label ja linkado corretamente ($Link -> $LinkTarget)"
            } else {
                Write-Output "ERRO: $Label existe em $Link mas aponta pra outro lugar ($currentTarget, esperado $targetResolved). Resolva manualmente antes de rodar de novo."
                $script:Fail = $true
            }
        } elseif ((Resolve-FullPath $Link) -eq $targetResolved) {
            Write-Output "OK: $Label ja e o proprio $LinkTarget - nenhuma junction necessaria"
        } else {
            Write-Output "ERRO: $Label existe em $Link mas nao e uma junction (e uma pasta/arquivo real). Resolva manualmente (mova ou remova) antes de rodar de novo."
            $script:Fail = $true
        }
        return
    }

    New-Item -ItemType Junction -Path $Link -Target $LinkTarget | Out-Null
    Write-Output "OK: $Label linkado ($Link -> $LinkTarget)"
}

function Show-AiUsage() {
    Write-Output "uso: install.ps1 [-Target <pasta-de-perfil>] [-Ai <lista>]"
    Write-Output "  ex: install.ps1 -Target ~/.claude-work"
    Write-Output "  -Ai: claude,antigravity,codex,cursor (separados por virgula; claude e sempre incluido)"
}

function Test-AiTarget([string]$Id) {
    return $AiTargetsKnown -contains $Id
}

# Canonical order, deduplicated, `claude` always injected.
# Without -Tolerant an unknown id throws; with -Tolerant it is discarded.
function Get-NormalizedAiTargets([string]$Raw, [switch]$Tolerant) {
    $requested = @()
    if ($Raw) {
        $tokens = $Raw -split '[,\s]+' | Where-Object { $_ -ne "" }
        foreach ($token in $tokens) {
            $id = $token.Trim().ToLowerInvariant()
            if (-not (Test-AiTarget $id)) {
                if ($Tolerant) { continue }
                throw "IA desconhecida: '$id'. Validas: $($AiTargetsKnown -join ', ')"
            }
            $requested += $id
        }
    }

    $result = @()
    foreach ($known in $AiTargetsKnown) {
        if ($known -eq "claude" -or $requested -contains $known) {
            $result += $known
        }
    }
    return $result
}

# Never fails: a missing or malformed config falls back to @("claude").
function Read-PersistedAiTargets() {
    try {
        if (-not (Test-Path -LiteralPath $AiConfigFile)) { return @("claude") }
        $raw = Get-Content -LiteralPath $AiConfigFile -Raw
        $parsed = $raw | ConvertFrom-Json
        $stored = @($parsed.aiTargets) | Where-Object { $_ } | ForEach-Object { ([string]$_).Replace("`r", "").Trim() }
        return Get-NormalizedAiTargets ($stored -join ",") -Tolerant
    } catch {
        return @("claude")
    }
}

function Read-AiTargetSelection([string[]]$Preselected) {
    $labels = @(
        "Claude Code               (sempre instalado)",
        "Antigravity / Gemini CLI",
        "Codex CLI (OpenAI)",
        "Cursor"
    )

    # Screen text goes to Write-Host on purpose: this function's output pipeline
    # is its return value (see the `$script:AiTargets = Read-AiTargetSelection`
    # call site), so any Write-Output here would be appended to the returned
    # array of ai ids. Mirrors the `{ ... } >&2` pattern in install.sh.
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host ""
        Write-Host "Quais IAs voce usa nesta maquina?"
        for ($index = 0; $index -lt 4; $index++) {
            $mark = if ($Preselected -contains $AiTargetsKnown[$index]) { "x" } else { " " }
            Write-Host ("  [{0}] {1}) {2}" -f $mark, ($index + 1), $labels[$index])
        }
        Write-Host ""

        $answer = Read-Host "Numeros separados por espaco ou virgula (ex: 2 4), ou Enter para manter"
        $answer = ([string]$answer).Replace("`r", "").Trim()

        # Mirrors install.sh (commas become spaces, then `${answer// /}`): an
        # answer made only of separators counts as empty, so the preselection is
        # kept instead of being silently replaced by the default.
        if (($answer -replace '[,\s]', '') -eq "") { return $Preselected }

        $valid = $true
        $selected = @()
        foreach ($token in ($answer -split '[,\s]+' | Where-Object { $_ -ne "" })) {
            if ($token -match '^[1-4]$') {
                $selected += $AiTargetsKnown[[int]$token - 1]
            } else {
                $valid = $false
                Write-Host "ERRO: '$token' nao e uma opcao valida (use numeros de 1 a 4)."
                break
            }
        }

        if ($valid) { return Get-NormalizedAiTargets ($selected -join ",") -Tolerant }
    }

    Write-Host "AVISO: entrada invalida 3 vezes - mantendo a selecao anterior: $($Preselected -join ', ')"
    return $Preselected
}

function Resolve-AiTargets() {
    # `throw` under $ErrorActionPreference = "Stop" exits with 1, not 2, so an
    # invalid -Ai / env value needs an explicit `exit 2`.
    if ($Ai) {
        try {
            $script:AiTargets = Get-NormalizedAiTargets $Ai
        } catch {
            Write-Output "ERRO: valor invalido em -Ai: '$Ai' - $($_.Exception.Message)"
            Show-AiUsage
            exit 2
        }
        return
    }

    if ($env:AGENTES_PIPELINE_AI_TARGETS) {
        try {
            $script:AiTargets = Get-NormalizedAiTargets $env:AGENTES_PIPELINE_AI_TARGETS
        } catch {
            Write-Output "ERRO: valor invalido em AGENTES_PIPELINE_AI_TARGETS: '$($env:AGENTES_PIPELINE_AI_TARGETS)' - $($_.Exception.Message)"
            Show-AiUsage
            exit 2
        }
        return
    }

    # IsInputRedirected is $true under a pipe/redirect; UserInteractive is not
    # a reliable TTY signal here.
    if (-not [Console]::IsInputRedirected) {
        $script:AiTargets = Read-AiTargetSelection (Read-PersistedAiTargets)
        return
    }

    $script:AiTargets = Read-PersistedAiTargets
    Write-Output "AVISO: stdin nao e um terminal - usando selecao de IAs: $($script:AiTargets -join ', ') (mude com -Ai ou AGENTES_PIPELINE_AI_TARGETS)"
}

function Save-AiTargets() {
    if (-not (Test-Path -LiteralPath $AiConfigDir)) {
        New-Item -ItemType Directory -Force -Path $AiConfigDir | Out-Null
    }

    $targetsJson = ($script:AiTargets | ForEach-Object { '"' + $_ + '"' }) -join ", "
    $updatedAt = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $json = @"
{
  "version": 1,
  "aiTargets": [$targetsJson],
  "updatedAt": "$updatedAt",
  "updatedBy": "install.ps1"
}
"@
    # UTF-8 without BOM, so the bash reader never trips on a leading marker.
    $json = $json.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($AiConfigFile, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Test-AiTargetSelected([string]$Id) {
    return $script:AiTargets -contains $Id
}

# Persisted before the junctions and independently of $script:Fail: the
# selection is the user's declared intent and must not be lost.
Resolve-AiTargets
Save-AiTargets
Write-Output "OK: IAs selecionadas: $($script:AiTargets -join ', ') (registrado em $AiConfigFile)"

Ensure-Junction -LinkTarget $RepoDir -Link $PipelineHome -Label "~/agentes-pipeline"
Ensure-Junction -LinkTarget $SkillTarget -Link $SkillLink -Label "skill init-project ($Target)"

if (-not (Test-AiTargetSelected "antigravity")) {
    Write-Output "OK: Antigravity nao selecionado - etapa do plugin Superpowers-Antigravity pulada"
} elseif ($env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY) {
    Write-Output "OK: etapa do plugin Superpowers-Antigravity pulada (AGENTES_PIPELINE_SKIP_ANTIGRAVITY=1)"
} else {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        if (Test-Path -LiteralPath (Join-Path $AntigravityPluginDir ".git")) {
            Write-Output "OK: plugin Superpowers-Antigravity ja presente em $AntigravityPluginDir"
        } else {
            $pluginParent = Split-Path -Parent $AntigravityPluginDir
            New-Item -ItemType Directory -Force -Path $pluginParent | Out-Null
            & git clone $AntigravityPluginUrl $AntigravityPluginDir
            if ($LASTEXITCODE -ne 0) {
                Write-Output "ERRO: falha ao clonar o plugin Superpowers-Antigravity (git clone saiu com codigo $LASTEXITCODE). Resolva manualmente antes de rodar de novo, ou apague $AntigravityPluginDir se o clone ficou parcial."
                $script:Fail = $true
            } else {
                Write-Output "OK: plugin Superpowers-Antigravity clonado em $AntigravityPluginDir"
            }
        }
    } else {
        Write-Output "AVISO: git nao encontrado no PATH - pulei a instalacao do plugin Superpowers-Antigravity. Instale git e rode este script de novo, ou clone manualmente: git clone $AntigravityPluginUrl $AntigravityPluginDir"
    }
}

Write-Output ""
Write-Output "Lembretes (nao automatizaveis por este script):"
Write-Output "  - Dentro do Claude Code, rode: /plugin install superpowers@claude-plugins-official"
$agyCmd = Get-Command agy -ErrorAction SilentlyContinue
if ((Test-AiTargetSelected "antigravity") -and (-not $agyCmd)) {
    Write-Output "  - Antigravity CLI nao encontrado no PATH. Instale com: npm install -g @google/antigravity"
}

if ($script:Fail) {
    exit 1
}
