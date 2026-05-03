# Tools

Helper scripts for local discovery, validation, and packaging live here.

## ROT static data dump

`Export-RotData.ps1` reads `Directory.Build.props`, expands the configured
ROT module folders, parses every `.xml` and `.xslt` file under each
`ModuleData` folder, and writes searchable CSV plus focused JSON exports under
`data-dumps/`.

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-RotData.ps1
```

Common options:

```powershell
# Write to a stable local folder instead of a timestamped one.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-RotData.ps1 -OutputDir .\data-dumps\rot-static-current

# Use explicit module directories instead of Directory.Build.props.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-RotData.ps1 -ModuleDir "C:\Path\To\ROT-Core","C:\Path\To\ROT-Content","C:\Path\To\ROT_Map","C:\Path\To\ROT-Dragon"

# Include slower computed element paths in the broad element/attribute dumps.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-RotData.ps1 -IncludeXPath

# Generate only focused curation/debug tables, skipping huge elements/attributes CSVs.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-RotData.ps1 -SkipBroadTables
```

Primary outputs:

- `modules.csv` and `module_dependencies.csv`
- `files.csv`
- `elements.csv`
- `attributes.csv`
- `cultures.csv`, `kingdoms.csv`, `clans.csv`, `heroes.csv`
- `characters.csv`, including `NPCCharacter` rows from `.xml` and `.xslt`
- `named_objects.csv`, linking object IDs to localized/display names
- `localization_strings.csv`, extracting string IDs and text
- `settlements.csv` and `settlement_components.csv`
- `naval_markers.csv`
- `summary.json` and selected focused JSON files

Generated dumps are intentionally ignored by git.

## ROT data search

`Search-RotData.ps1` searches focused dump CSVs and prints related data for
people, clans, kingdoms, and settlements. It auto-selects the newest dump that
contains `characters.csv` and `named_objects.csv`.

Run from the repository root:

```powershell
# Person lookup, including clan/kingdom when linked.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Search-RotData.ps1 "Stannis"

# Settlement lookup, including owner clan and kingdom.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Search-RotData.ps1 "Dragonstone" -Kind Settlement

# Clan or kingdom lookup, including controlled settlements.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Search-RotData.ps1 "Baratheon,Stannis" -Kind Clan
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Search-RotData.ps1 "dragonstone" -Kind Kingdom

# Machine-readable output.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Search-RotData.ps1 "town_EW1" -Exact -Json
```

Possible future tools:

- ROT data discovery dumps
- settlement/culture/kingdom ID exports
- title XML validation
- release packaging
- clean build helpers
