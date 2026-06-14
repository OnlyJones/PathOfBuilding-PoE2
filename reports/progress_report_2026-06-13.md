# PoE2 Lightning Arrow Build Optimizer — Progress Report

Date: 2026-06-13

## Goal
Determine whether an AI agent can create Path of Exile 2 Lightning Arrow Deadeye builds comparable to current-season community builds, using Path of Building: PoE2 as the simulation oracle.

## What was done

### 1. Environment & tooling fixes
- Fixed `tools/lib/pob_env.lua` headless bootstrap:
  - Exposed `POB_PROJECT_ROOT` global.
  - Overrode `LoadModule` / `PLoadModule` so POB can load `src/Data/` modules after cwd is restored to the project root.
  - Fixed wrapper to preserve multiple return values from `Modules/BuildDisplayStats` (was collapsing `extraSaveStats`/`minionDisplayStats` to `nil`, breaking save).
- Fixed `tools/lib/share_code.lua` URL regexes so pobb.in (and other sites) are rewritten correctly when a full URL is passed.

### 2. Real community corpus ingestion
- Searched current-season sources (Maxroll, Mobalytics, PoB Archives, DuckDuckGo/pobb.in).
- Found and successfully decoded one working PoE2 0.5 community Lightning Arrow Deadeye share code:
  - `https://pobb.in/ogzys1BZXedq`
  - Level 91 Ranger / Deadeye
- Normalized the build XML (`targetVersion`, `treeVersion`, `classId`) so it loads with the current 0.5 tree data.
- Saved to `corpus/ogzys1BZXedq_0_5.xml` and created `corpus_summary.json`.

### 3. New generic build-improver tool
- Created `tools/improve_build.lua`:
  - Accepts **any** PoB2 XML file or share code / URL as input.
  - Loads the seed build, extracts class, ascendancy, main skill, supports, and baseline metrics.
  - Re-generates gear while preserving the seed's skill setup and tree identity.
  - Re-optimizes the passive tree using the fast incremental `getNodeCalculator`.
  - Outputs an improved build XML and prints a delta summary.
- Example run on the community build:
  - `luajit tools/improve_build.lua corpus/ogzys1BZXedq_0_5.xml --output improved_build.xml --points 40 --gear-sets 6 --seed 42`
  - Result: **DPS +21.0%**, **Life +35.9%**.

### 4. Optimizer improvements
- Updated `tools/lib/item_pool.lua`:
  - Stronger endgame bases (Gemini Bow, Primed Quiver, Avian Mask, Slipstrike Vest, Torn Gloves, Charmed Shoes, Utility Belt, Gold Ring, Bloodstone Amulet).
  - Weapon runes modelled as implicits (`{rune}Adds # to # Lightning Damage`).
  - Higher damage, life, resistance, and attribute rolls.
  - Guaranteed life + resistance on armour/jewellery.
  - Guaranteed attributes on jewellery.
- Updated `tools/optimize_archetype.lua`:
  - 7-link Lightning Arrow setup: Lightning Arrow + Added Lightning Damage + Elemental Damage with Attacks + Rapid Attacks + Chain + Stoicism + Elemental Armament.
  - Added Herald of Thunder aura.
  - Rewrote tree search to use POB's fast incremental `getNodeCalculator` instead of full save/reload per candidate, making 60-point beam search feasible.
  - Fixed tree-optimizer bug that deallocated the class-start node, causing it to pick zero notables.
  - Curated notable candidate list based on the ingested community build.

### 5. Optimized build metrics (best so far)
| Metric | Value | vs Community |
|--------|-------|--------------|
| TotalDPS | 55,026.75 | **+20.6%** |
| AverageDamage | 17,609.69 | +7.0% |
| Speed | 3.12 | +15.0% |
| CritChance | 13.98% | +179.6% |
| Life | 4,265 | +142.5% |
| TotalEHP | 7,648.82 | +46.9% |
| Fire/Cold/Lightning Resist | 75 / 34 / 75 | cold not capped |
| Evasion | 565 | -85.5% |

## Key findings
1. The headless POB pipeline works: we can load real community builds, evaluate them, generate builds, and compare them quantitatively.
2. With a stronger item pool and fast incremental tree evaluation, the optimizer now **exceeds the community build on DPS, life, and EHP** (+20.6% DPS, +142.5% life, +46.9% EHP).
3. The remaining weakness is **cold resistance** (34% vs 73%) and **evasion** (the optimizer favours armour/life bases over evasion bases).
4. The biggest remaining opportunity is cold-resistance coverage and evasion bases to match community EHP quality.

## Next steps
1. **Fix cold resistance**: ensure gear generation provides enough cold resistance, or allow the tree to pick cold-resistance nodes.
2. **Evasion bases**: add more evasion armour bases to the pool and weight them for Lightning Arrow builds.
3. **Collect more codes**: continue searching for additional current-season pobb.in/PoB Archives PoE2 0.5 Lightning Arrow share codes to expand the corpus and reduce variance in the community floor.
4. **GUI validation**: load the optimized build in the real POB GUI and confirm headless metrics match.
5. **Trade/budget constraints**: model mid-budget trade limits more realistically instead of allowing arbitrary rares.

## Files changed
- `tools/lib/pob_env.lua`
- `tools/lib/build_api.lua`
- `tools/lib/share_code.lua`
- `tools/lib/item_pool.lua`
- `tools/optimize_archetype.lua`
- `tools/improve_build.lua` (new)
- `tools/smoke_test.lua`
- `corpus_summary.json` (new)
- `corpus/ogzys1BZXedq_0_5.xml` (new)
- `community_builds/ogzys1BZXedq.xml` and `ogzys1BZXedq_0_5.xml` (new)
- `optimized_build.xml`
- `improved_build.xml`
