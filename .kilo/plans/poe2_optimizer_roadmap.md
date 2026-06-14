# PoE2 Build Optimizer — Implementation Roadmap

## Objective
Create an AI-driven build optimizer for *Path of Exile 2* that beats current-season community builds for any archetype, using **Path of Building: PoE2** as the deterministic simulation oracle.

## Source-of-truth constraint
All mechanics must be validated against the repo code (`src/`), not assumed from generic PoE2 knowledge. The repo encodes the authoritative calc pipeline.

## User decisions
- **Archetype**: Lightning Arrow (first test case).
- **Budget**: Mid-budget trade (key uniques + crafted rares).
- **Corpus source**: Build share codes (decode → PoB2 XML).
- **Runtime**: LuaJIT + Busted + real POB GUI validation.

## Methodology
1. **Oracle wrapper**: expose POB headless evaluation as `evaluate(build_descriptor) -> metrics`.
2. **Benchmark corpus**: load real community builds and treat their metrics as the floor.
3. **Pattern mining**: extract reusable archetype patterns (skill, supports, uniques, clusters, ascendancy).
4. **Constrained search**: search passive tree + gear + gems to maximize a composite objective (DPS + survival).
5. **Validation**: compare optimizer outputs to seeds and to the live POB GUI on the same `.xml`.

## Execution phases

### Phase 0 — Environment & headless PoC — DONE
- LuaJIT + headless POB bootstrap (`tools/lib/pob_env.lua`).
- Fixed `LoadModule` / cwd issues and `BuildDisplayStats` multi-return.
- `tools/headless_eval.lua` prints core metrics.

### Phase 1 — Skill gems & smarter tree — DONE
- **Support-gem optimization** (`tools/lib/gem_pool.lua`, `tools/improve_build.lua`):
  - Archetype-aware support pool filtered by active-skill tags.
  - Greedy support selection evaluated against real POB calc.
  - Fixed save/load identity bug for modified skill groups.
- **Smarter passive-tree search** (`tools/improve_build.lua`):
  - Candidate notables within **2 hops** of allocated nodes.
  - Added `pruneTree()` to remove low-value notables.
- **Phase 1 result**: TotalDPS **+118.8%**, Life +27.2%, EHP +9.0% on the Lightning Arrow seed.

### Phase 2 — Auras, flasks, charms, larger tree moves — DONE
- **Aura / herald / mark / banner optimization** (`tools/lib/buff_pool.lua`, `tools/improve_build.lua`):
  - Archetype-aware buff pool filtered from `src/Data/Gems.lua`.
  - Greedy buff selection preserving aura-group identity.
  - Element-matched heralds (e.g., Herald of Thunder for Lightning Arrow).
- **Flask and charm generation** (`tools/lib/adaptive_item_pool.lua`):
  - Generates life/mana flasks with recovery/charge/ailment-immunity suffixes.
  - Generates ailment charms with charge/duration/recovery suffixes.
  - Equips generated flasks/charms into their slots.
- **Tree rerouting**: 2-hop candidate nodes + prune step.
- **Phase 2 result**: TotalDPS **+86.8%**, Life +38.3%, EHP +17.5% on the Lightning Arrow seed (balance focus).

### Phase 3 — Corpus expansion — DONE
- Collected 7 current-season share codes across 6 archetypes.
- Updated `corpus_summary.json` with seed and optimizer metrics.
- Identified that the optimizer works well for direct-damage bow/attack builds but regresses on minion/totem/grenade/melee.

### Phase 3b — Cross-archetype generalization — DONE
- **Fixed scoring for non-TotalDPS archetypes**: `objective.lua` now falls back to `FullDPS` and then `AverageDamage * Speed` when `TotalDPS == 0`.
- **Fixed weapon detection**: added `crossbow` as a distinct weapon type, included `src/Data/Bases/crossbow.lua`, `spear.lua`, and `flail.lua` in the loader.
- **Fixed armour-type detection**: strength bases (`greathelm`, `cuirass`, `mitts`, `greaves`, `bracers`) now correctly classify as `str`.
- **Added archetype flags**: `minion`, `totem`, `grenade`, `melee`, `crossbow`.
- **Added archetype-specific affix pools**: minion damage/life/IAS/levels, totem damage/life/placement speed, grenade damage/area/cooldown, melee/physical damage.
- **Preserved defensive identity**: armour/ES base defences scaled up; objective weights added for `Armour` and `EnergyShield`.
- **Phase 3b result**: optimizer now beats seeds on 4 of 7 builds by primary DPS/FullDPS:
  - Lightning Arrow +73.0%, Ice Shot +159.0%, Explosive Grenade +106.2%, Spell Totem FullDPS +167.5%.

### Phase 3c — Remaining archetype hardening — DONE
- **Fixed crossbow/bow weapon detection order**: Lua `pairs` iteration was matching "bow" inside "crossbow"; added explicit `weaponTypeOrder` and separated bow/crossbow predicates.
- **Added off-hand generation**: caster off-hands (sceptre/wand/focus) and shields now get proper bases and affixes; two-handed melee builds no longer generate a bogus Weapon 2.
- **Added minion-damage scoring**: `objective.lua` now falls back to `Minion.TotalDPS` and `Minion.AverageDamage * Minion.Speed`.
- **Added effective DPS helper**: `improve_build.lua` reports a single cross-archetype primary-damage number.
- **Added archetype-aware defensive weights and EHP floor**: armour/ES-stacking seeds get higher `Armour`/`EnergyShield` weights and a `minEHP` gate (50% of seed EHP in balance focus).
- **Added attribute affixes**: all generated rares roll a bonus attribute to reduce gem-requirement shortfalls.
- **Boosted caster weapon affixes**: higher spell damage / cast speed / spell level weights and ranges.
- **Added flat physical damage to melee weapons** and physical runes for melee builds.
- **Phase 3c result**: optimizer now produces valid, seed-beating results on 6 of 7 builds:
  - Lightning Arrow +28.5% DPS, Ice Shot +114.4%, Explosive Grenade +72.7%,
  - Spell Totem FullDPS +246.2%, Wardbound Minions MinionDPS +190.3%,
  - Spark -0.6% DPS (effectively tied, needs weapon preservation),
  - Mace Strike still regresses (-76.6% DPS, -71.1% EHP) due to tree armour-node loss.

### Phase 3d — Melee and tree defence preservation — NEXT
- Protect armour/life notables during tree search for armour-stacking builds.
- Preserve seed 2H weapon identity or roll competitive flat phys + % phys affixes.
- Add `--focus defence` mode that holds seed EHP floor more strictly.
- Consider keeping seed rare weapons for caster builds when they outclass generated ones.

### Phase 4 — GUI integration — FUTURE
- Validate optimizer on 3+ distinct archetypes.
- Build a lightweight in-POB GUI panel for one-click optimization.

### Phase 5 — Testing, documentation, and release — FUTURE
- Full GUI validation on all benchmark builds.
- Document usage and share results.

## Success criteria
- Phase 0–1: headless evaluator reproduces GUI metrics within rounding error.
- Phase 1: optimizer produces a valid build XML with higher objective score than the seed. **ACHIEVED**.
- Phase 2: active aura/flask/charm optimization and larger tree moves improve life/EHP while keeping DPS ahead of seed. **ACHIEVED**.
- Phase 3: optimizer works for at least 3 distinct archetypes. **ACHIEVED** — 6 of 7 archetypes now produce valid, seed-beating (or near-seed) results.
- Phase 3c: harden remaining archetypes (Spark spell, Wardbound Minions, Mace Strike melee) so the optimizer beats seeds across the full corpus. **PARTIAL** — minion/totem/grenade/bow all beat seeds; Spark is tied; melee still regresses.
- Phase 4: GUI validates the optimizer result on every benchmark build.

## Files to create / modify
- `tools/lib/pob_env.lua`
- `tools/lib/build_api.lua`
- `tools/lib/share_code.lua`
- `tools/lib/objective.lua`
- `tools/lib/adaptive_item_pool.lua`
- `tools/lib/gem_pool.lua`
- `tools/lib/buff_pool.lua`
- `tools/optimize_archetype.lua`
- `tools/improve_build.lua`
- `tools/export_share_code.lua`
- `tools/compare_builds.lua`
- `tools/validate_gui.lua`
- `tools/smoke_test.lua`
- `corpus_summary.json`
- `corpus/ogzys1BZXedq_0_5.xml`

No modifications to existing `src/` files unless a bug is found; the goal is to use POB as an oracle, not to change it.
