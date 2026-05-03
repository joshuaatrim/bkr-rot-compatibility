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
```

Primary outputs:

- `modules.csv` and `module_dependencies.csv`
- `files.csv`
- `elements.csv`
- `attributes.csv`
- `cultures.csv`, `kingdoms.csv`, `clans.csv`, `heroes.csv`
- `settlements.csv` and `settlement_components.csv`
- `naval_markers.csv`
- `summary.json` and focused JSON files

Generated dumps are intentionally ignored by git.

Possible future tools:

- ROT data discovery dumps
- settlement/culture/kingdom ID exports
- title XML validation
- release packaging
- clean build helpers
