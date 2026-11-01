. "$PSScriptRoot\common.ps1"

$source = Join-Path $PSScriptRoot 'telegraphs'
$binDir = Join-Path $source 'bin'
$exe    = Join-Path $binDir 'TelegraphKit.exe'

if (Get-Process HordesOfAzeroth, WoW -ErrorAction SilentlyContinue) { throw 'Close the game first: it keeps the patch open.' }

if ($OnWindows) {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $csc)) { throw "The C# compiler was not found at $csc." }
    New-Item -ItemType Directory -Force $binDir | Out-Null
    $files = Get-ChildItem $source -Filter '*.cs' | ForEach-Object { $_.FullName }
    & $csc -nologo -optimize '-r:System.Drawing.dll' "-out:$exe" @files
} else {
    & dotnet build (Join-Path $source 'TelegraphKit.csproj') -c Release --nologo -v quiet
}
if ($LASTEXITCODE -ne 0) { throw 'TelegraphKit did not compile.' }

if ($OnWindows) {
    & $exe build $RepoRoot
} else {
    & dotnet (Join-Path $binDir 'TelegraphKit.dll') build $RepoRoot
}
if ($LASTEXITCODE -ne 0) { throw 'TelegraphKit could not build the patch.' }
