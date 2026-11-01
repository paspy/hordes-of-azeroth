param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Password,
    [ValidateRange(0, 6)][int]$GmLevel = 0
)
. "$PSScriptRoot\common.ps1"

if (Get-Process mangosd -ErrorAction SilentlyContinue) { throw 'Stop mangosd first (tools\stop-server.ps1).' }
if (-not (Test-DbUp)) { throw 'MariaDB is not running (tools\start-server.ps1 starts it).' }

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = Get-Program $RunDir 'mangosd'
$startInfo.WorkingDirectory = $RunDir
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardInput = $true
$startInfo.RedirectStandardOutput = $true
$world = [System.Diagnostics.Process]::Start($startInfo)
$output = $world.StandardOutput.ReadToEndAsync()

Wait-Until {
    if ($world.HasExited) { throw "mangosd exited$(if ($null -ne $world.ExitCode) { " with code $($world.ExitCode)" }). See $(Join-Path $LogDir 'Server.log')." }
    Test-PortOpen 8085
} 300 'mangosd (port 8085)'

$console = $world.StandardInput
$console.WriteLine()
$console.WriteLine("account create $Name $Password")
if ($GmLevel -gt 0) {
    Start-Sleep -Seconds 2
    $console.WriteLine("account set gmlevel $Name $GmLevel")
}

Start-Sleep -Seconds 3
$console.Close()
$world.WaitForExit()

$text = $output.Result
$prompt = $text.IndexOf('mangos>')
if ($prompt -ge 0) { Write-Host $text.Substring($prompt) }
