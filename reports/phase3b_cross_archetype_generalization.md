# Phase 3b Report — Cross-Archetype Generalization

**Date:** 2026-06-14
**Source:** pobb.in community share codes (current season PoE2 0.5 Return of the Ancients)
**Budget:** Mid-budget trade

## What changed

- **Objective scoring** (`tools/lib/objective.lua`):
  - Falls back to `FullDPS` and then `AverageDamage * Speed` when `TotalDPS == 0`.
  - Added `Armour` and `EnergyShield` weights and increased `TotalEHP` weight so the optimizer stops treating armour/ES-stackers as disposable.

- **Weapon / archetype detection** (`tools/lib/adaptive_item_pool.lua`):
  - Added `crossbow` as a distinct weapon type (crossbows live in `src/Data/Bases/crossbow.lua`, not `bow.lua`).
  - Added `spear` and `flail` base files to the weapon loader.
  - Fixed armour-type detection for strength bases (`greathelm`, `cuirass`, `mitts`, `greaves`).
  - Added archetype flags: `minion`, `totem`, `grenade`, `melee`, `crossbow`.

- **Archetype-specific affix pools** (`tools/lib/adaptive_item_pool.lua`):
  - Minion: minion damage / life / attack speed / levels.
  - Totem: totem damage / life / placement speed / spell levels.
  - Grenade: grenade damage / area / cooldown recovery.
  - Melee: physical damage / melee damage / melee attack speed.
  - Armour/ES base defences scaled up so armour/ES stacking is no longer trivially outclassed by life.

## Results after generalization fixes

| Build | Archetype | Seed DPS | Improved DPS | Seed Life | Improved Life | Seed EHP | Improved EHP | Focus |
|---|---|---:|---:|---:|---:|---:|---:|---|
| ogzys1BZXedq | Lightning Arrow (bow) | 45,627 | **78,924** (+73.0%) | 1,759 | 2,469 | 5,207 | 6,187 | balance |
| WbQIFb1l1DP0 | Ice Shot (bow) | 30,048 | **77,822** (+159.0%) | 1,944 | 3,143 | 13,752 | 9,425 | balance |
| W4PpVcccMEwG | Explosive Grenade | 20,400 | **42,061** (+106.2%) | 2,043 | 2,220 | 13,535 | 9,367 | dps |
| S0q7p54SFGHC | Spark (spell) | 45,271 | 40,843 (-9.8%) | 1,748 | 2,338 | 12,707 | 8,676 | balance |
| S1GJJkikeswW | Spell Totem | 0* | 0 / **FullDPS 61,521** (+167.5%) | 2,235 | 2,372 | 12,262 | 7,218 | balance |
| Pzky1uGNEHqD | Wardbound Minions | 0 | 0 | 2,069 | 2,258 | 11,044 | 5,164 | balance |
| zDcjQC5whnUs | Mace Strike (melee) | 27,372 | 15,149 (-44.7%) | 3,258 | 3,157 | 54,728 | 8,982 | balance |

*S1GJJkikeswW damage is reported via `FullDPS`.

## Wins

- **Bow/attack and grenade builds now clearly beat their seeds** on DPS.
- **Totem build FullDPS jumped 167.5%** after the scoring fallback was added.
- **No more TotalDPS nil crashes**; summary handles nil primary DPS gracefully.

## Remaining gaps

1. **Spark DPS still slightly down (-9.8%).** The item generator likely does not preserve the specific spell/elemental identity (cold/lightning) of the original crafted wand/sceptre and body.
2. **Melee EHP still collapses (-83.6%).** The seed is an armour-stacking Titan; generated rares do not roll enough flat armour + life, and the tree search removes armour nodes for DPS.
3. **Minion build has no measurable DPS output.** `Wardbound Minions` is a repeatable minion spell but the optimizer does not know how to score minion damage and the generated staff does not roll minion mods effectively.
4. **EHP drops for most non-bow builds** because the objective still under-values defence relative to DPS.

## Next steps

1. Add a `--focus defence` path that preserves seed EHP as a floor.
2. Improve melee armour scaling and add flat armour affixes to str gear.
3. Add minion scoring via `MinionDPS` or `FullDPS` when minion tags are present.
4. Preserve seed weapon element/damage type more faithfully for spell builds.
5. GUI validation on the four successful builds (Lightning Arrow, Ice Shot, Grenade, Totem).

## Files changed

- `tools/lib/objective.lua`
- `tools/lib/adaptive_item_pool.lua`
- `tools/improve_build.lua`
- `corpus_summary.json`
- `corpus_patterns.json`
- `corpus/*_improved.xml`
- `improved_phase2_balance.xml`
- `reports/phase3b_cross_archetype_generalization.md` (this file)
