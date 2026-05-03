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
- `settlements.csv`
- `settlement_components.csv`
- `naval_markers.csv`

`naval_markers.csv` is a deterministic text search aid. Do not treat it as a
verified port list or shipping topology without runtime validation.

Focused JSON files mirror the focused CSVs for easier manual reading.

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

These counts are a local discovery baseline, not committed source data.
