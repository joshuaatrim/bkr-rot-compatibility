<# 
.SYNOPSIS
Exports searchable Realm of Thrones XML data for compatibility work.

.DESCRIPTION
Reads the local Bannerlord/ROT paths from Directory.Build.props by default,
parses all .xml and .xslt files under each configured ROT ModuleData folder,
and writes CSV plus focused JSON outputs to an ignored data-dumps folder.

This is a static source-file dump. Treat naval/port rows as search markers,
not verified runtime shipping lanes.
#>

[CmdletBinding()]
param(
    [string]$PropsPath,
    [string]$BannerlordDir,
    [string[]]$ModuleDir,
    [string]$OutputDir,
    [switch]$IncludeXPath,
    [switch]$SkipBroadTables,
    [switch]$IncludeRawSubModuleElements
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($PropsPath)) {
    $PropsPath = Join-Path $repoRoot "Directory.Build.props"
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
    $OutputDir = Join-Path $repoRoot ("data-dumps\rot-static-" + $stamp)
}

function Expand-ProjectProperty {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][hashtable]$Properties
    )

    $expanded = $Value
    for ($i = 0; $i -lt 20; $i++) {
        $before = $expanded
        $expanded = [regex]::Replace($expanded, "\$\(([A-Za-z0-9_.-]+)\)", {
            param($match)

            $key = $match.Groups[1].Value
            if ($Properties.ContainsKey($key)) {
                return [string]$Properties[$key]
            }

            return $match.Value
        })

        if ($expanded -eq $before) {
            break
        }
    }

    return [Environment]::ExpandEnvironmentVariables($expanded)
}

function Read-ProjectProperties {
    param([Parameter(Mandatory = $true)][string]$Path)

    $properties = @{}

    if (-not (Test-Path -LiteralPath $Path)) {
        $examplePath = Join-Path $repoRoot "Directory.Build.props.example"
        if (Test-Path -LiteralPath $examplePath) {
            Write-Warning "Could not find $Path; reading Directory.Build.props.example instead."
            $Path = $examplePath
        }
        else {
            throw "Could not find $Path or Directory.Build.props.example."
        }
    }

    [xml]$xml = Get-Content -Raw -LiteralPath $Path
    foreach ($propertyGroup in @($xml.Project.PropertyGroup)) {
        foreach ($node in @($propertyGroup.ChildNodes)) {
            if ($node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                $properties[$node.Name] = $node.InnerText.Trim()
            }
        }
    }

    foreach ($key in @($properties.Keys)) {
        $properties[$key] = Expand-ProjectProperty -Value ([string]$properties[$key]) -Properties $properties
    }

    if (-not [string]::IsNullOrWhiteSpace($BannerlordDir)) {
        $properties["BannerlordDir"] = $BannerlordDir
        foreach ($key in @($properties.Keys)) {
            $properties[$key] = Expand-ProjectProperty -Value ([string]$properties[$key]) -Properties $properties
        }
    }

    return $properties
}

function New-XmlReaderSettings {
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $settings.XmlResolver = $null
    return $settings
}

function Read-XmlDocument {
    param([Parameter(Mandatory = $true)][string]$Path)

    $settings = New-XmlReaderSettings
    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    try {
        $document = New-Object System.Xml.XmlDocument
        $document.PreserveWhitespace = $false
        $document.Load($reader)
        return $document
    }
    finally {
        if ($null -ne $reader) {
            $reader.Close()
        }
    }
}

function Get-AttributeValue {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element,
        [Parameter(Mandatory = $true)][string[]]$Names
    )

    if ($null -eq $Element.Attributes) {
        return ""
    }

    foreach ($name in $Names) {
        foreach ($attribute in @($Element.Attributes)) {
            if ($attribute.LocalName -ieq $name) {
                return $attribute.Value
            }
        }
    }

    return ""
}

function Get-HashValue {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Values,
        [Parameter(Mandatory = $true)][string[]]$Names
    )

    foreach ($name in $Names) {
        if ($Values.ContainsKey($name)) {
            return [string]$Values[$name]
        }
    }

    return ""
}

function Split-LocalizedText {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{
            LocalizationKey = ""
            DisplayText = ""
        }
    }

    if ($Value -match "^\{\{=([^}]+)\}\}(.*)$") {
        return [pscustomobject]@{
            LocalizationKey = $matches[1]
            DisplayText = $matches[2]
        }
    }

    if ($Value -match "^\{=([^}]+)\}(.*)$") {
        return [pscustomobject]@{
            LocalizationKey = $matches[1]
            DisplayText = $matches[2]
        }
    }

    return [pscustomobject]@{
        LocalizationKey = ""
        DisplayText = $Value
    }
}

function Get-AttributesJson {
    param([Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element)

    $attributes = [ordered]@{}
    foreach ($attribute in @($Element.Attributes)) {
        $key = $attribute.LocalName
        if (-not [string]::IsNullOrWhiteSpace($attribute.NamespaceURI)) {
            $key = "{" + $attribute.NamespaceURI + "}" + $attribute.LocalName
        }

        $attributes[$key] = $attribute.Value
    }

    if ($attributes.Count -eq 0) {
        return "{}"
    }

    return ($attributes | ConvertTo-Json -Compress -Depth 10)
}

function Get-DirectText {
    param([Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element)

    $text = ""
    foreach ($child in @($Element.ChildNodes)) {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Text -or
            $child.NodeType -eq [System.Xml.XmlNodeType]::CDATA) {
            $text += $child.Value
        }
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    return $text.Trim()
}

function Get-ElementXPath {
    param([Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element)

    $parts = New-Object System.Collections.Generic.List[string]
    $node = $Element

    while ($null -ne $node -and $node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
        $parts.Insert(0, $node.LocalName)
        $node = $node.ParentNode
    }

    return "/" + ($parts -join "/")
}

function Get-ElementDepth {
    param([Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element)

    $depth = 0
    $node = $Element.ParentNode
    while ($null -ne $node -and $node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
        $depth++
        $node = $node.ParentNode
    }

    return $depth
}

function Find-AncestorByLocalName {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element,
        [Parameter(Mandatory = $true)][string]$LocalName
    )

    $node = $Element.ParentNode
    while ($null -ne $node) {
        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Element -and $node.LocalName -ieq $LocalName) {
            return $node
        }

        $node = $node.ParentNode
    }

    return $null
}

function Get-XsltTemplateMatch {
    param([Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element)

    $node = $Element.ParentNode
    while ($null -ne $node) {
        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Element -and $node.LocalName -ieq "template") {
            $match = Get-AttributeValue -Element $node -Names @("match")
            if (-not [string]::IsNullOrWhiteSpace($match)) {
                return $match
            }
        }

        $node = $node.ParentNode
    }

    return ""
}

function New-ElementRecord {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [Parameter(Mandatory = $true)][string]$ModuleFolder,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$SourceKind,
        [Parameter(Mandatory = $true)][int]$ElementIndex
    )

    $attributes = @{}
    foreach ($attribute in @($Element.Attributes)) {
        if (-not $attributes.ContainsKey($attribute.LocalName)) {
            $attributes[$attribute.LocalName] = $attribute.Value
        }
    }

    $identifier = Get-HashValue -Values $attributes -Names @("id", "Id", "stringId", "StringId")
    $nameAttribute = Get-HashValue -Values $attributes -Names @("name", "Name")
    $textAttribute = Get-HashValue -Values $attributes -Names @("text", "Text")
    $valueAttribute = Get-HashValue -Values $attributes -Names @("value", "Value")
    $culture = Get-HashValue -Values $attributes -Names @("culture", "Culture")
    $owner = Get-HashValue -Values $attributes -Names @("owner", "Owner")
    $faction = Get-HashValue -Values $attributes -Names @("faction", "Faction")

    $xpath = ""
    if ($IncludeXPath) {
        $xpath = Get-ElementXPath -Element $Element
    }

    return [pscustomobject]@{
        ModuleId = $ModuleId
        ModuleFolder = $ModuleFolder
        SourceKind = $SourceKind
        RelativePath = $RelativePath
        ElementIndex = $ElementIndex
        XPath = $xpath
        ElementName = $Element.LocalName
        NamespaceUri = $Element.NamespaceURI
        Depth = Get-ElementDepth -Element $Element
        Identifier = $identifier
        NameAttribute = $nameAttribute
        TextAttribute = $textAttribute
        ValueAttribute = $valueAttribute
        Culture = $culture
        Owner = $owner
        Faction = $faction
        Occupation = Get-HashValue -Values $attributes -Names @("occupation", "Occupation")
        IsHero = Get-HashValue -Values $attributes -Names @("is_hero", "IsHero")
        IsFemale = Get-HashValue -Values $attributes -Names @("is_female", "IsFemale")
        DefaultGroup = Get-HashValue -Values $attributes -Names @("default_group", "DefaultGroup")
        SkillTemplate = Get-HashValue -Values $attributes -Names @("skill_template", "SkillTemplate")
        XsltTemplateMatch = ""
        AttributeCount = $Element.Attributes.Count
        DirectText = Get-DirectText -Element $Element
    }
}

function New-DomainRecord {
    param(
        [Parameter(Mandatory = $true)]$ElementRecord,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element,
        [string]$ParentSettlementId = "",
        [string]$ComponentType = ""
    )

    $label = $ElementRecord.NameAttribute
    if ([string]::IsNullOrWhiteSpace($label)) {
        $label = $ElementRecord.TextAttribute
    }
    if ([string]::IsNullOrWhiteSpace($label)) {
        $label = $ElementRecord.ValueAttribute
    }

    $localized = Split-LocalizedText -Value $label
    $xsltTemplateMatch = Get-XsltTemplateMatch -Element $Element

    return [pscustomobject]@{
        Kind = $Kind
        ModuleId = $ElementRecord.ModuleId
        SourceKind = $ElementRecord.SourceKind
        RelativePath = $ElementRecord.RelativePath
        ElementIndex = $ElementRecord.ElementIndex
        XPath = $ElementRecord.XPath
        Identifier = $ElementRecord.Identifier
        NameAttribute = $ElementRecord.NameAttribute
        TextAttribute = $ElementRecord.TextAttribute
        ValueAttribute = $ElementRecord.ValueAttribute
        LocalizationKey = $localized.LocalizationKey
        DisplayText = $localized.DisplayText
        Culture = $ElementRecord.Culture
        Owner = $ElementRecord.Owner
        Faction = $ElementRecord.Faction
        Occupation = $ElementRecord.Occupation
        IsHero = $ElementRecord.IsHero
        IsFemale = $ElementRecord.IsFemale
        XsltTemplateMatch = $xsltTemplateMatch
        ParentSettlementId = $ParentSettlementId
        ComponentType = $ComponentType
        AttributesJson = Get-AttributesJson -Element $Element
        DirectText = $ElementRecord.DirectText
    }
}

function New-NamedObjectRecord {
    param(
        [Parameter(Mandatory = $true)]$ElementRecord,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element
    )

    $localized = Split-LocalizedText -Value $ElementRecord.NameAttribute
    $xsltTemplateMatch = Get-XsltTemplateMatch -Element $Element

    return [pscustomobject]@{
        ModuleId = $ElementRecord.ModuleId
        SourceKind = $ElementRecord.SourceKind
        RelativePath = $ElementRecord.RelativePath
        ElementIndex = $ElementRecord.ElementIndex
        XPath = $ElementRecord.XPath
        ElementName = $ElementRecord.ElementName
        Identifier = $ElementRecord.Identifier
        NameAttribute = $ElementRecord.NameAttribute
        LocalizationKey = $localized.LocalizationKey
        DisplayName = $localized.DisplayText
        Culture = $ElementRecord.Culture
        Owner = $ElementRecord.Owner
        Faction = $ElementRecord.Faction
        Occupation = $ElementRecord.Occupation
        IsHero = $ElementRecord.IsHero
        IsFemale = $ElementRecord.IsFemale
        XsltTemplateMatch = $xsltTemplateMatch
        AttributeCount = $ElementRecord.AttributeCount
    }
}

function New-CharacterRecord {
    param(
        [Parameter(Mandatory = $true)]$ElementRecord,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element
    )

    $localized = Split-LocalizedText -Value $ElementRecord.NameAttribute
    $xsltTemplateMatch = Get-XsltTemplateMatch -Element $Element

    return [pscustomobject]@{
        ModuleId = $ElementRecord.ModuleId
        SourceKind = $ElementRecord.SourceKind
        RelativePath = $ElementRecord.RelativePath
        ElementIndex = $ElementRecord.ElementIndex
        XPath = $ElementRecord.XPath
        Identifier = $ElementRecord.Identifier
        NameAttribute = $ElementRecord.NameAttribute
        LocalizationKey = $localized.LocalizationKey
        DisplayName = $localized.DisplayText
        Culture = $ElementRecord.Culture
        Occupation = $ElementRecord.Occupation
        IsHero = $ElementRecord.IsHero
        IsFemale = $ElementRecord.IsFemale
        DefaultGroup = $ElementRecord.DefaultGroup
        SkillTemplate = $ElementRecord.SkillTemplate
        XsltTemplateMatch = $xsltTemplateMatch
        AttributesJson = Get-AttributesJson -Element $Element
    }
}

function New-LocalizationStringRecord {
    param(
        [Parameter(Mandatory = $true)]$ElementRecord,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element
    )

    $label = $ElementRecord.TextAttribute
    if ([string]::IsNullOrWhiteSpace($label)) {
        $label = $ElementRecord.ValueAttribute
    }

    $localized = Split-LocalizedText -Value $label
    $xsltTemplateMatch = Get-XsltTemplateMatch -Element $Element

    return [pscustomobject]@{
        ModuleId = $ElementRecord.ModuleId
        SourceKind = $ElementRecord.SourceKind
        RelativePath = $ElementRecord.RelativePath
        ElementIndex = $ElementRecord.ElementIndex
        XPath = $ElementRecord.XPath
        StringId = $ElementRecord.Identifier
        TextAttribute = $ElementRecord.TextAttribute
        ValueAttribute = $ElementRecord.ValueAttribute
        LocalizationKey = $localized.LocalizationKey
        DisplayText = $localized.DisplayText
        XsltTemplateMatch = $xsltTemplateMatch
        AttributesJson = Get-AttributesJson -Element $Element
    }
}

function Get-NavalMarker {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Element,
        [Parameter(Mandatory = $true)]$ElementRecord
    )

    $pattern = "(?i)\b(port|harbor|harbour|naval|ship|sea|coast|sail|dock|ferry|water|river|lake|island)\b"
    $markerMatches = New-Object System.Collections.Generic.List[string]

    if ($Element.LocalName -match $pattern) {
        [void]$markerMatches.Add("element=" + $Element.LocalName)
    }

    foreach ($attribute in @($Element.Attributes)) {
        if ($attribute.LocalName -match $pattern) {
            [void]$markerMatches.Add("attribute-name=" + $attribute.LocalName)
        }

        if ($attribute.Value -match $pattern) {
            [void]$markerMatches.Add("attribute-value=" + $attribute.LocalName)
        }
    }

    if ($ElementRecord.DirectText -match $pattern) {
        [void]$markerMatches.Add("direct-text")
    }

    if ($markerMatches.Count -eq 0) {
        return $null
    }

    return [pscustomobject]@{
        ModuleId = $ElementRecord.ModuleId
        SourceKind = $ElementRecord.SourceKind
        RelativePath = $ElementRecord.RelativePath
        ElementIndex = $ElementRecord.ElementIndex
        XPath = $ElementRecord.XPath
        ElementName = $ElementRecord.ElementName
        Identifier = $ElementRecord.Identifier
        MatchedFields = ($markerMatches -join ";")
        AttributesJson = Get-AttributesJson -Element $Element
        DirectText = $ElementRecord.DirectText
    }
}

function Export-Table {
    param(
        [Parameter(Mandatory = $true)]$Rows,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        [void](New-Item -ItemType Directory -Force -Path $parent)
    }

    $rowsArray = @($Rows | ForEach-Object { $_ })
    if ($rowsArray.Count -eq 0) {
        [void](New-Item -ItemType File -Force -Path $Path)
        return
    }

    $rowsArray | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $Path
}

function Export-Json {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        [void](New-Item -ItemType Directory -Force -Path $parent)
    }

    @($Value | ForEach-Object { $_ }) | ConvertTo-Json -Depth 50 | Set-Content -Encoding UTF8 -LiteralPath $Path
}

$properties = Read-ProjectProperties -Path $PropsPath

$configuredModuleDirs = New-Object System.Collections.Generic.List[string]
if ($null -ne $ModuleDir -and $ModuleDir.Count -gt 0) {
    foreach ($dir in $ModuleDir) {
        [void]$configuredModuleDirs.Add((Expand-ProjectProperty -Value $dir -Properties $properties))
    }
}
else {
    foreach ($key in @("ROTCoreModuleDir", "ROTContentModuleDir", "ROTMapModuleDir", "ROTDragonModuleDir")) {
        if ($properties.ContainsKey($key)) {
            [void]$configuredModuleDirs.Add([string]$properties[$key])
        }
    }
}

if ($configuredModuleDirs.Count -eq 0) {
    throw "No ROT module directories were configured. Set Directory.Build.props or pass -ModuleDir."
}

[void](New-Item -ItemType Directory -Force -Path $OutputDir)

$moduleRows = New-Object System.Collections.Generic.List[object]
$dependencyRows = New-Object System.Collections.Generic.List[object]
$fileRows = New-Object System.Collections.Generic.List[object]
$parseErrorRows = New-Object System.Collections.Generic.List[object]
$elementRows = New-Object System.Collections.Generic.List[object]
$attributeRows = New-Object System.Collections.Generic.List[object]
$elementCount = 0
$attributeCount = 0
$cultureRows = New-Object System.Collections.Generic.List[object]
$kingdomRows = New-Object System.Collections.Generic.List[object]
$clanRows = New-Object System.Collections.Generic.List[object]
$heroRows = New-Object System.Collections.Generic.List[object]
$characterRows = New-Object System.Collections.Generic.List[object]
$namedObjectRows = New-Object System.Collections.Generic.List[object]
$localizationStringRows = New-Object System.Collections.Generic.List[object]
$settlementRows = New-Object System.Collections.Generic.List[object]
$settlementComponentRows = New-Object System.Collections.Generic.List[object]
$navalMarkerRows = New-Object System.Collections.Generic.List[object]

$loadOrderIndex = 0
foreach ($modulePathValue in $configuredModuleDirs) {
    $modulePath = Expand-ProjectProperty -Value $modulePathValue -Properties $properties
    $moduleFolder = Split-Path -Leaf $modulePath
    $moduleId = $moduleFolder
    $moduleName = ""
    $moduleVersion = ""
    $singleplayer = ""
    $multiplayer = ""
    $moduleDataPath = Join-Path $modulePath "ModuleData"
    $subModulePath = Join-Path $modulePath "SubModule.xml"
    $moduleExists = Test-Path -LiteralPath $modulePath
    $moduleDataExists = Test-Path -LiteralPath $moduleDataPath

    if (Test-Path -LiteralPath $subModulePath) {
        try {
            $subModule = Read-XmlDocument -Path $subModulePath
            $idNode = $subModule.SelectSingleNode("/Module/Id")
            $nameNode = $subModule.SelectSingleNode("/Module/Name")
            $versionNode = $subModule.SelectSingleNode("/Module/Version")
            $singleplayerNode = $subModule.SelectSingleNode("/Module/SingleplayerModule")
            $multiplayerNode = $subModule.SelectSingleNode("/Module/MultiplayerModule")

            if ($null -ne $idNode -and $null -ne $idNode.Attributes["value"]) {
                $moduleId = $idNode.Attributes["value"].Value
            }
            if ($null -ne $nameNode -and $null -ne $nameNode.Attributes["value"]) {
                $moduleName = $nameNode.Attributes["value"].Value
            }
            if ($null -ne $versionNode -and $null -ne $versionNode.Attributes["value"]) {
                $moduleVersion = $versionNode.Attributes["value"].Value
            }
            if ($null -ne $singleplayerNode -and $null -ne $singleplayerNode.Attributes["value"]) {
                $singleplayer = $singleplayerNode.Attributes["value"].Value
            }
            if ($null -ne $multiplayerNode -and $null -ne $multiplayerNode.Attributes["value"]) {
                $multiplayer = $multiplayerNode.Attributes["value"].Value
            }

            $dependedModulesNode = $subModule.SelectSingleNode("/Module/DependedModules")
            if ($null -ne $dependedModulesNode) {
                foreach ($dependency in @($dependedModulesNode.SelectNodes("DependedModule"))) {
                    [void]$dependencyRows.Add([pscustomobject]@{
                        ModuleId = $moduleId
                        ModuleFolder = $moduleFolder
                        DependencyType = "DependedModule"
                        DependencyId = $dependency.Id
                        Order = ""
                        Version = ""
                    })
                }
            }

            $metadataNode = $subModule.SelectSingleNode("/Module/DependedModuleMetadatas")
            if ($null -ne $metadataNode) {
                foreach ($metadata in @($metadataNode.SelectNodes("DependedModuleMetadata"))) {
                    [void]$dependencyRows.Add([pscustomobject]@{
                        ModuleId = $moduleId
                        ModuleFolder = $moduleFolder
                        DependencyType = "DependedModuleMetadata"
                        DependencyId = $metadata.id
                        Order = $metadata.order
                        Version = $metadata.version
                    })
                }
            }
        }
        catch {
            [void]$parseErrorRows.Add([pscustomobject]@{
                ModuleId = $moduleId
                ModuleFolder = $moduleFolder
                RelativePath = "SubModule.xml"
                Error = $_.Exception.Message
            })
        }
    }

    $files = @()
    if ($moduleDataExists) {
        $files = @(Get-ChildItem -LiteralPath $moduleDataPath -Recurse -File |
            Where-Object { $_.Extension -ieq ".xml" -or $_.Extension -ieq ".xslt" } |
            Sort-Object FullName)
    }

    [void]$moduleRows.Add([pscustomobject]@{
        ConfiguredLoadOrder = $loadOrderIndex
        ModuleId = $moduleId
        ModuleFolder = $moduleFolder
        Name = $moduleName
        Version = $moduleVersion
        SingleplayerModule = $singleplayer
        MultiplayerModule = $multiplayer
        ModulePath = $modulePath
        ModuleDataPath = $moduleDataPath
        ModuleExists = $moduleExists
        ModuleDataExists = $moduleDataExists
        ModuleDataFileCount = $files.Count
    })

    if ($moduleDataExists) {
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($modulePath.Length + 1)
            $sourceKind = $file.Extension.TrimStart(".").ToLowerInvariant()

            [void]$fileRows.Add([pscustomobject]@{
                ModuleId = $moduleId
                ModuleFolder = $moduleFolder
                SourceKind = $sourceKind
                RelativePath = $relativePath
                FullPath = $file.FullName
                Length = $file.Length
                LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString("o")
            })

            try {
                $document = Read-XmlDocument -Path $file.FullName
                $elementIndex = 0
                foreach ($element in @($document.SelectNodes("//*"))) {
                    $record = New-ElementRecord -Element $element -ModuleId $moduleId -ModuleFolder $moduleFolder -RelativePath $relativePath -SourceKind $sourceKind -ElementIndex $elementIndex
                    $elementCount++
                    $attributeCount += $element.Attributes.Count

                    if (-not $SkipBroadTables) {
                        [void]$elementRows.Add($record)
                    }

                    if (-not $SkipBroadTables) {
                        foreach ($attribute in @($element.Attributes)) {
                            [void]$attributeRows.Add([pscustomobject]@{
                                ModuleId = $moduleId
                                ModuleFolder = $moduleFolder
                                SourceKind = $sourceKind
                                RelativePath = $relativePath
                                ElementIndex = $record.ElementIndex
                                XPath = $record.XPath
                                ElementName = $record.ElementName
                                ElementIdentifier = $record.Identifier
                                AttributeName = $attribute.LocalName
                                AttributeNamespaceUri = $attribute.NamespaceURI
                                AttributeValue = $attribute.Value
                            })
                        }
                    }

                    if (-not [string]::IsNullOrWhiteSpace($record.Identifier) -and
                        -not [string]::IsNullOrWhiteSpace($record.NameAttribute)) {
                        [void]$namedObjectRows.Add((New-NamedObjectRecord -ElementRecord $record -Element $element))
                    }

                    switch ($element.LocalName.ToLowerInvariant()) {
                        "culture" {
                            [void]$cultureRows.Add((New-DomainRecord -ElementRecord $record -Kind "Culture" -Element $element))
                            break
                        }
                        "kingdom" {
                            [void]$kingdomRows.Add((New-DomainRecord -ElementRecord $record -Kind "Kingdom" -Element $element))
                            break
                        }
                        "faction" {
                            [void]$clanRows.Add((New-DomainRecord -ElementRecord $record -Kind $element.LocalName -Element $element))
                            break
                        }
                        "clan" {
                            [void]$clanRows.Add((New-DomainRecord -ElementRecord $record -Kind $element.LocalName -Element $element))
                            break
                        }
                        "hero" {
                            [void]$heroRows.Add((New-DomainRecord -ElementRecord $record -Kind "Hero" -Element $element))
                            break
                        }
                        "npccharacter" {
                            [void]$characterRows.Add((New-CharacterRecord -ElementRecord $record -Element $element))
                            break
                        }
                        "settlement" {
                            [void]$settlementRows.Add((New-DomainRecord -ElementRecord $record -Kind "Settlement" -Element $element))
                            break
                        }
                        "string" {
                            if (-not [string]::IsNullOrWhiteSpace($record.Identifier)) {
                                [void]$localizationStringRows.Add((New-LocalizationStringRecord -ElementRecord $record -Element $element))
                            }
                            break
                        }
                    }

                    $componentsAncestor = $element.ParentNode
                    if ($null -ne $componentsAncestor -and
                        $componentsAncestor.NodeType -eq [System.Xml.XmlNodeType]::Element -and
                        $componentsAncestor.LocalName -ieq "Components") {
                        $settlementAncestor = Find-AncestorByLocalName -Element $componentsAncestor -LocalName "Settlement"
                        if ($null -ne $settlementAncestor) {
                            $settlementId = Get-AttributeValue -Element $settlementAncestor -Names @("id", "Id", "stringId", "StringId")
                            [void]$settlementComponentRows.Add((New-DomainRecord -ElementRecord $record -Kind "SettlementComponent" -Element $element -ParentSettlementId $settlementId -ComponentType $element.LocalName))
                        }
                    }

                    $navalMarker = Get-NavalMarker -Element $element -ElementRecord $record
                    if ($null -ne $navalMarker) {
                        [void]$navalMarkerRows.Add($navalMarker)
                    }

                    $elementIndex++
                }
            }
            catch {
                [void]$parseErrorRows.Add([pscustomobject]@{
                    ModuleId = $moduleId
                    ModuleFolder = $moduleFolder
                    RelativePath = $relativePath
                    Error = $_.Exception.Message
                })
            }
        }
    }

    if ($IncludeRawSubModuleElements -and (Test-Path -LiteralPath $subModulePath)) {
        try {
            $document = Read-XmlDocument -Path $subModulePath
            $elementIndex = 0
            foreach ($element in @($document.SelectNodes("//*"))) {
                $record = New-ElementRecord -Element $element -ModuleId $moduleId -ModuleFolder $moduleFolder -RelativePath "SubModule.xml" -SourceKind "submodule" -ElementIndex $elementIndex
                $elementCount++
                $attributeCount += $element.Attributes.Count
                if (-not $SkipBroadTables) {
                    [void]$elementRows.Add($record)
                }
                $elementIndex++
            }
        }
        catch {
            [void]$parseErrorRows.Add([pscustomobject]@{
                ModuleId = $moduleId
                ModuleFolder = $moduleFolder
                RelativePath = "SubModule.xml"
                Error = $_.Exception.Message
            })
        }
    }

    $loadOrderIndex++
}

Export-Table -Rows $moduleRows -Path (Join-Path $OutputDir "modules.csv")
Export-Table -Rows $dependencyRows -Path (Join-Path $OutputDir "module_dependencies.csv")
Export-Table -Rows $fileRows -Path (Join-Path $OutputDir "files.csv")
Export-Table -Rows $parseErrorRows -Path (Join-Path $OutputDir "parse_errors.csv")
if (-not $SkipBroadTables) {
    Export-Table -Rows $elementRows -Path (Join-Path $OutputDir "elements.csv")
    Export-Table -Rows $attributeRows -Path (Join-Path $OutputDir "attributes.csv")
}
Export-Table -Rows $cultureRows -Path (Join-Path $OutputDir "cultures.csv")
Export-Table -Rows $kingdomRows -Path (Join-Path $OutputDir "kingdoms.csv")
Export-Table -Rows $clanRows -Path (Join-Path $OutputDir "clans.csv")
Export-Table -Rows $heroRows -Path (Join-Path $OutputDir "heroes.csv")
Export-Table -Rows $characterRows -Path (Join-Path $OutputDir "characters.csv")
Export-Table -Rows $namedObjectRows -Path (Join-Path $OutputDir "named_objects.csv")
Export-Table -Rows $localizationStringRows -Path (Join-Path $OutputDir "localization_strings.csv")
Export-Table -Rows $settlementRows -Path (Join-Path $OutputDir "settlements.csv")
Export-Table -Rows $settlementComponentRows -Path (Join-Path $OutputDir "settlement_components.csv")
Export-Table -Rows $navalMarkerRows -Path (Join-Path $OutputDir "naval_markers.csv")

$summary = [ordered]@{
    GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    PropsPath = $PropsPath
    OutputDir = $OutputDir
    ModuleCount = $moduleRows.Count
    ModuleDataFileCount = $fileRows.Count
    ParseErrorCount = $parseErrorRows.Count
    ElementCount = $elementCount
    AttributeCount = $attributeCount
    BroadTablesSkipped = [bool]$SkipBroadTables
    CultureCount = $cultureRows.Count
    KingdomCount = $kingdomRows.Count
    ClanOrFactionCount = $clanRows.Count
    HeroCount = $heroRows.Count
    CharacterCount = $characterRows.Count
    NamedObjectCount = $namedObjectRows.Count
    LocalizationStringCount = $localizationStringRows.Count
    SettlementCount = $settlementRows.Count
    SettlementComponentCount = $settlementComponentRows.Count
    NavalMarkerCount = $navalMarkerRows.Count
    Notes = @(
        "ConfiguredLoadOrder is the order of module directories passed to this tool, not a launcher-resolved runtime load order.",
        "naval_markers.csv is a deterministic text search aid, not a verified port or shipping-lane list.",
        "elements.csv and attributes.csv are the broad source-of-truth dumps for schema details not covered by focused tables."
    )
}

Export-Json -Value $summary -Path (Join-Path $OutputDir "summary.json")
Export-Json -Value $moduleRows -Path (Join-Path $OutputDir "modules.json")
Export-Json -Value $cultureRows -Path (Join-Path $OutputDir "cultures.json")
Export-Json -Value $kingdomRows -Path (Join-Path $OutputDir "kingdoms.json")
Export-Json -Value $clanRows -Path (Join-Path $OutputDir "clans.json")
Export-Json -Value $heroRows -Path (Join-Path $OutputDir "heroes.json")
Export-Json -Value $characterRows -Path (Join-Path $OutputDir "characters.json")
Export-Json -Value $settlementRows -Path (Join-Path $OutputDir "settlements.json")
Export-Json -Value $settlementComponentRows -Path (Join-Path $OutputDir "settlement_components.json")

Write-Host "ROT static data dump written to: $OutputDir"
Write-Host ("Modules: {0}; files: {1}; elements: {2}; attributes: {3}; parse errors: {4}" -f $moduleRows.Count, $fileRows.Count, $elementCount, $attributeCount, $parseErrorRows.Count)
Write-Host ("Cultures: {0}; kingdoms: {1}; clans/factions: {2}; heroes: {3}; characters: {4}; settlements: {5}" -f $cultureRows.Count, $kingdomRows.Count, $clanRows.Count, $heroRows.Count, $characterRows.Count, $settlementRows.Count)
