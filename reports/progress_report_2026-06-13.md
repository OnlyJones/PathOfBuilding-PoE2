# PoE2 Build Optimizer — Progress Report

Date: 2026-06-13

## Goal
Determine whether an AI agent can create Path of Exile 2 builds that beat current-season community builds, using Path of Building: PoE2 as the simulation oracle. The tooling is designed to be **archetype-agnostic**: it should optimize any player's build regardless of class, ascendancy, main skill, or weapon type.

## What was done

### Phase 2 — Auras/heralds, flask/charm generation, and tree rerouting

#### 1. Aura / herald / mark / banner optimization (`tools/lib/buff_pool.lua`, `tools/improve_build.lua`)
- Added an archetype-aware buff pool that filters `src/Data/Gems.lua` for heralds, banners, purities, Discipline, and marks.
- Implemented `optimizeBuffs()`: greedy selection that preserves an existing aura/mark group identity, evaluates each addition against the real POB calc, and keeps the highest-scoring set.
- Heralds are filtered to match the active skill's element (e.g., Herald of Thunder for Lightning Arrow).
- Buffs are added to a separate skill group so they persist through save/load.

#### 2. Flask and charm generation (`tools/lib/adaptive_item_pool.lua`)
- `generateSet()` now creates two flasks and three charms per gear set.
- Flask generator produces life or mana flasks with a useful prefix + suffix (recovery, charge gain, or ailment immunity).
- Charm generator produces ailment charms with charge/duration/recovery suffixes.
- Generated flasks/charms are equipped into `Flask 1/2` and `Charm 1/2/3` slots during improvement.

#### 3. Larger passive-tree moves (`tools/improve_build.lua`)
- Candidate notable search radius expanded from 1 hop to **2 hops** around allocated nodes.
- Added `pruneTree()` to remove allocated notables that no longer improve the objective, freeing points for better nodes or travel.

#### 4. Phase 2 results on the Lightning Arrow Deadeye seed
Command:
```
luajit tools/improve_build.lua corpus/ogzys1BZXedq_0_5.xml --output improved_phase2_balance.xml --points 60 --gear-sets 16 --seed 42 --keep-uniques --focus balance --optimize-gems
```

| Metric | Seed | Phase 2 | Delta |
|--------|------|---------|-------|
| TotalDPS | 45,626.58 | 85,215.82 | **+86.8%** |
| AverageDamage | 16,462.03 | 28,297.67 | **+72.0%** |
| Life | 1,759 | 2,432 | **+38.3%** |
| TotalEHP | 5,206.83 | 6,119.08 | **+17.5%** |
| EnergyShield | 176 | 392 | **+122.7%** |
| Resists | 75/73/75 | 75/75/75 | Capped |

Generated files:
- `improved_phase2_balance.xml` — balance-focused build.
- `improved_phase2_dps.xml` — DPS-focused build (81,850 DPS).

Note: Phase 1's DPS-focused result was higher because Phase 1's item generator could roll very aggressive offence affixes and did not yet generate flasks/charms. Phase 2 trades some peak DPS for significantly higher life and EHP while still beating the seed by a large margin.

### Phase 1 — Skill gems & smarter tree — DONE
- **Support-gem optimization** (`tools/lib/gem_pool.lua`, `tools/improve_build.lua`):
  - Archetype-aware support pool filtered by active-skill tags.
  - Greedy support selection evaluated against real POB calc.
  - Fixed save/load identity bug for modified skill groups.
- **Smarter passive-tree search** (`tools/improve_build.lua`):
  - Candidate notables within **2 hops** of allocated nodes.
  - Added `pruneTree()` to remove low-value notables.
- Phase 1 result: **TotalDPS +118.8%**, Life +27.2%, EHP +9.0%.

### Earlier milestones (retained)
- Headless POB bootstrap, share-code encode/decode, adaptive cross-archetype item pool, generic build improver, smoke tests, and initial GUI validation.

## Key findings
1. **Support gems are the single biggest headless DPS lever**: most of Phase 1's DPS gain came from support selection.
2. **Auras/heralds/marks also matter**, but their value is more conditional and defensively weighted in the balance objective.
3. **Flasks and charms improve EHP and life recovery** while staying within the seed's item slots.
4. **Save/load identity matters** for both main-skill supports and aura/mark groups; in-place edits are required for persistence.
5. Phase 2's balance build has **lower peak DPS than Phase 1** but higher life/EHP, showing the objective profiles are working.

## Next steps (Phase 3)
1. **Corpus expansion**: ingest additional current-season share codes across multiple archetypes.
2. **Trade/budget constraints**: model realistic cost limits for rares and uniques.
3. **GUI integration**: build a lightweight in-POB panel once the optimizer is validated across archetypes.

## Files changed
- `tools/lib/pob_env.lua`
- `tools/lib/build_api.lua`
- `tools/lib/share_code.lua`
- `tools/lib/objective.lua`
- `tools/lib/adaptive_item_pool.lua`
- `tools/lib/gem_pool.lua`
- `tools/lib/buff_pool.lua` (new)
- `tools/optimize_archetype.lua`
- `tools/improve_build.lua`
- `tools/export_share_code.lua`
- `tools/compare_builds.lua`
- `tools/validate_gui.lua`
- `tools/smoke_test.lua`
- `corpus_summary.json`
- `corpus/ogzys1BZXedq_0_5.xml`
