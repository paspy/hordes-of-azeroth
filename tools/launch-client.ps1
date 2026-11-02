param(
    [string]$Account = 'player',
    [string]$Password = 'player',
    [string[]]$ClientArgs = @()
)
. "$PSScriptRoot\common.ps1"

$client = Join-Path $RepoRoot 'client'
$exe = Get-Program (Join-Path (Join-Path $client 'target') 'release') 'HordesOfAzeroth'
if (-not (Test-Path $exe)) { throw 'Build the client first: cargo build --release -p hoa (in client/).' }

$env:BENILLA_HOME = Join-Path $client 'benilla-config'
$addon = Join-Path (Join-Path $RepoRoot 'Interface') (Join-Path 'AddOns' 'HordesOfAzeroth')
$clientAddOns = Join-Path $env:BENILLA_HOME 'AddOns'
$addonLink = Join-Path $clientAddOns 'HordesOfAzeroth'
if (-not (Test-Path $addonLink)) {
    New-Item -ItemType Directory -Force $clientAddOns | Out-Null
    $linkType = if ($OnWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $addonLink -Target $addon | Out-Null
    Write-Host "Linked the addon into $clientAddOns"
}
Get-ChildItem (Join-Path $env:BENILLA_HOME 'cache') -Filter *.bin -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force
if (-not (Test-Path (Join-Path $client 'WoW'))) { $env:WOW_DATA = Join-Path $RepoRoot 'Data' }
$env:WOW_USER = $Account
$env:WOW_PASS = $Password
if ($OnWindows) {
    Start-Quoted $exe $ClientArgs $client | Out-Null
} else {
    New-Item -ItemType Directory -Force $LogDir | Out-Null
    $env:HOA_CLIENT_LOG = Join-Path $LogDir 'Client.log'
    $env:HOA_CLIENT_ERRORS = Join-Path $LogDir 'ClientErrors.log'
    Push-Location $client
    try {
        & /bin/sh -c 'nohup "$0" "$@" > "$HOA_CLIENT_LOG" 2> "$HOA_CLIENT_ERRORS" < /dev/null &' $exe @ClientArgs
    } finally {
        Pop-Location
    }
    Write-Host "Client output goes to $(Join-Path $LogDir 'Client.log')"
}
Write-Host "Started HordesOfAzeroth; it logs in as $Account"
