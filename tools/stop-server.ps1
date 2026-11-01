. "$PSScriptRoot\common.ps1"

foreach ($name in 'mangosd', 'realmd') {
    foreach ($proc in Get-Process $name -ErrorAction SilentlyContinue) {
        Write-Host "Stopping $name..."
        Stop-ServerProcess $proc
    }
    Close-ServerConsole $name
}

$runArchive = Join-Path $PSScriptRoot 'run-archive.py'
$python = Get-Python
if ($python -and (Test-Path $runArchive)) {
    & $python $runArchive save
    if ($LASTEXITCODE -ne 0) { Write-Host "Saving runs to data\runs failed with exit code $LASTEXITCODE" }
}

if (Test-DbUp) {
    Write-Host 'Stopping MariaDB...'
    & (Get-MariaProgram 'mariadb-admin') @DbRootArgs shutdown
    if ($LASTEXITCODE -ne 0) { throw "mariadb-admin shutdown failed with exit code $LASTEXITCODE." }
}
if (-not $OnWindows) {
    Wait-Until { -not (Get-Process mariadbd -ErrorAction SilentlyContinue) } 60 'MariaDB to exit'
    Close-ServerConsole 'mariadbd'
}

Write-Host 'Server stopped'
