# AGENTS.md

Repository instructions for Codex and other coding agents working on `bkr-rot-compatibility`.

## Project identity

This repository builds a standalone Mount & Blade II: Bannerlord module that makes Banner Kings Redux operate inside Realm of Thrones.

- Repository name: `bkr-rot-compatibility`
- Module ID: `BannerKingsRedux.RealmOfThrones`
- Assembly name: `BannerKingsRedux.RealmOfThrones`
- DLL name: `BannerKingsRedux.RealmOfThrones.dll`
- Namespace root: `BannerKingsRedux.RealmOfThrones`
- Display name: `Banner Kings Redux - Realm of Thrones Compatibility Patch`
- License for this repository's original work: MIT

Target stack:

- Mount & Blade II: Bannerlord `1.3.15`
- War Sails / NavalDLC enabled as module ID `NavalDLC`
- Banner Kings Redux `1.5.x`
- Realm of Thrones `8.x`
- BLSE / Harmony stack
- ButterLib
- UIExtenderEx

North star: make Banner Kings Redux feel native in Realm of Thrones, not merely stop startup crashes. First make the empty compatibility module load, then prevent missing-ID crashes, then add minimal BKR functionality, then build ROT-specific title, culture, shipping, and balance data.

## Codex operating rules

- Keep this file concise enough for Codex to load as repository-level guidance. Do not turn it into a full design doc.
- Before editing, inspect existing files and preserve the current single-project structure unless the task specifically asks for a restructure.
- Make small, reviewable changes. Prefer targeted commits/patches over broad rewrites.
- Do not invent local Bannerlord paths, installed mod versions, ROT StringIds, or BKR API signatures. If the data is not in the repo or the live game files, add a discovery step or leave a clear TODO.
- Do not copy upstream BKR or ROT source, XML, DLLs, textures, assets, or UI layouts into this repo.
- Do not commit generated output, local path files, build artifacts, external binaries, logs, crash dumps, or release zips.
- When a task cannot be fully validated in the Codex environment because Bannerlord/mod DLLs are absent, still run all available static checks and clearly report what could not be validated.
- For tasks that touch module loading, always consider launcher behavior and runtime load order, not just C# compilation.
- Suggest updates to AGENTS.md, especially if information contained becomes outdated or incorrect, but also when new additions are appropriate.
- Suggest creation of agent skills when they are likely to be helpful in upcoming milestones.

## Repository layout

Current intended layout:

```text
bkr-rot-compatibility/
├─ docs/
├─ src/
│  ├─ _module/
│  │  ├─ ModuleData/
│  │  └─ SubModule.xml
│  └─ SubModule.cs
├─ tools/
├─ builds/                         # generated, ignored
├─ obj/                            # generated, ignored
├─ .gitignore
├─ BannerKingsRedux.RealmOfThrones.csproj
├─ BannerKingsRedux.RealmOfThrones.slnx
├─ Directory.Build.props           # local only, ignored
├─ Directory.Build.props.example   # tracked template
├─ LICENSE
└─ README.md
```

Important source-of-truth rules:

- `src/` is edited source.
- `src/_module/` is the source-controlled Bannerlord module template. 
- `src/_module/SubModule.xml` is the source-controlled manifest template.
- `src/_module/ModuleData/` is where original compatibility XML belongs.
- `builds/BannerKingsRedux.RealmOfThrones/` is generated package output and must stay ignored.
- `Directory.Build.props` is developer-local and must stay ignored.
- `Directory.Build.props.example` documents required local properties and may be edited when build setup changes.

## Build and local dependency model

The project is SDK-style while targeting Bannerlord-compatible .NET Framework:

- Target framework: `net472`
- Platform target: `x64`
- Output type: library
- Expected DLL output: `builds/BannerKingsRedux.RealmOfThrones/bin/Win64_Shipping_Client/`

Expected package shape:

```text
builds/BannerKingsRedux.RealmOfThrones/
├─ SubModule.xml
├─ ModuleData/
└─ bin/
   └─ Win64_Shipping_Client/
      └─ BannerKingsRedux.RealmOfThrones.dll
```

Local Bannerlord paths belong in ignored `Directory.Build.props`, based on the tracked example. Do not hardcode a developer's Steam path in the project file.

Expected local properties:

```xml
<BannerlordDir>C:\Program Files (x86)\Steam\steamapps\common\Mount &amp; Blade II Bannerlord</BannerlordDir>
<BannerlordBinDir>$(BannerlordDir)\bin\Win64_Shipping_Client</BannerlordBinDir>
```

Reference game DLLs through `$(BannerlordBinDir)` and keep `Private=false` so TaleWorlds DLLs are not copied into the module package. Add BKR, ROT, Harmony, ButterLib, or UIExtenderEx compile references only when code actually needs them.

Recommended local commands when dependencies are available:

```powershell
dotnet build BannerKingsRedux.RealmOfThrones.csproj -c Debug
dotnet build BannerKingsRedux.RealmOfThrones.csproj -c Release
```

If the environment lacks .NET Framework reference assemblies or Bannerlord/mod DLLs, do not fake a successful build. Check XML validity, project file structure, path handling, and code consistency instead.

## Bannerlord module rules

Bannerlord modules live under the game's `Modules` folder. A module must contain `SubModule.xml`; compiled DLLs must be under `bin\Win64_Shipping_Client`; gameplay XML belongs under `ModuleData`. Keep this repository aligned with that package shape.

For C# entry points:

- The main class should inherit `TaleWorlds.MountAndBlade.MBSubModuleBase`.
- `SubModule.xml` must reference the DLL and class name accurately.
- Apply Harmony patches during submodule load only when the patch target is present.
- Register campaign behaviors from `OnGameStart(Game game, IGameStarter starter)` after confirming `starter is CampaignGameStarter`.
- Use `CampaignGameStarter.AddBehavior(...)` for campaign behaviors.
- Make all behavior registration idempotent to avoid duplicate BKR registry entries after save/load or same-process restarts.

## SubModule.xml dependency direction

The compatibility patch must load after the native stack, NavalDLC, modding dependencies, Banner Kings Redux, and Realm of Thrones modules.

Verified installed module IDs from the project context:

```text
Native
SandBoxCore
Sandbox
CustomBattle
StoryMode
BirthAndDeath
NavalDLC
Bannerlord.Harmony
Bannerlord.ButterLib
Bannerlord.UIExtenderEx
BannerKings.Redux
ROT-Core
ROT-Content
ROT_Map
ROT-Dragon
```

Debug/helper modules discovered locally but not valid hard dependencies:

```text
BetterExceptionWindow
FastMode
```

Preferred dependency direction for `src/_module/SubModule.xml` unless runtime testing proves otherwise:

```xml
<DependedModules>
  <DependedModule Id="Native"/>
  <DependedModule Id="SandBoxCore"/>
  <DependedModule Id="Sandbox"/>
  <DependedModule Id="CustomBattle"/>
  <DependedModule Id="StoryMode"/>
  <DependedModule Id="BirthAndDeath"/>
  <DependedModule Id="NavalDLC"/>

  <DependedModule Id="Bannerlord.Harmony"/>
  <DependedModule Id="Bannerlord.ButterLib"/>
  <DependedModule Id="Bannerlord.UIExtenderEx"/>

  <DependedModule Id="BannerKings.Redux"/>

  <DependedModule Id="ROT-Core"/>
  <DependedModule Id="ROT-Content"/>
  <DependedModule Id="ROT_Map"/>
  <DependedModule Id="ROT-Dragon"/>
</DependedModules>
```

Notes:

- `BirthAndDeath` is a dependency candidate, not permanently settled. Remove it only after testing proves it is not needed.
- The BKR upstream compatibility note uses `realmofthrones.core` as an observed ROT ID, but this project's local scan found ROT IDs as `ROT-Core`, `ROT-Content`, `ROT_Map`, and `ROT-Dragon`. Prefer verified installed IDs in this repo unless fresh evidence says otherwise.
- If BUTR launcher metadata is added, pin BKR to the tested `1.5.x` version and use `LoadBeforeThis`/equivalent ordering so the patch loads after BKR and ROT.

## Legal and redistribution constraints

This module must remain a standalone compatibility patch.

Allowed:

- Reference BKR, ROT, TaleWorlds, Harmony, ButterLib, and UIExtenderEx public APIs at compile time or runtime.
- Reference ROT and BKR objects by runtime `StringId`.
- Author original C# code and original XML compatibility data.
- Link to upstream projects in documentation.
- Depend on installed upstream modules through `SubModule.xml`.

Forbidden:

- Do not redistribute BKR, ROT, TaleWorlds, BLSE, Harmony, ButterLib, UIExtenderEx, or other third-party DLLs.
- Do not copy BKR source files into this repo, even if modified.
- Do not copy BKR `titles.xml` and edit it into ROT form.
- Do not copy ROT XML, textures, scenes, scripts, meshes, or other assets.
- Do not clone either upstream project into this repo and rename it as this patch.
- Do not make BetterExceptionWindow, FastMode, or other local debug helpers required dependencies.

When in doubt, author original compatibility data from scratch and reference upstream data by ID at runtime.

## Implementation architecture

BKR-on-ROT compatibility has three layers. Treat these as the default architecture for future work.

### Layer 1: BKR registry extensions

Banner Kings Redux exposes many `DefaultTypeInitializer<TSelf, TObj>` style registries. The patch should add ROT-specific objects through public `AddObject(...)` paths from campaign startup behaviors.

High-impact registries to inspect or extend:

```text
DefaultLifestyles
DefaultLanguages
DefaultDemesneLaws
DefaultSuccessions
DefaultGovernments
DefaultStartOptions
DefaultRadicalGroups
DefaultInterestGroup
DefaultTitleNames
DefaultPopulationNames
DefaultDynasties
DefaultLegacies
DefaultFiefHeritage
DefaultMarketGroups
DefaultShippingLanes
```

Other registry areas to keep in mind:

```text
DefaultCrimes
DefaultCriminalSentences
DefaultDemands
DefaultCasusBelli
DefaultBannerKingsEvents
DefaultInvasions
DefaultCustomTroopPresets
DefaultMercenaryPrivileges
DefaultSchemes
BKVillageTypes
DefaultCulturalStandings
BKSkillEffects
BKTraits
DefaultTraitEffects
DefaultCourtExpenses
DefaultCouncilPositions
DefaultCouncilTasks
DefaultLegacyTypes
BKBuildings
DefaultVillageBuildings
```

Rules for registry code:

- Register from a `CampaignBehaviorBase` added through `CampaignGameStarter`.
- Run on both new campaign and loaded campaign paths where appropriate.
- Make registration idempotent. Check existing `All` entries or keep a guarded local state.
- Null-check every ROT culture, kingdom, clan, hero, settlement, and BKR type before use.
- Do not assume Calradian cultures like `empire`, `vlandia`, `nord`, or towns like `town_V1` exist in ROT.
- Log skipped registrations with enough context to fix missing IDs.

### Layer 2: original ROT title XML

BKR's feudal hierarchy is XML-driven. This patch should ship its own ROT-specific title hierarchy under `src/_module/ModuleData/`, usually as `titles.xml` once the exact BKR XML registration is confirmed.

Rules for title XML:

- Write original XML from scratch.
- Reference only ROT `Kingdom.StringId`, `Hero.StringId`, and `Settlement.StringId` values verified by a live data dump.
- Do not copy or modify BKR's Calradia title hierarchy.
- Do not include Calradian title entries.
- Treat every `deJure`, `faction`, `settlement`, and culture reference as crash-sensitive.
- Use BKR-supported values for `government`, `succession`, `inheritance`, and `genderLaw`, or register new values before referencing them.
- Keep title work data-first and test incrementally. A minimal valid hierarchy is better than a large unverified hierarchy.

Useful BKR title concepts:

```text
kingdom -> duchy -> county -> barony -> lordship
faction      = Kingdom.StringId
settlement   = Settlement.StringId
deJure       = Hero.StringId
government   = BKR government StringId
succession   = BKR succession StringId
inheritance  = Primogeniture or Seniority, unless BKR supports more
genderLaw    = Agnatic, Cognatic, AgnaticCognatic, or Enatic
```

### Layer 3: narrow runtime guards and Harmony patches

Some BKR code assumes Calradian IDs. Patch only the specific paths that crash or misbehave under ROT.

Known high-risk path:

```text
DefaultShippingLanes.Initialize
```

Upstream analysis says BKR 1.5.x default shipping lanes use `Settlement.All.First(...)` with Calradian settlement IDs such as `town_S4` and `town_EN2`. In ROT those IDs are absent, so initialization can throw `InvalidOperationException: Sequence contains no matching element`.

Preferred fix order:

1. If contributing to BKR upstream, replace hard `First(...)` lookups with `FirstOrDefault(...)`, skip missing ports, and skip lanes with fewer than two valid ports.
2. In this patch, if upstream does not provide null guards, add a narrow Harmony prefix for `DefaultShippingLanes.Initialize` that skips the default Calradian initialization and registers ROT lanes instead.
3. Keep the patch isolated in a file such as `ShippingLanesPatch.cs`.
4. If a public `ShippingLane` constructor/factory is unavailable, isolate reflection in a small helper and fail gracefully with logging.

Other known risks:

- `titles.xml` references to missing heroes or settlements cause BKR title-loader crashes.
- `Helpers.GetCulture(string id)` may return null; most callers are safe, but any dereference must be guarded.
- `BKShippingBehavior.OnWeeklyTick` may spawn merchant notables from lane culture. ROT lanes can leave `culture` null to skip culture-specific notable spawning until templates exist.
- Bandit integrations should rely on ROT registering its bandits through Bannerlord's `Clan.BanditFactions`.

## Data discovery workflow

Do not author large ROT compatibility XML or code against guessed IDs. First build or use a diagnostic dumper that records live data from the active ROT campaign environment.
Source data is found in installed ROT modules (eg: '$<bannerlorddir>/Modules/ROT-Core/ModuleData' ). Use all .xml and .xslt

Keep data discovery separate from lore research:

- Raw ROT data proves only what the installed ROT modules or live runtime expose.
- Canon research can guide flavor, names, and rationale, but it does not override ROT gameplay IDs or relationships.
- ROT adaptation wins over external canon for in-game integration unless runtime testing proves the data is wrong.
- Original BKR-ROT compatibility lore is allowed when BKR systems need data ROT does not define, but it must be clearly labeled as non-canon compatibility interpretation.

Minimum data to dump:

```text
modules and load order
cultures
kingdoms
clans
heroes, rulers, and lords
settlements
towns
castles
villages
ports or coastal settlement candidates
settlement owners
settlement cultures
ROT naval/War Sails relevant markers, if exposed
```

Discovery output should go to logs or generated docs, not hardcoded immediately into source. Good destinations are `docs/` for curated, reviewed ID inventories or ignored local logs for raw dumps.

When implementing a dumper:

- Source data is found in installed ROT modules (eg: '$<bannerlorddir>/Modules/ROT-Core/ModuleData' )
- Use all .xml and .xslt as source material
- Start static installed-file discovery with `tools/Export-RotData.ps1`; add a live in-game dumper later for runtime-only data.
- Require joined or associated data to be linked by ID or another deterministic reference. No guessing or inference. 
- Include module ID/load-order information.
- Avoid requiring debug/helper modules.
- Make it safe to run in a fresh campaign.
- Can have CSV output or whatever is preferred for efficiency.
- JSON or another file format option as a secondary output to assist with human-readability and organization.
- It is intended to build a tool or script that allows searching dumped data. Design output to facilitate this.
- Do not drop any data columns or properties.

## Shipping and NavalDLC rules

Shipping is a separate workstream, not incidental title data.

Goals:

- Keep War Sails / NavalDLC enabled and functional.
- Avoid fighting ROT's own naval/map behavior.
- Replace or bypass BKR's Calradian shipping lanes when running in ROT.
- Register original ROT lanes connecting verified ROT ports.
- Test topology and pathing with BKR shipping console commands.

Candidate routes must be based on verified ROT settlement IDs. Start small with a minimal connected port graph, then expand into Westeros, Essos, and Narrow Sea routes.

Do not set lane culture unless the target culture has valid notable templates and BKR notable spawning has been tested.

## Save-game and runtime assumptions

- Test compatibility on fresh ROT campaigns.
- Do not promise that saves started on Calradia will work after switching to ROT geography.
- If this patch adds saveable classes, use a unique save ID range, preferably `>= 10000`, to avoid BKR collisions.
- Reset or guard static runtime state carefully when returning to the main menu and starting/loading another campaign in the same process.

## Milestone order

Follow this order unless the user explicitly changes priorities:

1. Finalize `src/_module/SubModule.xml` dependency list and metadata.
2. Troubleshoot launcher/runtime startup with a controlled baseline.
3. Add a logging-only `MBSubModuleBase` smoke test.
4. Confirm an empty module loads after BKR and ROT.
5. Build a ROT data discovery/dump utility.
6. Document verified ROT IDs.
7. Add minimal crash-prevention patches, starting with shipping initialization if needed.
8. Add minimal BKR registry data for ROT cultures and settlements.
9. Add minimal original ROT title hierarchy.
10. Add ROT shipping lanes and NavalDLC-safe tests.
11. Expand lore, balance, languages, laws, dynasties, books/flavor, and economy data.
12. Package and regression-test without bundled upstream assets.

Tier 1 done means:

- Module appears in launcher.
- Load order is correct.
- Fresh ROT campaign starts.
- Patch logs confirm it loaded.
- BKR initialization does not crash on missing Calradia settlements.
- BKR menus or screens are visible enough for feature testing.

Tier 2 done means:

- ROT title hierarchy is playable.
- Succession and inheritance can be tested.
- ROT shipping topology and paths work.
- NavalDLC remains active.
- ROT cultures have enough BKR data for menus and UI to feel intentional.

## Runtime test checklist

Basic checks:

```text
1. Vanilla Bannerlord 1.3.15 starts.
2. NavalDLC / War Sails is enabled.
3. BLSE and Harmony stack load.
4. Banner Kings Redux 1.5.x loads without this patch in its supported baseline.
5. Realm of Thrones 8.x fresh campaign starts without this patch.
6. This patch appears in the launcher.
7. This patch loads after BKR and ROT.
8. Fresh ROT campaign starts with this patch enabled.
9. Logs confirm this patch loaded and registered only expected content.
```

BKR-specific checks after compatibility code exists:

```text
1. No `Sequence contains no matching element` from BKR shipping initialization.
2. BK kingdom screen opens.
3. ROT kingdoms/titles appear when declared.
4. Enter a ROT settlement and confirm BK menu options are not empty.
5. Lifestyle picker opens for ROT-cultured heroes when lifestyles exist.
6. `bannerkings.shipping_topology` reports registered ROT lanes.
7. `bannerkings.shipping_path <fromId> <toId>` returns a path between tested ROT ports.
8. `bannerkings.give_title <Title> | <Hero>` can transfer a test title.
9. Save/load does not duplicate registrations or crash.
```

Known BKR 1.5.x useful cheats, when cheat mode is enabled:

```text
bannerkings.give_title <Title> | <Hero>
bannerkings.start_rebellion <settlement>
bannerkings.add_piety <amount>
bannerkings.add_career_points
bannerkings.finish_claims
bannerkings.shipping_topology
bannerkings.shipping_path <fromId> <toId>
bannerkings.give_player_full_peerage
bannerkings.spawn_bandit_hero
bannerkings.advance_era <culture_id>
```

## C# conventions

- Use namespace `BannerKingsRedux.RealmOfThrones` or a child namespace.
- Keep the public surface minimal.
- Prefer `internal` for implementation types unless Bannerlord, Harmony, or serialization requires public.
- Prefer explicit null checks and helpful logs over assumptions.
- Use `FirstOrDefault`, `SingleOrDefault`, or dictionary lookup plus validation; avoid `First`/`Single` on game data.
- Keep Harmony patches narrow, named, and documented with the exact upstream method they patch.
- Avoid broad transpilers unless a prefix/postfix cannot solve the problem.
- Isolate reflection in one helper per target area.
- Do not introduce new dependencies without a clear need and a project-file update.
- Preserve `net472` compatibility.
- Do not use APIs unavailable in Bannerlord 1.3.15 or BKR 1.5.x unless gated and documented.

Recommended code organization as implementation grows:

```text
src/
├─ SubModule.cs                         # MBSubModuleBase entry point
├─ Compatibility/
│  ├─ ModIds.cs                         # module IDs and loaded checks
│  └─ CompatibilityState.cs             # runtime flags, if needed
├─ Behaviors/
│  ├─ RotBkContentBehavior.cs           # BKR registry additions
│  └─ RotDataDumpBehavior.cs            # optional diagnostic dumper
├─ Patches/
│  └─ ShippingLanesPatch.cs             # DefaultShippingLanes.Initialize guard
├─ Shipping/
│  ├─ RotShippingLaneRegistrar.cs
│  └─ ShippingLaneFactory.cs            # public API or isolated reflection
└─ Utilities/
   ├─ Log.cs
   └─ ObjectLookup.cs
```

Only create folders when there is real code to put in them.

## XML and localization conventions

- Keep module XML under `src/_module/ModuleData/`.
- Use UTF-8 XML.
- Use stable, unique IDs prefixed for this module where the schema allows it.
- Prefer adding original compatibility XML over modifying upstream XML.
- Validate every referenced `StringId` against a documented ROT data dump.
- Keep localization keys unique. Do not reuse upstream localization IDs unless intentionally overriding text.
- Add comments sparingly; comments should explain data source or risk, not restate XML names.

## Documentation expectations

Use `docs/` for durable project knowledge, especially:

```text
docs/MODULE_IDS.md       # verified module IDs and load order
docs/ROT_DATA_IDS.md     # curated ROT culture/kingdom/settlement/hero IDs
docs/TESTING.md          # launcher/runtime validation steps
docs/SHIPPING.md         # ROT port graph and lane rationale
docs/LORE.md             # canon, ROT adaptation, and BKR-ROT compatibility lore provenance
```

Raw generated dumps should be ignored unless curated into a stable doc.

## Git hygiene

Do not commit:

```text
.vs/
*.user
obj/
bin/
builds/
Builds/
Directory.Build.props
*.dll
*.pdb
*.zip
logs/
crashes/
external game or mod binaries
```

Before finishing a task, inspect the diff and ensure no local paths, binaries, generated files, or third-party assets were added.

## What to do when blocked

- Missing Bannerlord DLLs: verify project/XML/static code and state that a local game install is required for compilation.
- Missing BKR/ROT APIs: inspect available references if present; otherwise write narrow interfaces/TODOs and avoid guessing signatures.
- Missing ROT IDs: add or improve the data dumper; do not hardcode guessed IDs.
- Launcher crash before code runs: check `SubModule.xml`, DLL path, class type name, dependency IDs, target framework, x64 output, and blocked/untrusted DLL status before changing compatibility logic.
- Runtime crash from missing IDs: identify the exact `StringId`, add a guard or corrected data, and add it to the relevant documented ID inventory.

## Source references for future agents

These references informed this repository guidance. Prefer the repository files and verified local data when they conflict with generic docs.

- OpenAI Codex AGENTS.md guide: `https://developers.openai.com/codex/guides/agents-md`
- OpenAI Codex best practices: `https://developers.openai.com/codex/learn/best-practices`
- BKR ROT compatibility outline: `https://github.com/GIO443/bannerlord-banner-kings-redux/blob/main/docs/dev/banner-kings-rot-compat.md`
- TaleWorlds module quick guide: `https://moddocs.bannerlord.com/asset-management/quickguide_create_a_mod/`
- TaleWorlds XML merging guide: `https://moddocs.bannerlord.com/bestpractices/merging_module_xml_files_with_native/`
- TaleWorlds API docs: `https://apidoc.bannerlord.com/`
