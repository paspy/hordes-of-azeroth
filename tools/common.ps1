$ErrorActionPreference = 'Stop'

$OnWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
$ExeSuffix = if ($OnWindows) { '.exe' } else { '' }

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $RepoRoot 'config'
$ServerDir = Join-Path $RepoRoot 'server'
$RunDir    = Join-Path $ServerDir 'run'
$DataDir   = Join-Path $ServerDir 'data'
$LogDir    = Join-Path $ServerDir 'logs'
$MariaData = Join-Path $ServerDir 'mariadb-data'

function Find-MariaDir {
    $bundled = Join-Path $ServerDir 'mariadb'
    if ($OnWindows) { return $bundled }
    if ($env:HOA_MARIADB) { return $env:HOA_MARIADB }
    if (Test-Path (Join-Path $bundled 'bin')) { return $bundled }
    $brew = Get-Command brew -ErrorAction SilentlyContinue
    if ($brew) {
        $prefix = & $brew.Source --prefix 'mariadb@11.4' 2>$null
        if ($LASTEXITCODE -eq 0 -and $prefix -and (Test-Path (Join-Path $prefix 'bin'))) { return $prefix }
    }
    return $bundled
}

$MariaDir = Find-MariaDir
$env:HOA_MARIADB = $MariaDir

function Get-Program([string]$Directory, [string]$Name) {
    Join-Path $Directory ($Name + $ExeSuffix)
}

function Get-MariaProgram([string]$Name) {
    Get-Program (Join-Path $MariaDir 'bin') $Name
}

function Get-Python {
    $names = if ($OnWindows) { 'python', 'python3' } else { 'python3', 'python' }
    foreach ($name in $names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch '\\WindowsApps\\' } | Select-Object -First 1
        if ($command) { return $command.Source }
    }
    return $null
}

$DbHost = '127.0.0.1'
$DbPort = 3306
$DbRootArgs = @('--skip-ssl', '-h', $DbHost, '-P', $DbPort, '-u', 'root', '-proot')

function Test-PortOpen([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect($DbHost, $Port)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Test-DbUp { Test-PortOpen $DbPort }

function Start-Quoted([string]$Exe, [string[]]$Arguments, [string]$WorkDir, [string]$WindowStyle = 'Normal') {
    $quoted = $Arguments | ForEach-Object { '"' + $_ + '"' }
    $params = @{ FilePath = $Exe; WorkingDirectory = $WorkDir; PassThru = $true }
    if ($OnWindows) {
        $params.WindowStyle = $WindowStyle
    } elseif ($WindowStyle -eq 'Hidden') {
        $params.RedirectStandardOutput = '/dev/null'
    }
    if ($quoted) { $params.ArgumentList = $quoted }
    Start-Process @params
}

function Get-ConsoleSession([string]$Name) { "hoa-$Name" }

function Close-ServerConsole([string]$Name) {
    if ($OnWindows -or -not (Get-Command tmux -ErrorAction SilentlyContinue)) { return }
    & tmux kill-session -t (Get-ConsoleSession $Name) 2>$null
    $global:LASTEXITCODE = 0
}

function Start-ServerConsole([string]$Exe, [string[]]$Arguments, [string]$WorkDir, [string]$WindowStyle = 'Minimized') {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Exe)
    if ($OnWindows) { return Start-Quoted $Exe $Arguments $WorkDir $WindowStyle }
    $tmux = Get-Command tmux -ErrorAction SilentlyContinue
    if (-not $tmux) { throw 'The server consoles run in tmux on macOS and Linux: install it (brew install tmux).' }
    $session = Get-ConsoleSession $name
    Close-ServerConsole $name
    & $tmux.Source new-session -d -s $session -c $WorkDir
    if ($LASTEXITCODE -ne 0) { throw "tmux could not start $name." }
    & $tmux.Source set-option -t $session remain-on-exit on | Out-Null
    & $tmux.Source respawn-pane -k -t $session -c $WorkDir /usr/bin/env $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "tmux could not start $name." }
    $process = $null
    $deadline = (Get-Date).AddSeconds(5)
    while (-not $process -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
        $process = Get-Process $name -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1
    }
    if (-not $process) { throw "$name exited at once. tmux attach -t $session shows its output." }
    Write-Host "  console: tmux attach -t $session (detach with Ctrl+B, D)"
    return $process
}

function Stop-ServerProcess([System.Diagnostics.Process]$Process, [int]$TimeoutMilliseconds = 20000) {
    if ($OnWindows) {
        $asked = $Process.CloseMainWindow()
    } else {
        & kill -TERM $Process.Id
        $asked = $LASTEXITCODE -eq 0
    }
    if ($asked -and $Process.WaitForExit($TimeoutMilliseconds)) { return }
    Write-Host "$($Process.ProcessName) did not exit in time, killing it"
    $Process.Kill()
    $Process.WaitForExit()
}

function Wait-Until([scriptblock]$Condition, [int]$TimeoutSeconds, [string]$What) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not (& $Condition)) {
        if ((Get-Date) -gt $deadline) { throw "Timed out after ${TimeoutSeconds}s waiting for $What." }
        Start-Sleep -Milliseconds 500
    }
}
