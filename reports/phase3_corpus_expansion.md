# Phase 3 Report — Cross-Archetype Corpus Expansion

**Date:** 2026-06-14
**Source:** pobb.in community share codes (current season PoE2 0.5 Return of the Ancients)
**Budget:** Mid-budget trade
**Target level:** 90–97 (seed-dependent)

## Executive summary

The optimizer was run against seven community builds spanning six distinct archetypes.
It improves direct-DPS builds (Lightning Arrow and Ice Shot) substantially, but it degrades DPS for several other archetypes because the current scoring function and item generator are tuned for bow/attack builds and do not yet model minion/totem/grenade/melee mechanics correctly.

| Build | Class / Ascendancy | Main skill | Seed DPS | Improved DPS | Seed Life | Improved Life | Seed EHP | Improved EHP | Focus |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| ogzys1BZXedq | Ranger / Deadeye | Lightning Arrow | 45,627 | **85,216** (+86.8%) | 1,759 | 2,432 | 5,207 | 6,119 | balance |
| WbQIFb1l1DP0 | Ranger / Deadeye | Ice Shot | 30,048 | **77,822** (+159.0%) | 1,944 | 3,143 | 13,752 | 9,425 | balance |
| S0q7p54SFGHC | Sorceress / Stormweaver | Spark | 45,271 | 31,782 (-29.8%) | 1,748 | 2,630 | 12,707 | 9,273 | balance |
| W4PpVcccMEwG | Mercenary / Witchhunter | Explosive Grenade | 20,400 | 0 (-100%) | 2,043 | 2,507 | 13,535 | 12,854 | dps |
| Pzky1uGNEHqD | Mercenary / Gemling Legionnaire | Wardbound Minions | 0 | 0 | 2,069 | 2,243 | 11,044 | 5,582 | balance |
| S1GJJkikeswW | Witch / Infernalist | Spell Totem (Grim Pillars) | 0* | 0 | 2,235 | 2,703 | 12,262 | 7,600 | balance |
| zDcjQC5whnUs | Warrior / Titan | Mace Strike | 27,372 | 5,765 (-78.9%) | 3,258 | 3,401 | 54,728 | 11,030 | balance |

*S1GJJkikeswW reports DPS via FullDPS (22,993) because the main skill is a totem.

## Key findings

1. **Direct-damage bow/attack builds are the easiest wins.** The optimizer's affix pools, support-gem selection, and tree search are all aligned with attack/bow damage.
2. **Minion, totem, grenade, and melee builds are not yet handled.** Generated gear does not roll minion/totem/grenade-specific mods, support-gem compatibility is incomplete, and the EHP calculation collapses for armour-stacking melee builds when rares are replaced.
3. **FullDPS-based archetypes are invisible to the current objective.** The scorer only uses `TotalDPS`; totem and minion builds that report damage through `FullDPS` are scored as zero DPS and therefore not optimized for damage.
4. **EHP drops for most non-bow builds.** The item generator trades armour/ES for life and resists, which destroys the EHP of armour-stackers and ES-stackers.

## Next steps (Phase 3 continued / Phase 4)

1. Add archetype-specific scoring and affix pools:
   - Minion damage / minion life / minion attack speed.
   - Totem damage / totem life / totem placement speed.
   - Grenade damage / grenade cooldown / area damage.
   - Melee / physical / armour-stacking focus.
2. Use `FullDPS` and `AverageDamage` as primary objectives for totem/minion/trigger builds.
3. Detect and preserve defensive identity (armour, evasion, ES stacking) instead of always favouring life.
4. Add support for weapon swaps and dual-wield/off-hand setups (sceptre + wand, etc.).
5. GUI validation on the two successful bow builds to confirm headless/GUI parity.

## Files changed

- `tools/improve_build.lua` — fixed nil `TotalDPS` crash in improvement summary.
- `corpus_summary.json` — expanded to seven builds with optimizer deltas.
- `corpus/*.xml` — added community seed builds.
- `corpus/*_improved.xml` — generated optimizer outputs.
