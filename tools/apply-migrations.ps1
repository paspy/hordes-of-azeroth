. "$PSScriptRoot\common.ps1"

if (-not (Test-DbUp)) { throw 'MariaDB is not running. Start it with tools\start-server.ps1 -DatabaseOnly.' }

$mariadb   = Get-MariaProgram 'mariadb'
$databases = @{ world = 'mangos'; characters = 'characters'; logon = 'realmd' }
$applied   = 0

foreach ($file in Get-ChildItem (Join-Path $ServerDir 'core\sql\migrations') -Filter '*.sql' | Sort-Object Name) {
    if ($file.BaseName -notmatch '^(\d{14})_(world|characters|logon)$') { continue }
    $id = $Matches[1]
    $db = $databases[$Matches[2]]

    $known = & $mariadb @DbRootArgs -N -B $db -e "SELECT COUNT(*) FROM ``migrations`` WHERE ``id`` = '$id'"
    if ($LASTEXITCODE -ne 0) { throw "Could not read the migrations table of $db." }
    if ([int]$known -gt 0) { continue }

    Write-Host "Applying $($file.Name) to $db"
    & $mariadb @DbRootArgs $db -e "source $($file.FullName -replace '\\', '/')"
    if ($LASTEXITCODE -ne 0) { throw "Migration $($file.Name) failed." }
    $applied++
}

Write-Host "$applied migration(s) applied"
