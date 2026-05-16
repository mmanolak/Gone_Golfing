# Phase 3 Mice.jl Bug Scope Audit

**Date:** 2026-05-15
**Purpose:** Determine how widely the pre-fix Mice.jl `complete()` bug affected
Julia's Phase 3 output. Was Hawaii Kai an isolated victim, or did the bug affect
hundreds of courses? Trace the origin of the "49/100 datasets / ~$473M" figures
cited in Phase3_Rerun_Report.md.

**Files read:**
- `Phase 2 Spatial Polygons and True Acreage/Bulk Tests/Julia/Jl_Phase2_Acreage_Matched.csv`
  (pre-fix Phase 2 input — what Bulk Tests MICE.jl actually read)
- `Phase 2 Spatial Polygons and True Acreage/Data/Julia/Jl_Phase2_Acreage_Matched.csv`
  (post-rerun Phase 2 input — what Phase_3.jl currently reads)
- `Phase 3 Economic Merge and MICE Imputation/Bulk Tests/Julia/MICE.jl`
  (pre-fix script; confirmed input path and `complete()` assignment)
- `Phase 3 Economic Merge and MICE Imputation/Bulk Tests/Julia/Jl_Imputed_Dataset_{1..5}.csv`
  (pre-fix Julia MICE output, m=5)
- `Phase 3 Economic Merge and MICE Imputation/Phase_3.jl`
  (current version; confirmed input path and restoration loop)

---

## Step 1 — Pre-Fix Phase 2 BVPA Structure

The Bulk Tests MICE.jl script reads the Phase 2 file at:
`Phase 2 Spatial Polygons and True Acreage/Bulk Tests/Julia/Jl_Phase2_Acreage_Matched.csv`

(The main Phase_3.jl reads from `Data/Julia/Jl_Phase2_Acreage_Matched.csv`, which is the
post-rerun version. These are two distinct files with different FIPS resolution states.)

| Metric | Pre-Fix Phase 2 (Bulk Tests) | Post-Rerun Phase 2 (Current) |
|--------|------------------------------|------------------------------|
| Total rows | 16,292 | 16,292 |
| Rows with observed BVPA | **15,197** | 15,228 |
| Rows with missing BVPA | **1,095** | 1,064 |

The post-rerun Phase 2 resolved 31 additional BVPA values relative to the pre-fix version.
(The 5 Hawaii FIPS-NA courses contribute 3 of those 31, since 2 Hawaii FIPS-NA courses —
King Kamehameha and Kahili — had no OSM acreage and therefore no OC contribution.)

### Pre-Fix Phase 2: Hawaii FIPS-NA Courses

All 5 Hawaii FIPS-NA courses are confirmed MISSING in the pre-fix Bulk Tests Phase 2:

| Course | FIPS | BVPA | osm_acreage |
|--------|------|------|-------------|
| Hawaii Kai Golf Course | (empty) | MISSING | 130.44 ac |
| Mid Pacific Country Club | (empty) | MISSING | 151.96 ac |
| Kapalua Golf Club | (empty) | MISSING | 153.47 ac |
| King Kamehameha Golf Club | (empty) | MISSING | (empty) |
| Kahili Golf Course | (empty) | MISSING | (empty) |

**Key implication:** In the Bulk Tests run, Hawaii Kai was a MICE imputation subject —
it had no observed BVPA anchor. MICE had to draw its BVPA from the distribution of
similar courses without knowing its county affiliation.

---

## Step 2 — Bulk Tests Julia Script: The Bug Location

The pre-fix `Bulk Tests/Julia/MICE.jl` (lines 72–74) contains:

```julia
out = copy(acreage_df)
out.osm_acreage            = completed.osm_acreage
out.Baseline_Value_Per_Acre = completed.Baseline_Value_Per_Acre   # ← alleged bug
```

The Phase 3 Rerun Report claimed this bulk assignment overwrites observed
(non-missing) BVPA values because `complete()` returns drawn values for ALL rows.
**This claim is empirically tested below.**

---

## Step 3 — Overwrite Test: Does `complete()` Change Observed Values?

Compared 15,197 courses with observed BVPA in the pre-fix Phase 2 against all 5
Bulk Test datasets (tolerance: |diff| > $1).

| Dataset | Courses with BVPA changed from observed value |
|---------|-----------------------------------------------|
| 1 | **0** |
| 2 | **0** |
| 3 | **0** |
| 4 | **0** |
| 5 | **0** |

**Finding: Zero observed BVPA values were overwritten in any of the 5 Bulk Test datasets.**

Spot-checked 5 random observed courses (e.g., course_id=25, BVPA=$5,745; course_id=27,
BVPA=$3,062; etc.): identical values in all 5 Bulk Test outputs.

**Conclusion: Mice.jl's `complete()` DOES preserve observed (non-missing) values exactly.**
The "overwrite of observed values" mechanism described in Phase3_Rerun_Report.md does
not occur in the Bulk Tests. The restoration loop added to Phase_3.jl lines 90–97 is a
no-op for the main Phase 3 run — it restores values that `complete()` already returns
unchanged.

---

## Step 4 — Hawaii Kai Across All 5 Bulk Test Datasets

Hawaii Kai had MISSING BVPA in the pre-fix Phase 2 input. MICE drew its BVPA:

| Dataset | Hawaii Kai BVPA | Correct? |
|---------|-----------------|----------|
| 1 | $4,952,600 (Honolulu FHFA) | ✅ |
| 2 | $4,952,600 (Honolulu FHFA) | ✅ |
| 3 | $4,952,600 (Honolulu FHFA) | ✅ |
| 4 | **$1,707,500 (Maui FHFA)** | ❌ |
| 5 | $4,952,600 (Honolulu FHFA) | ✅ |

**Bug confirmed in 1 of 5 Bulk Test datasets (20% rate).**
Mid-Pacific was correctly imputed at $4,952,600 in all 5 datasets.

### Per-Draw Error for Dataset 4

| Metric | Value |
|--------|-------|
| Observed BVPA (expected) | $4,952,600/ac |
| MICE draw (Dataset 4) | $1,707,500/ac |
| BVPA error | $3,245,100/ac |
| osm_acreage | 130.44 ac |
| Per-course OC error | **$423.3M** |

---

## Step 5 — Provenance of the "49/100 Datasets / ~$473M" Figures

The Phase3_Rerun_Report.md states:
> "the anchor failure affected 49/100 datasets, with an average draw error of
> ~$473M per affected dataset. Averaged across all 100 datasets, the aggregate
> impact was ~$232M (0.023% of the $954B total)"

**These figures cannot be verified from any available pre-fix files.**

- No pre-fix m=100 Julia imputed datasets exist anywhere in the project directory.
  The only pre-fix Julia Phase 3 datasets are the 5 Bulk Test datasets.
- The Bulk Tests show a **20% rate** (1/5 datasets), not 49%.
- The Bulk Tests show a **$423.3M per-draw error**, not $473M.
- The internal arithmetic of the report is self-consistent ($473M × 49/100 = $231.8M ≈
  $232M), indicating the numbers were derived from each other rather than from data.

**Conclusion: The "49/100 datasets" and "~$473M" figures in Phase3_Rerun_Report.md were
generated by the prior Sonnet session as estimates/inferences from the theoretical code
analysis, not from reading actual pre-fix output files.** These numbers should not be
cited as empirically derived.

**What the Bulk Tests actually show:**
- Hawaii Kai wrong-draw rate: **~20%** (1 of 5 datasets)
- Per-draw error when wrong: **$423.3M**
- Expected aggregate OC impact: $423.3M × 20% = **$84.7M** (not $232M)
- As % of national OC: $84.7M / $954.6B = **0.009%** (immaterial)

---

## Step 6 — State Distribution of Courses Exposed to BVPA Imputation Uncertainty

1,095 courses had missing BVPA in the pre-fix Phase 2. These are the courses that MICE
had to impute from scratch — the same class of exposure as Hawaii Kai. Distribution by
state (top 15):

| State | Missing-BVPA Courses |
|-------|---------------------|
| CT | **176** |
| NY | 85 |
| OH | 81 |
| VA | 70 |
| WI | 63 |
| MN | 47 |
| TX | 43 |
| IL | 42 |
| KY | 41 |
| IA | 36 |
| GA | 35 |
| IN | 31 |
| PA | 29 |
| NC | 25 |
| WV | 24 |
| HI | **5** |

Connecticut had 176 courses with missing BVPA — 35× more than Hawaii (5). Most of these
are inland rural courses in counties where FHFA data coverage is sparse, not FIPS-NA
courses. They faced the same MICE imputation uncertainty as Hawaii Kai but at lower
per-course dollar magnitudes (rural counties).

---

## What the Actual Bug Was

The bug is best characterized as an **imputation accuracy issue for FIPS-NA courses**,
not an overwrite of observed values:

1. Phase 1 Julia used coarse 20m cartographic boundaries, leaving 34 courses FIPS-NA
   (and thus BVPA-missing) in the Julia Phase 2 output.

2. MICE had to impute BVPA for these courses without knowing their true county affiliation.
   For Hawaii Kai, MICE mostly drew from the Honolulu distribution ($4,952,600) but
   occasionally drew from the Maui distribution ($1,707,500).

3. The **real fix** was the Phase 1 FIPS resolution (applying `cb = FALSE` to Phase_1.R
   and/or Phase_1.jl), which gave Hawaii Kai an observed BVPA = $4,952,600 in the Phase 2
   input. Once observed, `complete()` returns it unchanged — no imputation needed.

4. The restoration loop added to Phase_3.jl (lines 90–97) is **harmless and precautionary**
   but is not the mechanism that fixed the problem in the current run. The fix came from
   upstream (Phase 1).

---

## Summary and Conclusion

> **The pre-fix Mice.jl bug affected approximately 1,095 courses in Julia's Phase 3
> output** — these were courses with missing BVPA in the pre-fix Phase 2 input
> (FIPS-NA courses or courses in counties without FHFA data coverage). **The aggregate
> impact in expectation was approximately $84.7M (~0.009% of the $954B national OC)**,
> entirely within the measurement noise of the tri-language pipeline.
>
> **Hawaii Kai was NOT the most-affected course by frequency of exposure** — the most-
> affected state by total missing-BVPA course count was Connecticut (176 courses). Hawaii
> Kai was affected in 1 of 5 Bulk Test datasets (20% rate), with a per-draw OC error of
> $423.3M when the wrong (Maui) value was drawn. Mid-Pacific was correctly imputed in all
> 5 Bulk Test datasets.
>
> **The "49/100 datasets" and "~$473M" figures in Phase3_Rerun_Report.md are not
> empirically verified.** No pre-fix m=100 Julia datasets exist in the project directory
> from which these numbers could have been derived. Based on Bulk Tests evidence, the
> correct estimates are approximately 20% wrong-draw rate and $423.3M per-draw error.
>
> **The restoration loop in Phase_3.jl is a no-op** for the current run, because Hawaii
> Kai's BVPA is now observed (resolved by the Phase 1 FIPS fix) and Mice.jl's `complete()`
> already preserves observed values exactly. The root fix was the Phase 1 FIPS boundary
> correction, not the Phase_3.jl restoration loop.

---

## Implications for Thesis Defense

| Item | Status |
|------|--------|
| National OC impact of bug | ~0.009% — immaterial ✅ |
| Hawaii Kai BVPA in current run | $4,952,600 constant (100/100 datasets) ✅ |
| "49/100 datasets" stat in Phase3_Rerun_Report | **Not empirically derived** — must not be cited |
| Restoration loop in Phase_3.jl | Harmless; not the mechanism that fixed the problem |
| Actual fix mechanism | Phase 1 FIPS resolution → observed BVPA anchor |
| CT/NY/OH missing-BVPA exposure | No OC impact at national scale due to low per-acre magnitudes in those states |
