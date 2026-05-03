# ROT Data Dump

Static ROT data discovery starts with `tools/Export-RotData.ps1`.

The tool reads the local module paths from `Directory.Build.props`, parses all
`.xml` and `.xslt` files under the configured ROT `ModuleData` folders, and
writes ignored CSV/JSON output under `data-dumps/`.

## Usage

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-RotData.ps1
```

The default output path is timestamped:

```text
data-dumps/rot-static-YYYYMMDD-HHMMSS/
```

Use `-OutputDir` for a stable local path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-RotData.ps1 -OutputDir .\data-dumps\rot-static-current
```

Use `-SkipBroadTables` when you only need focused curation/debug tables and do
not need the large `elements.csv` and `attributes.csv` files:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Export-RotData.ps1 -SkipBroadTables
```

## Output

The broad source-of-truth tables are:

- `elements.csv`: every parsed XML/XSLT element, with source module, file, element ordinal, common ID/name attributes, and direct text.
- `attributes.csv`: every parsed XML/XSLT attribute as one searchable row.
- `files.csv`: source file inventory.
- `modules.csv` and `module_dependencies.csv`: module metadata and declared dependencies.

Focused tables are convenience views for compatibility work:

- `cultures.csv`
- `kingdoms.csv`
- `clans.csv`
- `heroes.csv`
- `characters.csv`
- `named_objects.csv`
- `localization_strings.csv`
- `settlements.csv`
- `settlement_components.csv`
- `naval_markers.csv`

`characters.csv` includes `NPCCharacter` rows from both `.xml` and `.xslt`
sources. This is important because files such as `lords.xslt` can be the source
that links a character ID to a display name.

`named_objects.csv` is the first place to look when relating an object ID to a
human-readable name, localization key, source file, and enclosing XSLT template
match.

## Searching

Use `tools/Search-RotData.ps1` for common relationship lookups over the focused
CSV files:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Search-RotData.ps1 "Stannis"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Search-RotData.ps1 "Dragonstone" -Kind Settlement
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Search-RotData.ps1 "Baratheon,Stannis" -Kind Clan
```

The search tool links:

- people to `Hero` data, clan/faction, kingdom, culture, and occupation
- clans to owner, kingdom, initial home settlement, and controlled settlements
- kingdoms to ruler, clans, and controlled settlements
- settlements to owner clan, owner hero, kingdom, culture, type, and port markers

`naval_markers.csv` is a deterministic text search aid. Do not treat it as a
verified port list or shipping topology without runtime validation.

Selected focused JSON files mirror smaller focused CSVs for easier manual
reading. Large relationship tables such as `named_objects.csv` and
`localization_strings.csv` are CSV-only by default.

## Current Local Baseline

The first successful local run parsed:

- 4 configured ROT modules
- 167 `.xml` and `.xslt` files
- 253,824 XML/XSLT elements
- 478,100 attributes
- 0 parse errors

Focused table counts from that run:

- 34 cultures
- 27 kingdoms
- 233 clans/factions
- 1,012 heroes
- 1,037 settlements

Newer dumps also include character, named-object, and localization-string
focused tables. Use the current `summary.json` for their exact counts.

These counts are a local discovery baseline, not committed source data.
