param(
    [Parameter(Mandatory = $true)]
    [string]$Target
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoreDir = Join-Path $ScriptDir "core"
$QueueHome = if ($env:CLAUDE_CONTINUIDADE_HOME) { $env:CLAUDE_CONTINUIDADE_HOME } else { Join-Path $env:USERPROFILE ".claude-resume-queue" }

New-Item -ItemType Directory -Force -Path (Join-Path $Target "hooks\continuidade") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Target "skills") | Out-Null

# 1. instalação compartilhada do watcher (uma vez por máquina)
$WatcherBinDir = Join-Path $QueueHome "bin"
New-Item -ItemType Directory -Force -Path $WatcherBinDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $QueueHome "stale") | Out-Null
Copy-Item -Path (Join-Path $CoreDir "watcher.js") -Destination (Join-Path $WatcherBinDir "watcher.js") -Force
Remove-Item -Path (Join-Path $WatcherBinDir "lib") -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $CoreDir "lib") -Destination $WatcherBinDir -Recurse -Force

$TaskName = "AgentesPipelineContinuidadeWatcher"
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $ExistingTask) {
    $NodePath = (Get-Command node).Source
    $WatcherScript = Join-Path $WatcherBinDir "watcher.js"
    $Action = New-ScheduledTaskAction -Execute $NodePath -Argument "`"$WatcherScript`""
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::MaxValue)
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Description "Retoma sessoes do Claude Code interrompidas por rate limit/erro" | Out-Null
    Write-Output "watcher agendado registrado: tarefa '$TaskName' a cada 15min"
} else {
    Write-Output "watcher compartilhado ja presente (tarefa '$TaskName'), nao recriado"
}

# 2. copia queue.js (hook de enfileiramento) e state.js pro alvo
Copy-Item -Path (Join-Path $CoreDir "queue.js") -Destination (Join-Path $Target "hooks\continuidade\queue.js") -Force
Copy-Item -Path (Join-Path $CoreDir "state.js") -Destination (Join-Path $Target "hooks\continuidade\state.js") -Force
Remove-Item -Path (Join-Path $Target "hooks\continuidade\lib") -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $CoreDir "lib") -Destination (Join-Path $Target "hooks\continuidade") -Recurse -Force

# 3. mescla o hook StopFailure no settings.json do alvo
$SettingsPath = Join-Path $Target "settings.json"
$QueueScriptPath = Join-Path $Target "hooks\continuidade\queue.js"
$QueueCmd = "node `"$QueueScriptPath`""
$MergeScript = Join-Path $CoreDir "lib\merge-settings.js"
# String vazia literal como '""' evita que o PowerShell 5.1 descarte silenciosamente um argumento vazio antes de repassá-lo
node $MergeScript $SettingsPath "StopFailure" '""' $QueueCmd 10

# 4. copia os skills de pausar/continuar
Remove-Item -Path (Join-Path $Target "skills\pausar-trabalho") -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $ScriptDir "skills\pausar-trabalho") -Destination (Join-Path $Target "skills\pausar-trabalho") -Recurse -Force
Remove-Item -Path (Join-Path $Target "skills\continuar-trabalho") -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path (Join-Path $ScriptDir "skills\continuar-trabalho") -Destination (Join-Path $Target "skills\continuar-trabalho") -Recurse -Force

Write-Output "instalado em $Target`:"
Write-Output "  - hook StopFailure -> $QueueScriptPath"
Write-Output "  - skills /pausar-trabalho e /continuar-trabalho"
Write-Output "  - watcher compartilhado em $(Join-Path $WatcherBinDir 'watcher.js')"
