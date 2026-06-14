# PoE2 Build Optimizer — Progress Report

Date: 2026-06-13

## Goal
Determine whether an AI agent can create Path of Exile 2 builds that beat current-season community builds, using Path of Building: PoE2 as the simulation oracle. The tooling is designed to be **archetype-agnostic**: it should optimize any player's build regardless of class, ascendancy, main skill, or weapon type.

## What was done

### 1. Environment & tooling fixes
- Fixed `tools/lib/pob_env.lua` headless bootstrap:
  - Exposed `POB_PROJECT_ROOT` global.
  - Overrode `LoadModule` / `PLoadModule` so POB can load `src/Data/` modules after cwd is restored to the project root.
  - Fixed wrapper to preserve multiple return values from `Modules/BuildDisplayStats`.
- Fixed `tools/lib/share_code.lua` URL regexes and added **share-code encoding** (`tools/export_share_code.lua`).

### 2. Real community corpus ingestion
- Found and decoded a current-season PoE2 0.5 Lightning Arrow Deadeye share code:
  - `https://pobb.in/ogzys1BZXedq`
  - Level 91 Ranger / Deadeye
- Saved to `corpus/ogzys1BZXedq_0_5.xml` and created `corpus_summary.json`.

### 3. Cross-archetype adaptive item pool
- Replaced the Lightning-Arrow-only pool with `tools/lib/adaptive_item_pool.lua`:
  - Detects weapon type (bow, wand, staff, claw, dagger, melee) and armour type (dex/str/int) from **seed gear**.
  - Filters generated bases to match the seed's weapon and armour preferences.
  - Adds `% increased Evasion Rating`, `% increased Armour`, and `% increased Energy Shield` affixes based on armour type.
  - Registers **seed unique items** so the optimizer can keep and reuse them.
  - Generates shareable pobb.in URLs via `tools/export_share_code.lua`.

### 4. Generic build-improver tool
- `tools/improve_build.lua` now:
  - Accepts any PoB2 XML, share code, or URL.
  - Detects archetype from main skill + equipped gear.
  - Keeps seed uniques by default (`--keep-uniques`) while upgrading rare slots.
  - Supports `--focus dps|balance|defence` objective profiles.
  - Supports `--slots` targeting and `--replace-uniques`.
  - Example on the Lightning Arrow seed with `--keep-uniques --focus balance`:
    - **TotalDPS: 45,626 → 89,482 (+96.1%)**
    - **Life: 1,759 → 2,237 (+27.2%)**
    - **TotalEHP: 5,207 → 5,676 (+9.0%)**
    - All elemental resistances capped.

### 5. GUI validation
- Loaded `improved_balance.xml` in the real Path of Building: PoE2 GUI.
- Headless and GUI Calcs-tab values match within rounding:
  - TotalDPS: 89,481.5
  - Life: 2,237
  - EHP: 5,676
  - Evasion: 2,279
  - Resists: 75 / 75 / 75

## Key findings
1. The headless POB pipeline is validated against the live GUI: generated builds load and produce identical stats.
2. Keeping the seed's unique items while re-rolling rares produces a **large DPS uplift** (+96%) without sacrificing defences.
3. Adaptive base/affix selection works: the optimizer now stays within the seed's archetype (weapon type, armour type, elemental damage type).
4. Resistances are now reliably capped via guaranteed double-resist rolls on armour and jewellery.

## Next steps
1. **Expand unique database**: add more commonly-used build-defining uniques to the pool.
2. **Skill gem optimization**: suggest/upgrade support gems based on main skill tags.
3. **Aura/flask/charm optimization**: generate sensible flask/charm sets and auras.
4. **Tree rerouting**: allow larger tree moves, not just proximity-based additions.
5. **Corpus expansion**: ingest additional current-season share codes across multiple archetypes.
6. **Trade/budget constraints**: model realistic cost limits for rares and uniques.

## Files changed
- `tools/lib/pob_env.lua`
- `tools/lib/build_api.lua`
- `tools/lib/share_code.lua`
- `tools/lib/objective.lua`
- `tools/lib/adaptive_item_pool.lua` (new, replaces item_pool.lua)
- `tools/lib/base64.lua`
- `tools/optimize_archetype.lua`
- `tools/improve_build.lua`
- `tools/export_share_code.lua` (new)
- `tools/compare_builds.lua` (new)
- `tools/validate_gui.lua`
- `tools/smoke_test.lua`
- `corpus_summary.json`
- `corpus/ogzys1BZXedq_0_5.xml`
- `community_builds/ogzys1BZXedq.xml` and `ogzys1BZXedq_0_5.xml`
- `.gitignore`
