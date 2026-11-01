param([int]$Margin = 0)
. "$PSScriptRoot\common.ps1"

$TileSize = 533.33333
$GridCells = 16
$NoAreaFlag = 1
$WorldDb = 'mangos'
$OutFile = Join-Path $ConfigDir 'navtiles.json'
$MapsDir = Join-Path $DataDir 'maps'
$Camp = @{ Map = 1; X = 16226.2; Y = 16257.0 }

function Invoke-Query([string]$Sql) {
    $rows = & (Get-MariaProgram 'mariadb') @DbRootArgs -N -B -e $Sql $WorldDb
    if ($LASTEXITCODE -ne 0) { throw "Query failed: $Sql" }
    foreach ($row in $rows) { , ($row -split "`t") }
}

function Get-TileOf([double]$X, [double]$Y) {
    @([int][Math]::Floor(32 - $X / $TileSize), [int][Math]::Floor(32 - $Y / $TileSize))
}

function Get-TileAreaFlags([string]$Path) {
    $reader = [System.IO.BinaryReader]::new([System.IO.File]::OpenRead($Path))
    try {
        $reader.BaseStream.Position = 8
        $areaOffset = $reader.ReadUInt32()
        $reader.BaseStream.Position = $areaOffset + 4
        $flags = $reader.ReadUInt16()
        $single = $reader.ReadUInt16()
        if ($flags -band $NoAreaFlag) { return @($single) }
        $areas = [System.Collections.Generic.HashSet[int]]::new()
        for ($i = 0; $i -lt $GridCells * $GridCells; $i++) { [void]$areas.Add($reader.ReadUInt16()) }
        return @($areas)
    } finally {
        $reader.Dispose()
    }
}

function New-Group([string]$Name) {
    [pscustomobject]@{ Name = $Name; WholeMaps = [System.Collections.Generic.SortedSet[int]]::new(); Tiles = @{} }
}

function Add-TileArea($Group, [int]$MapId, [int]$FromX, [int]$FromY) {
    for ($dx = -$Margin; $dx -le $Margin; $dx++) {
        for ($dy = -$Margin; $dy -le $Margin; $dy++) {
            $x, $y = ($FromX + $dx), ($FromY + $dy)
            if ($x -lt 0 -or $x -gt 63 -or $y -lt 0 -or $y -gt 63) { continue }
            if (-not $Group.Tiles[$MapId]) { $Group.Tiles[$MapId] = [System.Collections.Generic.HashSet[string]]::new() }
            [void]$Group.Tiles[$MapId].Add("$x,$y")
        }
    }
}

$zoneOfAreaFlag = @{}
foreach ($row in Invoke-Query 'SELECT map_id, explore_flag, entry, zone_id FROM area_template') {
    $zoneOfAreaFlag["$([int]$row[0]):$([int]$row[1])"] = if ([int]$row[3] -eq 0) { [int]$row[2] } else { [int]$row[3] }
}

$areaFlagsByTile = @{}
function Get-CachedAreaFlags([System.IO.FileInfo]$File) {
    if (-not $areaFlagsByTile.ContainsKey($File.Name)) { $areaFlagsByTile[$File.Name] = Get-TileAreaFlags $File.FullName }
    $areaFlagsByTile[$File.Name]
}

$runMaps = @(Invoke-Query @'
SELECT b.id, b.map_id, b.zone_id, b.position_x, b.position_y, COALESCE(t.stages, 0), COALESCE(t.name, '')
FROM bonk_map b LEFT JOIN bonk_tier t ON t.id = b.tier
'@)
$startsByRunMap = @{}
foreach ($row in Invoke-Query 'SELECT map, x, y FROM bonk_map_start') {
    $startsByRunMap[[int]$row[0]] += , @([double]$row[1], [double]$row[2])
}

$tiers = $runMaps | Where-Object { [int]$_[5] -gt 0 } | ForEach-Object { [pscustomobject]@{ Stages = [int]$_[5]; Name = $_[6] } } |
    Sort-Object Stages -Unique
$firstTier = $tiers | Select-Object -First 1
$groups = [System.Collections.Generic.List[object]]::new()
$groupOfStages = @{}
foreach ($tier in $tiers) {
    $name = if ($tier -eq $firstTier) { "Camp and $($tier.Name) zones" } else { "$($tier.Name) zones" }
    $group = New-Group $name
    $groupOfStages[$tier.Stages] = $group
    $groups.Add($group)
    if ($tier -eq $firstTier) {
        $dungeons = New-Group 'Dungeons'
        $groups.Add($dungeons)
    }
}

$campX, $campY = Get-TileOf $Camp.X $Camp.Y
Add-TileArea $groups[0] $Camp.Map $campX $campY

foreach ($row in $runMaps) {
    $runMapId, $mapId, $zoneId, $stages = [int]$row[0], [int]$row[1], [int]$row[2], [int]$row[5]
    if ($zoneId -eq 0) {
        [void]$dungeons.WholeMaps.Add($mapId)
        continue
    }
    $group = $groupOfStages[$stages]
    foreach ($file in Get-ChildItem $MapsDir -Filter ('{0:D3}*.map' -f $mapId)) {
        $inZone = Get-CachedAreaFlags $file | Where-Object { $zoneOfAreaFlag["${mapId}:$_"] -eq $zoneId } | Select-Object -First 1
        if ($null -ne $inZone) { Add-TileArea $group $mapId ([int]$file.Name.Substring(3, 2)) ([int]$file.Name.Substring(5, 2)) }
    }
    $positions = @(, @([double]$row[3], [double]$row[4])) + @($startsByRunMap[$runMapId] | Where-Object { $_ })
    foreach ($position in $positions) {
        $x, $y = Get-TileOf $position[0] $position[1]
        Add-TileArea $group $mapId $x $y
    }
}

$claimed = [System.Collections.Generic.HashSet[string]]::new()
$output = [System.Collections.Generic.List[object]]::new()
foreach ($group in $groups) {
    $maps = [ordered]@{}
    foreach ($mapId in $group.WholeMaps) { $maps["$mapId"] = 'all' }
    foreach ($mapId in ($group.Tiles.Keys | Sort-Object)) {
        $list = foreach ($tile in $group.Tiles[$mapId]) {
            $fromX, $fromY = [int]($tile -split ',')[0], [int]($tile -split ',')[1]
            $fileName = '{0:D3}{1:D2}{2:D2}.map' -f $mapId, $fromX, $fromY
            if (-not (Test-Path (Join-Path $MapsDir $fileName))) { continue }
            if (-not $claimed.Add("${mapId}:$tile")) { continue }
            "$fromY,$fromX"
        }
        if ($list) { $maps["$mapId"] = @($list | Sort-Object) }
    }
    $output.Add([ordered]@{ name = $group.Name; maps = $maps })
}

$json = [ordered]@{ groups = $output } | ConvertTo-Json -Depth 5
$fresh = $json | ConvertFrom-Json | ConvertTo-Json -Depth 5 -Compress
$existing = if (Test-Path $OutFile) { Get-Content $OutFile -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 5 -Compress }
$changed = $fresh -ne $existing
if ($changed) { [System.IO.File]::WriteAllText($OutFile, $json + "`n") }
foreach ($group in $output) {
    $parts = foreach ($key in $group.maps.Keys) {
        $value = $group.maps[$key]
        if ($value -is [string]) { "map $key all" } else { "map $key $($value.Count)" }
    }
    Write-Host "$($group.name): $($parts -join ', ')"
}
if ($changed) { Write-Host "Wrote $OutFile" } else { Write-Host "$OutFile is up to date" }
