# Phase 2 Rerun Report

**Date:** 2026-05-15
**Phase:** 2 — Acreage Matching (OSM Polygon Join)
**Source files read:**
- `Phase 2 Spatial Polygons and True Acreage/Phase_2.R`
- `Phase 2 Spatial Polygons and True Acreage/Phase_2.py`
- `Phase 2 Spatial Polygons and True Acreage/Data/R/R_Phase2_Acreage_Matched_v2.csv`
- `Phase 2 Spatial Polygons and True Acreage/Data/python/Py_Phase2_Acreage_Matched.csv`
- `Phase 2 Spatial Polygons and True Acreage/Data/Julia/Jl_Phase2_Acreage_Matched.csv`

---

## Inputs

| Input | Description |
|-------|-------------|
| `00 - Data Sources/Original Data/us-260413.osm.pbf` | 11 GB US national OSM extract (Python Step 1 source) |
| `Phase 2 .../Data/python/Py_Phase2_OSM_Golf_Polygons.gpkg` | Python-generated GeoPackage (R and Julia Step 0 source) |
| `Phase 1 .../Data/R/R_Phase1_Baseline_Golf_Valuation.csv` | Phase 1 R output (16,292 rows) |
| `Phase 1 .../Data/Python/Py_Phase1_Baseline_Golf_Valuation.csv` | Phase 1 Python output (16,297 rows) |
| `Phase 1 .../Data/Julia/Jl_Phase1_Baseline_Golf_Valuation.csv` | Phase 1 Julia output (16,292 rows) |

---

## Outputs Generated

| File | Language | Rows |
|------|----------|------|
| `R_Phase2_Acreage_Matched_v2.csv` | R | 16,292 |
| `Py_Phase2_Acreage_Matched.csv` | Python | 16,297 |
| `Jl_Phase2_Acreage_Matched.csv` | Julia | 16,292 |

Row counts match Phase 1 outputs exactly across all three languages (stable through Phase 2).

---

## OSM Polygon Source Architecture

R and Julia read the Python-generated GeoPackage (`Py_Phase2_OSM_Golf_Polygons.gpkg`) rather
than streaming the raw PBF directly. This design is intentional: GDAL's OGR driver crashes at
~byte 3,049,247,581 of this particular PBF due to data corruption. The Python pipeline uses
pyosmium (C++ streaming handler), which tolerates the corruption, and writes the extracted
polygons to GPKG for downstream use by R and Julia.

**Python Step 1 cache check (added this session):** `Phase_2.py` was updated to check whether
`Py_Phase2_OSM_Golf_Polygons.gpkg` already exists before re-streaming the PBF. If the GPKG is
present, Python loads it directly and proceeds to Step 2. This avoids a 30–90 minute PBF parse
on reruns where the polygon set has not changed (OSM polygons are independent of Phase 1 fixes).

---

## Acreage Source Distribution

| Metric | R | Python | Julia |
|--------|---|--------|-------|
| Total rows | 16,292 | 16,297 | 16,292 |
| OSM matched | 11,605 (71.2%) | 11,610 (71.2%) | 11,605 (71.2%) |
| Tigris recovered | 0 | 0 | 0 |
| MICE_Target | 4,687 (28.8%) | 4,687 (28.8%) | 4,687 (28.8%) |

**MICE_Target consistency:** All three languages produce exactly 4,687 MICE_Target courses.
This is expected — courses without an OSM polygon within 500 m are the same set regardless
of language, since all three pipelines use the same OSM source.

**Python OSM count is 5 higher than R/Julia (11,610 vs 11,605):** This mirrors the Phase 1
row-count difference. Python's dataset contains 5 additional courses (16,297 vs 16,292); all
5 received OSM matches, leaving MICE_Target identical across all three languages.

**Tigris Tier-2 recovery: 0 in all three languages.** Census area landmarks with
`FULLNAME` matching "Golf/Country Club" yielded no recoveries within 500 m of any
MICE_Target course. This is consistent with prior runs — Census area landmarks have
sparse golf course coverage and this tier functions as a structural safety net that
rarely fires.

---

## osm_acreage Summary (OSM-matched rows only)

| Statistic | R | Python | Julia |
|-----------|---|--------|-------|
| Min | ~5.0 ac | 5.05 ac | 5.05 ac |
| Median | ~137.9 ac | 137.90 ac | 137.88 ac |
| Mean | ~147.6 ac | 147.57 ac | 147.62 ac |
| Max | ~1,327 ac | 1,326.85 ac | 1,326.85 ac |

Distributions are nearly identical across all three languages — as expected, since all three
use the same polygon source.

---

## Hawaii Course Acreage Verification

All three key Hawaii courses carry OSM-sourced acreage that matches the pre-rerun baseline
exactly across all three language pipelines:

| Course | Acreage Baseline | R | Python | Julia | FIPS | BVPA | Source |
|--------|-----------------|---|--------|-------|------|------|--------|
| Hawaii Kai Golf Course | 130.44 ac | 130.44 | 130.44 | 130.44 | 15003 | $4,952,600 | OSM ✅ |
| Mid Pacific Country Club | 151.96 ac | 151.96 | 151.96 | 151.96 | 15003 | $4,952,600 | OSM ✅ |
| Moanalua Golf Club | 57.86 ac | 57.86 | 57.86 | 57.86 | 15003 | $4,952,600 | OSM ✅ |

All three courses carry `Baseline_Value_Per_Acre = $4,952,600` (FHFA residential, Honolulu
County, 2022) in all three sub-pools. With FIPS now resolved from Phase 1, no MICE imputation
is needed for BVPA on these courses — they will enter Phase 3 with a constant, non-missing
baseline value.

---

## Anomalies / Unexpected Changes

**Minor — R `tigris_acreage` warning:**
Phase_2.R emits `Warning: Unknown or uninitialised column: 'tigris_acreage'` during the
finalize step. This is a cosmetic dplyr data-mask scoping quirk: the `if ("tigris_acreage"
%in% names(acreage_df))` guard inside a `mutate()` block triggers a warning as dplyr scans
for column references, even though the guard works correctly. The output is unaffected.
`coalesce(osm_acres, tigris_acres)` resolves to `coalesce(osm_acres, NA_real_)` = `osm_acres`
for all rows with OSM acreage; MICE_Target rows carry NA throughout, which is the intended
behavior. Recommend suppressing with `suppressWarnings()` in a future maintenance pass.

No other anomalies observed. All row counts, acreage distributions, and Hawaii course values
are within tolerance of the pre-rerun baseline.

---

## Conclusion

Phase 2 ran cleanly across all three language pipelines. All key metrics are stable:

- **Row counts** match Phase 1 outputs exactly (R/Jl: 16,292; Py: 16,297).
- **MICE_Target:** 4,687 in all three languages — consistent and unchanged from prior runs.
- **Hawaii Kai, Mid-Pacific, Moanalua:** acreages match baselines exactly (130.44, 151.96,
  57.86 ac) and carry BVPA = $4,952,600 with no MICE needed on the baseline value.
- **Tigris Tier-2:** 0 recoveries in all three languages (expected; structural safety net).

**All downstream phases are unblocked.** Phase 3 (MICE imputation) can proceed with the
expectation that Hawaii Kai and Mid-Pacific will have constant `Baseline_Value_Per_Acre =
$4,952,600` in all 300 imputed datasets across all three sub-pools.
