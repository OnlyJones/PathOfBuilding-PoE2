# Phase 2 Report — Lightning Arrow Build Optimizer

**Date:** 2026-06-13  
**Archetype:** Lightning Arrow  
**Budget:** Mid-budget trade  
**Target level:** 90  
**Class / Ascendancy:** Ranger / Deadeye

## Executive summary

TODO: Fill in after ingesting real community builds.

| | Optimizer | Seed mean | Best seed | Delta vs best seed |
|---|---|---|---|---|
| TotalDPS | | | | |
| FullDPS | | | | |
| AverageDamage | | | | |
| Speed | | | | |
| CritChance | | | | |
| TotalEHP | | | | |
| Life | | | | |
| FireResist | | | | |
| ColdResist | | | | |
| LightningResist | | | | |
| ChaosResist | | | | |

## Methodology

1. **Corpus ingestion** — decoded community share codes with `tools/ingest_corpus.lua`.
2. **Pattern extraction** — derived archetype template from frequency tables in `corpus_summary.json`.
3. **Gear search** — generated N random gear sets from `tools/lib/item_pool.lua` and kept the best-scoring after headless evaluation.
4. **Tree search** — greedy / beam search over candidate notables selected by keyword.
5. **Objective** — weighted DPS/EHP/life with hard gates for resistances and attributes (`tools/lib/objective.lua`).
6. **Validation** — loaded optimizer XML into the real POB GUI and compared metrics.

## Corpus

- Number of seed builds: TODO
- Data source: TODO (share codes / poe.ninja / etc.)
- Top skills: TODO
- Top uniques: TODO
- Top rare bases: TODO
- Top notables: TODO

## Optimizer configuration

```
-- Gear sets evaluated: TODO
-- Passive points: TODO
-- Objective weights:
--   TotalDPS = 1.0
--   FullDPS  = 0.5
--   TotalEHP = 0.001
--   Life     = 0.5
-- Hard gates:
--   minLife = 1200
--   minUncappedResist = 0
```

## Optimized build metrics (headless)

Run:

```bash
luajit tools/headless_eval.lua optimized_build.xml
```

TODO: paste output here.

## GUI validation

- Headless DPS: TODO
- GUI DPS: TODO
- Tolerance: ±1%
- Result: TODO (PASS / FAIL)

## Discussion

### Strengths of the optimizer
- Deterministic oracle (POB calc pipeline).
- Can evaluate many gear/tree combinations automatically.
- Objective function enforces survival gates.

### Limitations / simplifying assumptions
- Generated rare items use hand-crafted affix pools, not real trade data.
- No support gem level/quality variation beyond the fixed template.
- No jewel/rune crafting in current item pool.
- Tree search is greedy/beam over a keyword-filtered notable set.
- Comparison is limited to the ingested seed builds.

### Required next steps to beat current-season builds
- TODO: add real community builds to corpus.
- TODO: tune objective weights against seed metrics.
- TODO: expand item pool with current-league uniques and realistic crafted mods.
- TODO: add support-gem selection to the search space.

## Conclusion

TODO: State whether the optimizer meets/exceeds the community floor for Lightning Arrow mid-budget, with caveats.
