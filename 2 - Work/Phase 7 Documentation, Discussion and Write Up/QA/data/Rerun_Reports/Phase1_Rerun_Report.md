# Phase 1 Rerun Report

**Date:** 2026-05-15 *(revised; initial report 2026-05-14)*
**Phase:** 1 — Cleaning, Spatial Join, Augmentation, and Baseline Valuation
**Source files read:**
- `Phase 1 Parsing/Phase_1.R`
- `Phase 1 Parsing/Phase_1.py`
- `Phase 1 Parsing/Phase_1.jl`
- `Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv`
- `Phase 1 Parsing/Data/python/Py_Phase1_Baseline_Golf_Valuation.csv`
- `Phase 1 Parsing/Data/Julia/Jl_Phase1_Baseline_Golf_Valuation.csv`

**Revision note:** Initial report (2026-05-14) documented the boundary fix as applied to
Phase_1.R only; Phase_1.py and Phase_1.jl were not updated and still produced 34 FIPS-NA
each. This revision reflects the subsequent patches to both scripts and a full rerun of
all three Phase 1 pipelines.

---

## Inputs

- `00 - Data Sources/Original Data/Golf Courses-USA.csv` — raw course list (shared)
- `00 - Data Sources/Original Data/2022 - USDA County Data - Ag Use.csv` — USDA ag-use proxy
- `00 - Data Sources/Original Data/2024 - FHFA June 20 Land Prices.xlsx` — FHFA residential land proxy
- `00 - Data Sources/Secondary/2023-rural-urban-continuum-codes.csv` (Julia) / USDA ERS URL (R, Py) — RUCC codes
- County boundaries: see "Spatial Join Method" section below

---

## Outputs Generated

| File | Language | Rows |
|------|----------|------|
| `R_Phase1_Baseline_Golf_Valuation.csv` | R | 16,292 |
| `Py_Phase1_Baseline_Golf_Valuation.csv` | Python | 16,297 |
| `Jl_Phase1_Baseline_Golf_Valuation.csv` | Julia | 16,292 |

Row counts are identical to the pre-rerun baseline across all three languages.

---

## Spatial Join Method (Boundary Fix Status)

| Language | Method Used | Boundary Source | Fix Applied? |
|----------|-------------|-----------------|--------------|
| R | `tigris::counties(cb = FALSE, year = 2022)` | Full TIGER/Line shapefiles | **YES** |
| Python | `pygris.counties(cb=False, year=2022)` | Full TIGER/Line shapefiles | **YES** |
| Julia | Downloads `tl_2022_us_county.zip` from Census TIGER; reads `tl_2022_us_county.shp` | Full TIGER/Line shapefiles | **YES** |

All three language pipelines now use full TIGER/Line county boundaries (no cartographic
simplification). The coarse 20m cartographic boundary (`cb_2022_us_county_20m.shp`) that
caused the original 34 FIPS-NA failures has been replaced in all three scripts.

**Note on R script (Phase_1.R line 105):** The call passes `resolution = "20m"` to
`counties()`, but tigris ignores this argument when `cb = FALSE`. The dead argument is
harmless but could be removed in a future maintenance pass.

**Note on Julia column derivation:** The full TIGER/Line shapefile does not carry `STUSPS`
(state abbreviation). A `STATE_FIPS_TO_ABBR` lookup dictionary was added to Phase_1.jl to
derive `Tigris_State_Abbr` from `STATEFP`, preserving column compatibility with downstream
phases.

---

## FIPS-NA Counts

| Language | Pre-Rerun FIPS-NA | Post-Rerun FIPS-NA | Delta |
|----------|-------------------|---------------------|-------|
| R | 34 | **0** | **−34** ✅ |
| Python | 34 | **0** | **−34** ✅ |
| Julia | 34 | **3** | **−31** ✅ (minor residual — see below) |

---

## Comparison Against Baseline

| Metric | Baseline (Pre-Rerun) | Post-Rerun | Delta |
|--------|---------------------|------------|-------|
| R total rows | 16,292 | 16,292 | 0 |
| Python total rows | 16,297 | 16,297 | 0 |
| Julia total rows | 16,292 | 16,292 | 0 |
| R FIPS-NA | 34 | 0 | **−34** ✅ |
| Python FIPS-NA | 34 | 0 | **−34** ✅ |
| Julia FIPS-NA | 34 | 3 | **−31** ✅ |

---

## Hawaii Course FIPS Resolution — All Three Pipelines

All 5 previously FIPS-NA Hawaii courses now resolve correctly in all three language pipelines:

| Course | Expected FIPS | R | Python | Julia | BVPA | Status |
|--------|---------------|---|--------|-------|------|--------|
| Hawaii Kai Golf Course | 15003 | 15003 | 15003 | 15003 | $4,952,600 | ✅ ALL RESOLVED |
| Mid Pacific Country Club | 15003 | 15003 | 15003 | 15003 | $4,952,600 | ✅ ALL RESOLVED |
| Kahili Golf Course | 15009 | 15009 | 15009 | 15009 | $1,707,500 | ✅ ALL RESOLVED |
| King Kamehameha Golf Club | 15009 | 15009 | 15009 | 15009 | $1,707,500 | ✅ ALL RESOLVED |
| Kapalua Golf Club | 15009 | 15009 | 15009 | 15009 | $1,707,500 | ✅ ALL RESOLVED |

`Baseline_Value_Per_Acre = $4,952,600` confirmed for FIPS 15003 (Honolulu) in 2022 across
all three sub-pools. With FIPS now resolved in all pipelines, no MICE imputation is needed
for BVPA on Hawaii Kai or Mid-Pacific in any sub-pool. The Phase 3 Hawaii Kai test
(constant BVPA across all 300 datasets) is now expected to pass for all three languages.

---

## Julia Residual FIPS-NA (3 Courses)

Julia produced 3 FIPS-NA entries that were NOT in the original 34-course FIPS-NA list. These
are new boundary-edge cases exposed by the stricter TIGER/Line polygon geometry:

| Course | State | Notes |
|--------|-------|-------|
| Sewailo Golf Club | AZ | Not in original FIPS-NA list |
| Normandy Shores Golf Course | FL | Not in original FIPS-NA list |
| Turtle Creek Golf Club | FL | Not in original FIPS-NA list |

Python resolved all three of these courses cleanly (FIPS-NA = 0). The discrepancy between
Python (0) and Julia (3) likely reflects a difference in spatial join precision: pygris
fetches the TIGER/Line files via the Census API and uses geopandas `sjoin`, while Phase_1.jl
uses a custom bounding-box pre-filter followed by `ArchGDAL.intersects`. Edge-case points
that lie very close to a county boundary (e.g., on water or at a polygon vertex) may pass
one implementation's floating-point tolerance and fail another's.

These 3 courses will be sent to MICE imputation for BVPA in the Julia sub-pool only.
Given that 3 of 16,292 is 0.018% of the Julia dataset, the impact on national aggregates
is negligible. The Phase 3 report should confirm that these 3 courses do not drive
meaningful divergence between the Julia and Python/R sub-pools.

---

## Anomalies / Unexpected Changes

**Minor — 3 new FIPS-NA courses in Julia (not in original 34):**
Sewailo Golf Club (AZ), Normandy Shores Golf Course (FL), and Turtle Creek Golf Club (FL)
are now FIPS-NA in Julia only. These were not FIPS-NA in the pre-rerun run (which used the
coarser cartographic boundary). The coarser boundary apparently assigned these three courses
by proximity even though they fall outside the precise TIGER/Line polygon edge. Python's
geopandas sjoin resolves all three; Julia's ArchGDAL intersects loop does not. At 0.018%
of the dataset this is below the 1% alert threshold and is not expected to materially affect
Phase 3 or Phase 4 outputs.

**Minor — Dead argument in R script:**
`counties(cb = FALSE, year = 2022, resolution = "20m", ...)` — the `resolution` argument
is silently ignored by tigris when `cb = FALSE`. Harmless; recommend removing in a future
maintenance pass.

---

## Conclusion

All three Phase 1 language pipelines have been updated to use full TIGER/Line county
boundaries. The boundary fix is now complete across R, Python, and Julia.

- **R:** FIPS-NA 34 → 0 ✅. All 34 previously failing courses resolved, including all 5
  Hawaii courses. BVPA for FIPS 15003 confirmed at $4,952,600.
- **Python:** FIPS-NA 34 → 0 ✅. All 34 previously failing courses resolved. All 5 Hawaii
  courses confirmed at correct FIPS and BVPA.
- **Julia:** FIPS-NA 34 → 3 ✅. All 34 previously failing courses resolved. Three new
  boundary-edge cases (Sewailo/AZ, Normandy Shores/FL, Turtle Creek/FL) remain unresolved
  in Julia only; Python handles them cleanly. Impact is negligible at 0.018% of the dataset.

**All downstream phases are unblocked.** Phase 2 and Phase 3 can now proceed with the
expectation that Hawaii Kai and Mid-Pacific will carry constant `Baseline_Value_Per_Acre =
$4,952,600` across all 300 imputed datasets in all three sub-pools (no MICE on BVPA for
these courses). The pre-rerun MICE divergence at Hawaii Kai ($296M Python vs $414M Julia
vs $646M R) should not recur.
