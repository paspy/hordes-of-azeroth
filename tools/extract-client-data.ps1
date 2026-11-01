param(
    [int]$Threads = [Environment]::ProcessorCount,
    [switch]$SkipMmaps,
    [switch]$AllTiles,
    [switch]$MmapsOnly
)
. "$PSScriptRoot\common.ps1"

$extractors = Join-Path $RunDir 'Extractors'
$navTilesFile = Join-Path $ConfigDir 'navtiles.json'
$generatorOptions = @(
    '--silent',
    '--offMeshInput', (Join-Path $extractors 'offmesh.txt'),
    '--configInputPath', (Join-Path $extractors 'config.json')
)

function Invoke-Step([string]$Name, [string]$Exe, [string[]]$Arguments) {
    Write-Host "=== $Name ($(Get-Date -Format HH:mm:ss)) ==="
    & (Get-Program $extractors $Exe) @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE." }
}

function Get-TileFileName([string]$MapId, [string]$Tile) {
    $x, $y = $Tile -split ','
    '{0:D3}{1:D2}{2:D2}.mmtile' -f [int]$MapId, [int]$y, [int]$x
}

function Wait-ForSlot([System.Collections.Generic.List[System.Diagnostics.Process]]$Running, [int]$Limit) {
    while ($Running.Count -ge $Limit) {
        $finished = $Running | Where-Object HasExited
        if (-not $finished) { Start-Sleep -Milliseconds 200; continue }
        foreach ($process in @($finished)) {
            if ($process.ExitCode -ne 0) { throw "MoveMapGenerator exited with code $($process.ExitCode)." }
            [void]$Running.Remove($process)
        }
    }
}

function Build-NavTileGroups {
    $groups = (Get-Content $navTilesFile -Raw | ConvertFrom-Json).groups
    $generator = Get-Program $extractors 'MoveMapGenerator'
    $mmapsDir = Join-Path $DataDir 'mmaps'
    New-Item -ItemType Directory -Force $mmapsDir | Out-Null
    foreach ($group in $groups) {
        $wholeMaps = @()
        $tiles = [System.Collections.Generic.List[object]]::new()
        foreach ($map in $group.maps.PSObject.Properties) {
            if ($map.Value -is [string]) {
                if (-not (Get-ChildItem $mmapsDir -Filter ('{0:D3}*.mmtile' -f [int]$map.Name))) { $wholeMaps += $map.Name }
                continue
            }
            foreach ($tile in $map.Value) {
                if (-not (Test-Path (Join-Path $mmapsDir (Get-TileFileName $map.Name $tile)))) { $tiles.Add(@($map.Name, $tile)) }
            }
        }
        Write-Host "=== $($group.name): $($tiles.Count) tiles, $($wholeMaps.Count) whole maps ($(Get-Date -Format HH:mm:ss)) ==="
        foreach ($mapId in $wholeMaps) {
            & $generator $mapId --threads $Threads @generatorOptions | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "MoveMapGenerator $mapId failed with exit code $LASTEXITCODE." }
        }
        $running = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
        foreach ($tile in $tiles) {
            Wait-ForSlot $running $Threads
            $arguments = @($tile[0], '--tile', $tile[1], '--threads', '1') + $generatorOptions
            $running.Add((Start-Quoted $generator $arguments $DataDir 'Hidden'))
        }
        Wait-ForSlot $running 1
    }
}

New-Item -ItemType Directory -Force $DataDir, (Join-Path $DataDir 'vmaps') | Out-Null

Push-Location $DataDir
try {
    if (-not $MmapsOnly) {
        Invoke-Step 'Maps and DBC' 'MapExtractor' @('-i', $RepoRoot, '--silent')

        $dbcTarget = Join-Path (Join-Path $DataDir '5875') 'dbc'
        if (Test-Path $dbcTarget) { Remove-Item $dbcTarget -Recurse -Force }
        New-Item -ItemType Directory -Force (Split-Path $dbcTarget) | Out-Null
        Move-Item (Join-Path $DataDir 'dbc') $dbcTarget

        Invoke-Step 'VMap extract' 'VMapExtractor' @('-d', (Join-Path $RepoRoot 'Data'), '--silent')
        Invoke-Step 'VMap assemble' 'VMapAssembler' @('Buildings', 'vmaps', '--silent')
    }

    if ($AllTiles -and -not $SkipMmaps) {
        Invoke-Step 'MMap generate' 'MoveMapGenerator' (@('--threads', $Threads) + $generatorOptions)
    } elseif (-not $SkipMmaps) {
        Build-NavTileGroups
    }
} finally {
    Pop-Location
}

Write-Host "=== Done ($(Get-Date -Format HH:mm:ss)) ==="
