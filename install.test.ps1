# Regression suite for install.ps1's Read-AiTargetSelection.
#
# The function under test is extracted from the REAL install.ps1 via the
# PowerShell AST and evaluated here - never copied by hand - so a regression in
# production source fails this suite instead of a frozen snapshot of it.
#
# Run: pwsh -NoProfile -File install.test.ps1   (exit 0 = all green, 1 = failure)

$ErrorActionPreference = "Stop"

$Installer = Join-Path $PSScriptRoot "install.ps1"
$ShInstaller = Join-Path $PSScriptRoot "install.sh"

$script:Pass = 0
$script:Fail = 0
$script:Skip = 0

function Assert-True([bool]$Condition, [string]$Label) {
    if ($Condition) {
        $script:Pass++
        Write-Host "PASS: $Label"
    } else {
        $script:Fail++
        Write-Host "FAIL: $Label"
    }
}

function Write-Skip([string]$Label) {
    $script:Skip++
    Write-Host "SKIP: $Label"
}

# ---------------------------------------------------------------------------
# static analysis: install.ps1 parses, and the function still exists
# ---------------------------------------------------------------------------
Write-Host "--- install.ps1 source integrity ---"

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Installer, [ref]$tokens, [ref]$errors)
Assert-True (@($errors).Count -eq 0) "install.ps1 parses with no syntax errors (found $(@($errors).Count))"
if (@($errors).Count -gt 0) {
    $errors | ForEach-Object { Write-Host "      $_" }
    Write-Host "ABORT: nao da pra testar uma fonte que nao parseia."
    exit 1
}

$functionAsts = @{}
foreach ($f in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    $functionAsts[$f.Name] = $f
}

$requiredFunctions = @("Test-AiTarget", "Get-NormalizedAiTargets", "Read-AiTargetSelection")
foreach ($name in $requiredFunctions) {
    Assert-True ($functionAsts.ContainsKey($name)) "install.ps1 defines $name"
}
if ($requiredFunctions | Where-Object { -not $functionAsts.ContainsKey($_) }) {
    Write-Host "ABORT: faltam funcoes essenciais em install.ps1."
    exit 1
}

# ---------------------------------------------------------------------------
# output-channel leak detection
#
# Read-AiTargetSelection returns its value through the output pipeline, so any
# statement that emits to stdout (a stray Write-Output, a bare expression) would
# be appended to the returned array of ai ids. That bug shipped once; this check
# exists to catch the whole class, not just that one occurrence.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- output channel purity ---"

$selectionAst = $functionAsts['Read-AiTargetSelection']

$invokedCommands = $selectionAst.Body.FindAll(
    { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
    ForEach-Object { $_.GetCommandName() } | Where-Object { $_ }
Assert-True (@($invokedCommands | Where-Object { $_ -eq 'Write-Output' }).Count -eq 0) `
    "Read-AiTargetSelection calls no Write-Output (screen text must use Write-Host)"

# A pipeline statement can only reach the output stream when its immediate
# parent is a statement block AND no enclosing node consumes its value.
$valueConsumers = @(
    'ArrayExpressionAst', 'SubExpressionAst', 'ScriptBlockExpressionAst', 'ParenExpressionAst',
    'ExpandableStringExpressionAst', 'AssignmentStatementAst', 'CommandAst', 'InvokeMemberExpressionAst'
)

function Find-LeakingStatements($FunctionAst) {
    $leaks = @()
    foreach ($statement in $FunctionAst.Body.FindAll(
            { $args[0] -is [System.Management.Automation.Language.PipelineAst] }, $true)) {
        if ($statement.Parent -isnot [System.Management.Automation.Language.StatementBlockAst] -and
            $statement.Parent -isnot [System.Management.Automation.Language.NamedBlockAst]) { continue }

        $consumed = $false
        $node = $statement.Parent
        while ($null -ne $node -and $node -ne $FunctionAst.Body) {
            if ($valueConsumers -contains $node.GetType().Name) { $consumed = $true; break }
            $node = $node.Parent
        }
        if ($consumed) { continue }

        $text = $statement.Extent.Text
        if ($text -notmatch '^\s*(Write-Host|return|break|continue)\b') {
            $leaks += "L$($statement.Extent.StartLineNumber): $text"
        }
    }
    return $leaks
}

$leaks = @(Find-LeakingStatements $selectionAst)
Assert-True ($leaks.Count -eq 0) "no unconsumed pipeline statement leaks into the return channel: $($leaks -join ' | ')"

# Negative control: without it, the assertion above would pass vacuously if the
# detection rule itself broke.
$leakyControlSource = @'
function Ctl-Leaky([string[]]$P) {
    $x = @("a","b")
    for ($i = 1; $i -le 3; $i++) {
        Write-Host "safe"
        Write-Output "PLANTED-LEAK"
        $m = if ($P -contains "a") { "x" } else { " " }
        foreach ($t in ($P | Where-Object { $_ -ne "" })) { $y = $t }
    }
    return $P
}
'@
$controlAst = [System.Management.Automation.Language.Parser]::ParseInput($leakyControlSource, [ref]$null, [ref]$null)
$controlFunction = $controlAst.FindAll(
    { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)[0]
$controlLeaks = @(Find-LeakingStatements $controlFunction)
Assert-True ($controlLeaks.Count -eq 1 -and $controlLeaks[0] -match 'PLANTED-LEAK') `
    "negative control: the leak rule flags a deliberately leaky function (found $($controlLeaks.Count): $($controlLeaks -join ' | '))"

# ---------------------------------------------------------------------------
# load the real definitions into this scope
# ---------------------------------------------------------------------------
foreach ($name in $requiredFunctions) {
    Invoke-Expression $functionAsts[$name].Extent.Text
}

# $AiTargetsKnown comes from the real assignment too, so a changed id list is
# picked up here instead of drifting against a hardcoded copy.
$knownAssignment = $ast.FindAll(
    { $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
    Where-Object { $_.Left.Extent.Text -eq '$AiTargetsKnown' } | Select-Object -First 1
Assert-True ($null -ne $knownAssignment) 'install.ps1 assigns $AiTargetsKnown'
if ($null -eq $knownAssignment) {
    Write-Host 'ABORT: sem $AiTargetsKnown nao da pra rodar os casos.'
    exit 1
}
Invoke-Expression $knownAssignment.Extent.Text
Assert-True ((@($AiTargetsKnown) -join ',') -eq 'claude,antigravity,codex,cursor') `
    "canonical ai id order is claude,antigravity,codex,cursor (got $(@($AiTargetsKnown) -join ','))"

# ---------------------------------------------------------------------------
# Read-Host mock: feeds a queued answer per menu attempt, and fails loudly when
# the function asks for more input than the case expects.
# ---------------------------------------------------------------------------
$script:InputQueue = @()
$script:ReadHostCalls = 0

function Read-Host {
    param([Parameter(Position = 0)][string]$Prompt)
    if ($script:ReadHostCalls -ge @($script:InputQueue).Count) {
        throw "mock Read-Host: input queue exhausted on call $($script:ReadHostCalls + 1)"
    }
    $value = @($script:InputQueue)[$script:ReadHostCalls]
    $script:ReadHostCalls++
    return $value
}

# Anything from the menu, the error line or the warning line that ends up inside
# the returned array is contamination of the return channel.
$MenuGarbagePattern = '\[|Quais|ERRO|AVISO|Numeros|sempre instalado'

function Invoke-SelectionCase {
    param(
        [string]$Label,
        [string[]]$Inputs,
        [string[]]$Preselected,
        [string]$ExpectedIds,
        [int]$ExpectedReadHostCalls
    )

    $script:InputQueue = $Inputs
    $script:ReadHostCalls = 0

    $result = @(Read-AiTargetSelection $Preselected)
    $joined = $result -join ','
    $garbage = @($result | Where-Object { $_ -match $MenuGarbagePattern })
    $unknown = @($result | Where-Object { $AiTargetsKnown -notcontains $_ })

    $ok = ($joined -eq $ExpectedIds) -and
          ($garbage.Count -eq 0) -and
          ($unknown.Count -eq 0) -and
          ($script:ReadHostCalls -eq $ExpectedReadHostCalls)

    Assert-True $ok ("$Label -> [$joined] ({0} calls)" -f $script:ReadHostCalls)
    if (-not $ok) {
        Write-Host ("      expected [$ExpectedIds] in $ExpectedReadHostCalls call(s); menu garbage: {0}; non-ai entries: {1}" -f `
            $garbage.Count, $unknown.Count)
    }
}

Write-Host ""
Write-Host "--- Read-AiTargetSelection behaviour ---"

# Core paths.
Invoke-SelectionCase "empty Enter keeps the preselection" `
    @("") @("claude", "antigravity", "cursor") "claude,antigravity,cursor" 1
Invoke-SelectionCase "explicit valid choice '2 4'" `
    @("2 4") @("claude") "claude,antigravity,cursor" 1
Invoke-SelectionCase "single valid choice '3' replaces the preselection" `
    @("3") @("claude", "cursor") "claude,codex" 1
Invoke-SelectionCase "invalid token then recovery on the second attempt" `
    @("9", "3") @("claude") "claude,codex" 2
Invoke-SelectionCase "three invalid attempts fall back to the preselection" `
    @("9", "abc", "0") @("claude", "codex") "claude,codex" 3
Invoke-SelectionCase "partially valid input '2 9' is rejected all three times" `
    @("2 9", "2 9", "2 9") @("claude", "cursor") "claude,cursor" 3

# Separator-only input: must never silently drop the preselection. install.sh
# turns commas into spaces and treats the result as an empty answer, so the
# PowerShell menu keeps the preselection in a single read, same as Enter.
Invoke-SelectionCase "separator-only ',' keeps the preselection" `
    @(",") @("claude", "codex", "cursor") "claude,codex,cursor" 1
Invoke-SelectionCase "separator-only ',,' keeps the preselection" `
    @(",,") @("claude", "codex", "cursor") "claude,codex,cursor" 1
Invoke-SelectionCase "separator-only ' , ' keeps the preselection" `
    @(" , ") @("claude", "antigravity") "claude,antigravity" 1
Invoke-SelectionCase "whitespace-only input keeps the preselection" `
    @("   ") @("claude", "cursor") "claude,cursor" 1
Invoke-SelectionCase "',;' is not separator-only and stays an invalid answer" `
    @(",;", ",;", ",;") @("claude", "cursor") "claude,cursor" 3

# Formatting variations.
Invoke-SelectionCase "extra spaces around the comma ' 2 , 4 '" `
    @(" 2 , 4 ") @("claude") "claude,antigravity,cursor" 1
Invoke-SelectionCase "comma without spaces '2,4'" `
    @("2,4") @("claude") "claude,antigravity,cursor" 1
Invoke-SelectionCase "trailing comma '2,4,'" `
    @("2,4,") @("claude") "claude,antigravity,cursor" 1
Invoke-SelectionCase "leading comma ',2,4'" `
    @(",2,4") @("claude") "claude,antigravity,cursor" 1
Invoke-SelectionCase "tab as separator '2<TAB>4'" `
    @("2`t4") @("claude") "claude,antigravity,cursor" 1
Invoke-SelectionCase "trailing CR from a CRLF paste" `
    @("2 4`r") @("claude") "claude,antigravity,cursor" 1
Invoke-SelectionCase "duplicates '2 2 2' are collapsed" `
    @("2 2 2") @("claude") "claude,antigravity" 1
Invoke-SelectionCase "out of order '4 2' is returned in canonical order" `
    @("4 2") @("claude") "claude,antigravity,cursor" 1
Invoke-SelectionCase "all options '1 2 3 4'" `
    @("1 2 3 4") @("claude") "claude,antigravity,codex,cursor" 1
Invoke-SelectionCase "'04' is not 4 - the digit regex is anchored" `
    @("04", "04", "04") @("claude", "cursor") "claude,cursor" 3
Invoke-SelectionCase "negative '-1' is rejected" `
    @("-1", "-1", "-1") @("claude", "cursor") "claude,cursor" 3

# ---------------------------------------------------------------------------
# the menu itself must still reach the user (information stream, not stdout)
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- menu is still displayed ---"

$script:InputQueue = @("2")
$script:ReadHostCalls = 0
$merged = Read-AiTargetSelection @("claude") 6>&1
$mergedText = ($merged | ForEach-Object { "$_" }) -join "`n"
Assert-True ($mergedText -match 'Quais IAs voce usa') "menu header still reaches the user on the information stream"
Assert-True ($mergedText -match '\[x\] 1\)') "preselection marker [x] is still rendered"

# ---------------------------------------------------------------------------
# parity with install.sh's prompt_ai_targets
#
# Requires Git Bash. Plain `bash` inside pwsh may resolve to WSL, which does not
# see /c or /d drive mounts, so the interpreter is discovered explicitly and the
# whole block is skipped - loudly - when it is absent.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "--- parity with install.sh ---"

function Find-GitBash {
    $candidates = @()
    $candidates += @(Get-Command bash.exe -All -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Source } | Where-Object { $_ -match '[\\/]Git[\\/]' })
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles "Git\bin\bash.exe") }
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} "Git\bin\bash.exe") }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe") }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

# C:\x\y -> /c/x/y. Written without a scriptblock replacement so it also runs on
# Windows PowerShell 5.1, where `-replace` takes no scriptblock.
function ConvertTo-BashPath([string]$WindowsPath) {
    $normalized = $WindowsPath -replace '\\', '/'
    if ($normalized -match '^([A-Za-z]):(.*)$') {
        return "/" + $Matches[1].ToLowerInvariant() + $Matches[2]
    }
    return $normalized
}

$gitBash = Find-GitBash
if (-not $gitBash) {
    Write-Skip "install.sh parity - Git Bash nao encontrado nesta maquina (instale o Git for Windows para rodar este bloco)"
} elseif (-not (Test-Path -LiteralPath $ShInstaller)) {
    Write-Skip "install.sh parity - install.sh nao encontrado em $ShInstaller"
} else {
    # Sources only prompt_ai_targets and its dependencies out of install.sh, so
    # the parity probe never runs the installer's side effects.
    # The answer travels in AI_PARITY_INPUT instead of argv: Windows PowerShell
    # 5.1 drops empty string arguments to native executables, which would silently
    # shift the Enter case.
    $probeScript = @'
#!/usr/bin/env bash
INSTALLER="$1"
eval "$(sed -n '/^validate_ai_target()/,/^}/p;/^normalize_ai_targets()/,/^}/p;/^prompt_ai_targets()/,/^}/p' "$INSTALLER")"
AI_TARGETS_KNOWN="claude antigravity codex cursor"
printf '%s\n%s\n%s\n' "$AI_PARITY_INPUT" "$AI_PARITY_INPUT" "$AI_PARITY_INPUT" | prompt_ai_targets "$2" 2>/dev/null
'@
    $probePath = Join-Path ([System.IO.Path]::GetTempPath()) ("install-parity-" + [guid]::NewGuid().ToString("N") + ".sh")
    [System.IO.File]::WriteAllText($probePath, ($probeScript -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))

    try {
        $probeBashPath = ConvertTo-BashPath $probePath
        $installerBashPath = ConvertTo-BashPath $ShInstaller
        $preselected = @("claude", "codex", "cursor")

        foreach ($probeInput in @(",", ",,", " , ", ",;", "2 4", "3", "9", "", ",`t,", " ,`t, ")) {
            $script:InputQueue = @($probeInput, $probeInput, $probeInput)
            $script:ReadHostCalls = 0
            $psResult = @(Read-AiTargetSelection $preselected)
            $psJoined = $psResult -join ' '
            $env:AI_PARITY_INPUT = $probeInput
            $shJoined = (& $gitBash $probeBashPath $installerBashPath ($preselected -join ' ') | Out-String).Trim()
            Remove-Item Env:\AI_PARITY_INPUT -ErrorAction SilentlyContinue

            $shown = if ($probeInput -eq "") { "<Enter>" } else { $probeInput }
            Assert-True (@($psResult | Where-Object { $_ -match $MenuGarbagePattern }).Count -eq 0) `
                "input '$shown' returns no menu text"
            Assert-True ($psJoined -eq $shJoined) `
                "install.ps1 and install.sh agree on input '$shown' (ps1='$psJoined' sh='$shJoined')"
        }
    } finally {
        Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "================ PASS: $script:Pass | FAIL: $script:Fail | SKIP: $script:Skip ================"
if ($script:Fail -gt 0) {
    Write-Host "ALGUM TESTE FALHOU"
    exit 1
}
Write-Host "TODOS OS TESTES PASSARAM"
exit 0
