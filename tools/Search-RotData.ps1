<#
.SYNOPSIS
Searches a ROT static data dump and prints related people, clans, kingdoms, and settlements.

.DESCRIPTION
Reads focused CSV files produced by tools/Export-RotData.ps1. The tool is meant
for manual discovery and debugging: search for "Stannis", "Dragonstone",
"clan_empire_west_3", or "town_EW1" and get linked ownership/membership data.

Use Export-RotData.ps1 -SkipBroadTables to create the focused tables quickly.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Query,

    [ValidateSet("All", "Person", "Clan", "Kingdom", "Settlement", "Named")]
    [string]$Kind = "All",

    [string]$DumpDir,

    [int]$Limit = 8,

    [switch]$Exact,

    [switch]$Json
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-DumpDirectory {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $resolved = Resolve-Path -LiteralPath $RequestedPath
        return $resolved.Path
    }

    $dataDumps = Join-Path $repoRoot "data-dumps"
    if (-not (Test-Path -LiteralPath $dataDumps)) {
        throw "No data-dumps directory found. Run tools/Export-RotData.ps1 first."
    }

    $candidates = @(Get-ChildItem -LiteralPath $dataDumps -Directory |
        Where-Object {
            (Test-Path -LiteralPath (Join-Path $_.FullName "summary.json")) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "characters.csv")) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "named_objects.csv"))
        } |
        Sort-Object LastWriteTime -Descending)

    if ($candidates.Count -eq 0) {
        throw "No suitable ROT dump found. Run tools/Export-RotData.ps1 -SkipBroadTables first."
    }

    return $candidates[0].FullName
}

function Import-OptionalCsv {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return @(Import-Csv -LiteralPath $Path)
    }

    return @()
}

function Read-Attributes {
    param($Row)

    if ($null -eq $Row -or [string]::IsNullOrWhiteSpace($Row.AttributesJson)) {
        return $null
    }

    try {
        return ($Row.AttributesJson | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-Attribute {
    param(
        $Row,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $attributes = Read-Attributes -Row $Row
    if ($null -eq $attributes) {
        return ""
    }

    $property = $attributes.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return ""
    }

    return [string]$property.Value
}

function Remove-ReferencePrefix {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $trimmed = $Value.Trim()
    if ($trimmed -match "^[A-Za-z_][A-Za-z0-9_]*\.(.+)$") {
        return $matches[1]
    }

    return $trimmed
}

function Normalize-SearchText {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    return ($Value -replace "[{}=\[\]""']", " ").ToLowerInvariant()
}

function Get-DisplayName {
    param($Row)

    foreach ($propertyName in @("DisplayName", "DisplayText", "NameAttribute", "TextAttribute", "ValueAttribute", "Identifier")) {
        if ($null -ne $Row.PSObject.Properties[$propertyName]) {
            $value = [string]$Row.$propertyName
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                if ($value -match "^\{\{=([^}]+)\}\}(.*)$") {
                    return $matches[2]
                }
                if ($value -match "^\{=([^}]+)\}(.*)$") {
                    return $matches[2]
                }
                return $value
            }
        }
    }

    return ""
}

function Get-RowValue {
    param(
        $Row,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    if ($null -eq $Row -or $null -eq $Row.PSObject.Properties[$PropertyName]) {
        return ""
    }

    return [string]$Row.$PropertyName
}

function Get-TextSnippet {
    param(
        [string]$Text,
        [int]$MaxLength = 220
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $singleLine = (($Text -replace "\s+", " ").Trim())
    if ($singleLine.Length -le $MaxLength) {
        return $singleLine
    }

    return $singleLine.Substring(0, $MaxLength - 3) + "..."
}

function Get-SettlementType {
    param($SettlementRow)

    $id = [string]$SettlementRow.Identifier
    if ($id.StartsWith("town_")) { return "Town" }
    if ($id.StartsWith("castle_")) { return "Castle" }
    if ($id.StartsWith("village_")) { return "Village" }
    if ($id.StartsWith("hideout_")) { return "Hideout" }
    if ($id.StartsWith("ROT_castle")) { return "Castle" }
    if ($id.StartsWith("ROT_village")) { return "Village" }

    return "Settlement"
}

function Build-Index {
    param([array]$Rows)

    $index = @{}
    foreach ($row in $Rows) {
        if (-not [string]::IsNullOrWhiteSpace($row.Identifier) -and -not $index.ContainsKey($row.Identifier)) {
            $index[$row.Identifier] = $row
        }
    }

    return $index
}

function Get-ById {
    param(
        [hashtable]$Index,
        [string]$Id
    )

    $normalized = Remove-ReferencePrefix -Value $Id
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }

    if ($Index.ContainsKey($normalized)) {
        return $Index[$normalized]
    }

    return $null
}

function Add-Match {
    param(
        [System.Collections.Generic.List[object]]$Matches,
        [string]$Kind,
        $Row,
        [int]$Score,
        [string]$Reason
    )

    if ($null -eq $Row) {
        return
    }

    $key = $Kind + ":" + [string]$Row.Identifier
    foreach ($existing in $Matches) {
        if ($existing.Key -eq $key) {
            if ($Score -gt $existing.Score) {
                $existing.Score = $Score
                $existing.Reason = $Reason
            }
            return
        }
    }

    [void]$Matches.Add([pscustomobject]@{
        Key = $key
        Kind = $Kind
        Row = $Row
        Score = $Score
        Reason = $Reason
    })
}

function Test-RowMatch {
    param(
        $Row,
        [string]$QueryText,
        [bool]$ExactMatch
    )

    $display = Get-DisplayName -Row $Row
    $id = [string]$Row.Identifier
    $source = [string]$Row.RelativePath
    $name = ""
    if ($null -ne $Row.PSObject.Properties["NameAttribute"]) {
        $name = [string]$Row.NameAttribute
    }

    if ($ExactMatch) {
        if ($id -ieq $QueryText -or
            (Remove-ReferencePrefix -Value $id) -ieq (Remove-ReferencePrefix -Value $QueryText) -or
            $display -ieq $QueryText -or
            $name -ieq $QueryText) {
            return [pscustomobject]@{ Matched = $true; Score = 100; Reason = "exact" }
        }

        return [pscustomobject]@{ Matched = $false; Score = 0; Reason = "" }
    }

    $needle = Normalize-SearchText -Value $QueryText
    $haystack = Normalize-SearchText -Value (($id, $display, $name, $source) -join " ")

    if ($haystack.Contains($needle)) {
        $score = 40
        $reason = "contains"
        if ((Normalize-SearchText -Value $id) -eq $needle -or (Normalize-SearchText -Value $display) -eq $needle) {
            $score = 100
            $reason = "exact normalized"
        }
        elseif ((Normalize-SearchText -Value $display).StartsWith($needle)) {
            $score = 80
            $reason = "display starts with query"
        }
        elseif ((Normalize-SearchText -Value $id).StartsWith($needle)) {
            $score = 75
            $reason = "id starts with query"
        }

        return [pscustomobject]@{ Matched = $true; Score = $score; Reason = $reason }
    }

    return [pscustomobject]@{ Matched = $false; Score = 0; Reason = "" }
}

function Find-Matches {
    param(
        [string]$QueryText,
        [string]$KindFilter,
        [bool]$ExactMatch
    )

    $matches = New-Object System.Collections.Generic.List[object]

    if ($KindFilter -eq "All" -or $KindFilter -eq "Person") {
        foreach ($row in $script:Characters) {
            $result = Test-RowMatch -Row $row -QueryText $QueryText -ExactMatch $ExactMatch
            if ($result.Matched) {
                Add-Match -Matches $matches -Kind "Person" -Row $row -Score $result.Score -Reason $result.Reason
            }
        }

        foreach ($row in $script:Heroes) {
            $result = Test-RowMatch -Row $row -QueryText $QueryText -ExactMatch $ExactMatch
            if ($result.Matched) {
                Add-Match -Matches $matches -Kind "HeroData" -Row $row -Score ($result.Score - 5) -Reason $result.Reason
            }
        }
    }

    if ($KindFilter -eq "All" -or $KindFilter -eq "Clan") {
        foreach ($row in $script:Clans) {
            $result = Test-RowMatch -Row $row -QueryText $QueryText -ExactMatch $ExactMatch
            if ($result.Matched) {
                Add-Match -Matches $matches -Kind "Clan" -Row $row -Score $result.Score -Reason $result.Reason
            }
        }
    }

    if ($KindFilter -eq "All" -or $KindFilter -eq "Kingdom") {
        foreach ($row in $script:Kingdoms) {
            $result = Test-RowMatch -Row $row -QueryText $QueryText -ExactMatch $ExactMatch
            if ($result.Matched) {
                Add-Match -Matches $matches -Kind "Kingdom" -Row $row -Score $result.Score -Reason $result.Reason
            }
        }
    }

    if ($KindFilter -eq "All" -or $KindFilter -eq "Settlement") {
        foreach ($row in $script:Settlements) {
            $result = Test-RowMatch -Row $row -QueryText $QueryText -ExactMatch $ExactMatch
            if ($result.Matched) {
                Add-Match -Matches $matches -Kind "Settlement" -Row $row -Score $result.Score -Reason $result.Reason
            }
        }
    }

    if ($KindFilter -eq "All" -or $KindFilter -eq "Named") {
        foreach ($row in $script:NamedObjects) {
            $result = Test-RowMatch -Row $row -QueryText $QueryText -ExactMatch $ExactMatch
            if ($result.Matched) {
                Add-Match -Matches $matches -Kind "Named" -Row $row -Score ($result.Score - 15) -Reason $result.Reason
            }
        }
    }

    return @($matches | Sort-Object Score, Kind -Descending | Select-Object -First $Limit)
}

function Get-ClanKingdom {
    param($ClanRow)

    $superFaction = Get-Attribute -Row $ClanRow -Name "super_faction"
    return Get-ById -Index $script:KingdomById -Id $superFaction
}

function Get-ClanSettlements {
    param($ClanRow)

    $clanId = [string]$ClanRow.Identifier
    return @($script:Settlements | Where-Object { (Remove-ReferencePrefix -Value $_.Owner) -eq $clanId } |
        Sort-Object @{ Expression = { Get-SettlementType -SettlementRow $_ } }, DisplayText)
}

function Get-KingdomClans {
    param($KingdomRow)

    $kingdomId = [string]$KingdomRow.Identifier
    return @($script:Clans | Where-Object { (Remove-ReferencePrefix -Value (Get-Attribute -Row $_ -Name "super_faction")) -eq $kingdomId } |
        Sort-Object DisplayText)
}

function Get-KingdomSettlements {
    param($KingdomRow)

    $kingdomClans = Get-KingdomClans -KingdomRow $KingdomRow
    $clanIds = @{}
    foreach ($clan in $kingdomClans) {
        $clanIds[$clan.Identifier] = $true
    }

    return @($script:Settlements | Where-Object { $clanIds.ContainsKey((Remove-ReferencePrefix -Value $_.Owner)) } |
        Sort-Object @{ Expression = { Get-SettlementType -SettlementRow $_ } }, DisplayText)
}

function Resolve-PersonContext {
    param($PersonRow)

    $id = [string]$PersonRow.Identifier
    $hero = Get-ById -Index $script:HeroById -Id $id
    $clan = $null
    $kingdom = $null
    $status = ""

    $heroFaction = Get-RowValue -Row $hero -PropertyName "Faction"
    if (-not [string]::IsNullOrWhiteSpace($heroFaction)) {
        $clan = Get-ById -Index $script:ClanById -Id $heroFaction
    }

    $personFaction = Get-RowValue -Row $PersonRow -PropertyName "Faction"
    if ($null -eq $clan -and -not [string]::IsNullOrWhiteSpace($personFaction)) {
        $clan = Get-ById -Index $script:ClanById -Id $personFaction
    }

    if ($null -ne $clan) {
        $kingdom = Get-ClanKingdom -ClanRow $clan
    }

    if ($PersonRow.Occupation -eq "Wanderer") {
        $status = "Wanderer / likely recruitable"
    }
    elseif ($PersonRow.Occupation -eq "Lord") {
        $status = "Lord"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($PersonRow.Occupation)) {
        $status = $PersonRow.Occupation
    }
    elseif ($null -eq $clan) {
        $status = "No clan/faction found in focused dump"
    }

    return [pscustomobject]@{
        Hero = $hero
        Clan = $clan
        Kingdom = $kingdom
        Status = $status
    }
}

function Format-EntityRef {
    param(
        $Row,
        [string]$Fallback = ""
    )

    if ($null -eq $Row) {
        return $Fallback
    }

    $display = Get-DisplayName -Row $Row
    if ([string]::IsNullOrWhiteSpace($display)) {
        $display = [string]$Row.Identifier
    }

    return ("{0} ({1})" -f $display, $Row.Identifier)
}

function Format-SettlementList {
    param(
        [array]$Settlements,
        [int]$Max = 12
    )

    if ($Settlements.Count -eq 0) {
        return "none found"
    }

    $items = @($Settlements | Select-Object -First $Max | ForEach-Object {
        "{0}: {1} ({2})" -f (Get-SettlementType -SettlementRow $_), (Get-DisplayName -Row $_), $_.Identifier
    })

    if ($Settlements.Count -gt $Max) {
        $items += ("...and {0} more" -f ($Settlements.Count - $Max))
    }

    return ($items -join "; ")
}

function Convert-MatchToObject {
    param($Match)

    $row = $Match.Row
    $display = Get-DisplayName -Row $row

    switch ($Match.Kind) {
        "Person" {
            $context = Resolve-PersonContext -PersonRow $row
            $heroText = ""
            if ($null -ne $context.Hero) {
                $heroText = Get-TextSnippet -Text $context.Hero.DisplayText
            }

            return [pscustomobject]@{
                Kind = "Person"
                Id = $row.Identifier
                Name = $display
                Status = $context.Status
                Culture = $row.Culture
                Clan = Format-EntityRef -Row $context.Clan
                Kingdom = Format-EntityRef -Row $context.Kingdom
                Source = $row.RelativePath
                XsltTemplateMatch = $row.XsltTemplateMatch
                Notes = $heroText
            }
        }
        "HeroData" {
            $person = Get-ById -Index $script:CharacterById -Id $row.Identifier
            if ($null -ne $person) {
                return Convert-MatchToObject -Match ([pscustomobject]@{ Kind = "Person"; Row = $person; Score = $Match.Score; Reason = $Match.Reason })
            }
        }
        "Clan" {
            $kingdom = Get-ClanKingdom -ClanRow $row
            $owner = Get-ById -Index $script:CharacterById -Id $row.Owner
            $settlements = @(Get-ClanSettlements -ClanRow $row)
            return [pscustomobject]@{
                Kind = "Clan"
                Id = $row.Identifier
                Name = $display
                Culture = $row.Culture
                Owner = Format-EntityRef -Row $owner -Fallback $row.Owner
                Kingdom = Format-EntityRef -Row $kingdom
                InitialHomeSettlement = Remove-ReferencePrefix -Value (Get-Attribute -Row $row -Name "initial_home_settlement")
                SettlementCount = $settlements.Count
                Settlements = Format-SettlementList -Settlements $settlements
                Source = $row.RelativePath
            }
        }
        "Kingdom" {
            $owner = Get-ById -Index $script:CharacterById -Id $row.Owner
            $clans = @(Get-KingdomClans -KingdomRow $row)
            $settlements = @(Get-KingdomSettlements -KingdomRow $row)
            return [pscustomobject]@{
                Kind = "Kingdom"
                Id = $row.Identifier
                Name = $display
                Culture = $row.Culture
                Ruler = Format-EntityRef -Row $owner -Fallback $row.Owner
                InitialHomeSettlement = Remove-ReferencePrefix -Value (Get-Attribute -Row $row -Name "initial_home_settlement")
                ClanCount = $clans.Count
                SettlementCount = $settlements.Count
                Settlements = Format-SettlementList -Settlements $settlements
                Source = $row.RelativePath
            }
        }
        "Settlement" {
            $clan = Get-ById -Index $script:ClanById -Id $row.Owner
            $kingdom = $null
            $clanOwner = $null
            if ($null -ne $clan) {
                $kingdom = Get-ClanKingdom -ClanRow $clan
                $clanOwner = Get-ById -Index $script:CharacterById -Id $clan.Owner
            }

            $portX = Get-Attribute -Row $row -Name "port_posX"
            $portY = Get-Attribute -Row $row -Name "port_posY"
            $port = ""
            if (-not [string]::IsNullOrWhiteSpace($portX) -or -not [string]::IsNullOrWhiteSpace($portY)) {
                $port = ("port marker ({0}, {1})" -f $portX, $portY)
            }

            return [pscustomobject]@{
                Kind = "Settlement"
                Id = $row.Identifier
                Name = $display
                Type = Get-SettlementType -SettlementRow $row
                Culture = $row.Culture
                OwnerClan = Format-EntityRef -Row $clan -Fallback $row.Owner
                OwnerHero = Format-EntityRef -Row $clanOwner
                Kingdom = Format-EntityRef -Row $kingdom
                Naval = $port
                Source = $row.RelativePath
            }
        }
        "Named" {
            return [pscustomobject]@{
                Kind = "Named"
                Id = $row.Identifier
                Name = $display
                ElementName = $row.ElementName
                Culture = $row.Culture
                Source = $row.RelativePath
                XsltTemplateMatch = $row.XsltTemplateMatch
            }
        }
    }

    return [pscustomobject]@{
        Kind = $Match.Kind
        Id = $row.Identifier
        Name = $display
        Source = $row.RelativePath
    }
}

function Write-Result {
    param(
        $Object,
        [int]$Index
    )

    Write-Host ""
    Write-Host ("[{0}] {1}: {2} ({3})" -f $Index, $Object.Kind, $Object.Name, $Object.Id)

    foreach ($property in $Object.PSObject.Properties) {
        if ($property.Name -in @("Kind", "Name", "Id")) {
            continue
        }

        $value = [string]$property.Value
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            Write-Host ("  {0}: {1}" -f $property.Name, $value)
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Query)) {
    throw "Pass a search query. Example: tools/Search-RotData.ps1 Stannis"
}

$resolvedDumpDir = Resolve-DumpDirectory -RequestedPath $DumpDir

$script:Characters = Import-OptionalCsv -Path (Join-Path $resolvedDumpDir "characters.csv")
$script:Heroes = Import-OptionalCsv -Path (Join-Path $resolvedDumpDir "heroes.csv")
$script:Clans = Import-OptionalCsv -Path (Join-Path $resolvedDumpDir "clans.csv")
$script:Kingdoms = Import-OptionalCsv -Path (Join-Path $resolvedDumpDir "kingdoms.csv")
$script:Settlements = Import-OptionalCsv -Path (Join-Path $resolvedDumpDir "settlements.csv")
$script:NamedObjects = Import-OptionalCsv -Path (Join-Path $resolvedDumpDir "named_objects.csv")

$script:CharacterById = Build-Index -Rows $script:Characters
$script:HeroById = Build-Index -Rows $script:Heroes
$script:ClanById = Build-Index -Rows $script:Clans
$script:KingdomById = Build-Index -Rows $script:Kingdoms
$script:SettlementById = Build-Index -Rows $script:Settlements

$matches = Find-Matches -QueryText $Query -KindFilter $Kind -ExactMatch ([bool]$Exact)
$convertedObjects = @($matches | ForEach-Object { Convert-MatchToObject -Match $_ } | Where-Object { $null -ne $_ })
$seenObjects = @{}
$objects = @($convertedObjects | Where-Object {
    $objectKey = [string]$_.Kind + ":" + [string]$_.Id
    if ($seenObjects.ContainsKey($objectKey)) {
        return $false
    }

    $seenObjects[$objectKey] = $true
    return $true
})

if ($Json) {
    [pscustomobject]@{
        DumpDir = $resolvedDumpDir
        Query = $Query
        Kind = $Kind
        Exact = [bool]$Exact
        Count = $objects.Count
        Results = $objects
    } | ConvertTo-Json -Depth 20
    return
}

Write-Host ("Dump: {0}" -f $resolvedDumpDir)
Write-Host ("Query: {0}; Kind: {1}; Results: {2}" -f $Query, $Kind, $objects.Count)

if ($objects.Count -eq 0) {
    Write-Host "No matches found."
    return
}

$index = 1
foreach ($object in $objects) {
    Write-Result -Object $object -Index $index
    $index++
}
