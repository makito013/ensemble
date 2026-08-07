param(
    [string]$Target = (Join-Path $env:USERPROFILE ".claude")
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

Ensure-Junction -LinkTarget $RepoDir -Link $PipelineHome -Label "~/agentes-pipeline"
Ensure-Junction -LinkTarget $SkillTarget -Link $SkillLink -Label "skill init-project ($Target)"

if ($env:AGENTES_PIPELINE_SKIP_ANTIGRAVITY) {
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
if (-not $agyCmd) {
    Write-Output "  - Antigravity CLI nao encontrado no PATH. Instale com: npm install -g @google/antigravity"
}

if ($script:Fail) {
    exit 1
}
