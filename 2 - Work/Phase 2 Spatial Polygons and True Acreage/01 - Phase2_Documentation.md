---
title: "Phase 2 Summary: OSM Polygon Extraction & Acreage Matching"
author: "Michael"
format:
  pdf:
    toc: true
    number-sections: true
    colorlinks: true
---

**Date updated:**
**Working directory:** `2 - Work/Phase 2 Spatial Polygons & True Acreage/`
**Source data policy:** The 11 GB PBF file is read from `00 - Data Sources/Original Data - Backup/`

---

## Step 1 — OSM Golf Course Polygon Extraction

**Scripts:** `Phase_2.py`, `Phase_2.R`, `Phase_2.jl`
**Outputs:** `Py_Phase2_OSM_Golf_Polygons.gpkg`, `R_Phase2_OSM_Golf_Polygons.gpkg`, `Jl_Phase2_OSM_Golf_Polygons.gpkg`

### What it does

1. Extracts OSM areas tagged `leisure=golf_course`. (The Python script handles the direct pyosmium streaming of the 11 GB PBF to bypass GDAL corruption, while R and Julia read this verified extraction to maintain stability).
2. Converts WKB geometries into multipolygons wrapped in a GeoDataFrame (initial CRS: EPSG:4326).
3. **Reprojects** to EPSG:5070 (NAD83 / Conus Albers) so that acreage is calculated on a planar projection rather than meaningless square degrees.
4. Calculates true acreage using `area_m2 / 4046.8564224`.
5. Filters out mapping errors: drops polygons below 5 acres (fragments, individual holes) or above 1,500 acres (mega-resort blobs).
6. Saves the cleaned polygons as a GeoPackage (`.gpkg`), which natively handles the complex multipolygon geometries that CSVs cannot store.

### Key results

| Metric                         | Value                                                    |
| ------------------------------ | -------------------------------------------------------- |
| Processing time                | ~22.0 minutes (Python PBF Parse) / ~11 seconds (Julia/R) |
| Raw polygons captured          | 16,447                                                   |
| Geometry build errors          | 6                                                        |
| Dropped (< 5 or > 1,500 acres) | 1,281                                                    |
| **Final polygon count**  | **15,166**                                         |

### Acreage summary (filtered polygons)

| Statistic | Value         |
| --------- | ------------- |
| Min       | 5.0 acres     |
| Median    | 127.8 acres   |
| Mean      | 134.1 acres   |
| Max       | 1,326.9 acres |

---

## Step 2 — Matching OSM Polygons to Phase 1 Courses

**Scripts:** `Phase_2.py`, `Phase_2.R`, `Phase_2.jl`
**Outputs:** `Py_Phase2_Acreage_Matched.csv`, `R_Phase2_Acreage_Matched.csv`, `Jl_Phase2_Acreage_Matched.csv`

### What it does

1. Loads the Phase 1 baseline dataset (`Phase1_Baseline_Golf_Valuation.csv`) and projects the point coordinates to EPSG:5070 to align with the polygons.
2. **Primary join** — `intersects`: finds courses whose point coordinate falls directly inside an OSM polygon.
3. **Fallback join** — `nearest` with `max_distance=500` meters: for any course that missed the primary join (e.g., the listed coordinate is a clubhouse or parking lot outside the mapped fairway), it grabs the nearest polygon's acreage if one exists within 500 m.
4. De-duplicates overlapping polygon matches.
5. Drops the heavy polygon geometries and saves a flat CSV with `osm_acreage` appended to all Phase 1 columns.

### Key results (Cross-Language Parity)

| Metric                                     | Value                    |
| ------------------------------------------ | ------------------------ |
| Phase 1 input rows                         | 16,292                   |
| Direct intersect hits                      | 5,458                    |
| Misses (need fallback)                     | 10,834                   |
| Nearest-neighbor recoveries (within 500 m) | 6,147                    |
| **Total matched with osm_acreage**   | **11,605 (71.2%)** |
| **Missing osm_acreage**              | **4,687 (28.8%)**  |

### Matched acreage summary

| Statistic | Value         |
| --------- | ------------- |
| Min       | 5.1 acres     |
| Median    | 137.9 acres   |
| Mean      | 147.6 acres   |
| Max       | 1,326.9 acres |

---

## Tigris Landmarks Fallback Matching Attempt

**Script:** `Bulk Tests/R/02_Match_Tigris.R`

### Overview

A fallback attempt was made to use the US Census Bureau's Tigris package (landmarks dataset) as an alternative source for golf course polygon acreage, in case OpenStreetMap coverage was incomplete. This approach aimed to identify "golf" or "country club" features and match them to courses missing OSM data.

### Key Finding: API Change

The tigris R package underwent a significant API change between versions:
- **Old behavior:** `landmarks()` could download all US landmarks without parameters
- **New behavior (tigris 2.x):** The `landmarks(state = "XX")` function now requires a state parameter, requiring iterative downloads for each state

This architectural change significantly complicates the fallback matching approach and was not implemented in Phase 2.

### Future Considerations

If Tigris landmarks are desired as a data source:
1. Modify `02_Match_Tigris.R` to loop through all states (or download national dataset via alternative means)
2. Filter for golf-related features using FULLNAME or FEATURE columns
3. Perform nearest-neighbor matching similar to Step 2

---

## Phase 2 Refinement: Final Acreage Preparation for Imputation

**Script:** `Bulk Tests/R/03_Finalize_Acreage.R`
**Output:** `R_Phase2_Acreage_Matched_v2.csv`

### What it does

1. Loads the Step 1 OSM output file (`R_Acreage_Step1_OSM.csv`)
2. Assigns `"MICE_Target"` to remaining missing values in `acreage_source` column
3. Renames `OSM_Area_SqFt` to `final_acreage`
4. Saves the final pre-imputation dataset

### Key results (Final Phase 2 Summary)

| Acreage Source | Count    | Percentage |
| -------------- | -------- | ---------- |
| MICE_Target    | 10,834   | 66.5%      |
| OSM            | 5,458    | 33.5%      |
| **Total**      | **16,292** | **100%**   |

### Final data profile heading into Phase 3

| Variable                    | Missing count | % of 16,292 |
| --------------------------- | ------------- | ----------- |
| `Baseline_Value_Per_Acre` | 1,095         | 6.7%        |
| `final_acreage`           | 10,834        | 66.5%       |

The acreage gap is now clearly marked with `"MICE_Target"` in the `acreage_source` column to indicate which rows should be imputed during Phase 3 MICE (Multiple Imputation by Chained Equations).

---



## File inventory

| File                                | Type          | Description                                                                      |
| ----------------------------------- | ------------- | -------------------------------------------------------------------------------- |
| `Phase_2.py`                      | Python Script | Combined master script for Python pipeline                                       |
| `Phase_2.R`                       | R Script      | Combined master script for R pipeline (incorporates multi-processing)            |
| `Phase_2.jl`                      | Julia Script  | Combined master script for Julia pipeline (incorporates multi-threading)         |
| `Bulk Tests/`                     | Directory     | Modular source scripts (`01_ParseOSM`, `02_MatchOSM`, etc) for all languages |
| `*_Phase2_OSM_Golf_Polygons.gpkg` | Output        | 15,166 cleaned golf polygons (GeoPackages)                                       |
| `*_Phase2_Acreage_Matched.csv`    | Output        | 16,292 courses with `osm_acreage` appended (CSV files)                         |

---

## CLAUDE.md Compliance Review (2026-05-08)

Scope: structural and methodological compliance review of `Phase_2.R` and `Phase_2.jl`
against CLAUDE.md standards.

### `Phase_2.R` — Result

No violations found. No fixes applied.

### `Phase_2.R` — Observations (No Fix Required)

| Script | Observation |
|--------|-------------|
| `Phase_2.R` | `PBF_FILE` in the script points to `00 - Data Sources/Original Data/us-260413.osm.pbf` but the Phase 2 summary header documents the PBF as residing in `Original Data - Backup/`. The script handles the mismatch via try/catch fallback to the Python GPKG, but the documentation path is misaligned. |
| `Phase_2.R` | `MAX_NEAREST_M <- 500` defines the nearest-neighbour cutoff but has no inline comment explaining the methodological basis for 500 m. Named constant is self-documenting; not a CLAUDE.md violation. |
| `Phase_2.R` | `rm(courses_sf, intersects_result, intersects_df, osm_golf_sf)` at line 337 (post Tier 1 cleanup) has no following `gc()` call. CLAUDE.md memory rule targets dataset-loading loops; this is post-join cleanup outside a loop, so not a strict violation, but several GB of spatial objects are freed without a GC hint. |

### `Phase_2.jl` — Result

One violation found. Fix applied.

### `Phase_2.jl` — Fix Applied

| Script | Fix | Location |
|--------|-----|----------|
| `Phase_2.jl` | Added `courses_df.acreage_source = ifelse.(ismissing.(courses_df.osm_acreage), "MICE_Target", "OSM")` immediately after `courses_df.osm_acreage = acreage_results` | After line 214 (original) |

### `Phase_2.jl` — Observation (No Fix Required)

| Script | Observation |
|--------|-------------|
| `Phase_2.jl` | No Tigris second tier: Phase_2.R runs a three-tier pipeline (OSM → Tigris landmarks → MICE_Target); Phase_2.jl is single-tier (OSM intersect + 500 m nearest → MICE_Target). Tigris cannot be replicated in Julia (`tigris` is an R-only package). The Julia MICE-target count will therefore be higher than R's. This is expected and not a violation. |

### `Phase_2.py` — Result

One violation found. Fix applied.

### `Phase_2.py` — Fix Applied

| Script | Fix | Location |
|--------|-----|----------|
| `Phase_2.py` | Added `courses_geo["acreage_source"] = courses_geo["osm_acreage"].apply(lambda x: "MICE_Target" if pd.isna(x) else "OSM")` after the de-duplication step | After line 188 (original) |

### `Phase_2.py` — Observation (No Fix Required)

| Script | Observation |
|--------|-------------|
| `Phase_2.py` | No Tigris second tier (same as Julia — R-only package). Two-value schema ("OSM" \| "MICE_Target") is expected. |
| `Phase_2.py` | Part 1D flag resolved: `Phase_2.py` performs only spatial joins (`sjoin`, `sjoin_nearest`) and never joins on `course_id`. The missing `course_id` in `Py_Phase1_Baseline_Golf_Valuation.csv` causes no failure in Phase 2. |

---

## Phase 2 Cross-Language Consistency Review (2026-05-08)

Scope: Part 2D of the master review checklist. Compared all three Phase 2 master scripts
for `acreage_source` schema consistency, match distance thresholds, MICE-target count
alignment, output CSV column schemas, and GPKG CRS.

### What is Consistent

| Check | Status |
|-------|--------|
| Polygon match distance threshold | `MAX_NEAREST_M = 500` m in all three languages ✓ |
| Output GPKG CRS | EPSG:5070 (NAD83 Conus Albers) in all three ✓ |
| `acreage_source` column present | All three output CSVs now carry `acreage_source` after 2B/2C fixes ✓ |
| Acreage units in output CSVs | All three report acreage in acres ✓ |

### Schema Discrepancies

| Column | R | Julia | Python |
|--------|---|-------|--------|
| Primary acreage column name | `final_acreage` (coalesced OSM+Tigris) | `osm_acreage` | `osm_acreage` |
| `tigris_acreage` | ✓ retained in CSV | ✗ absent | ✗ absent |
| `acreage_source` values | "OSM" \| "Tigris" \| "MICE_Target" | "OSM" \| "MICE_Target" | "OSM" \| "MICE_Target" |
| MICE_Target count | Lower (Tigris recovers additional courses) | Higher | Higher |
| `course_id`, `Address`, `City`, `State_Abbr`, `Zip_Code` | ✓ (inherited from Phase 1 R) | ✓ (inherited from Phase 1 Julia) | ✗ missing (Phase 1 gap carries forward) |

### Key Observations

1. **`acreage_source` value set is asymmetric by design**: R produces three categories ("OSM" | "Tigris" | "MICE_Target"); Julia and Python produce two ("OSM" | "MICE_Target"). The `tigris` package is R-only; the two-value schema in Julia and Python is expected and correct. Phase 3 scripts should filter on `acreage_source != "MICE_Target"` rather than on a specific positive value to remain safe across all three languages.

2. **`final_acreage` vs `osm_acreage` — primary acreage column name differs**: R's pipeline coalesces OSM and Tigris acreage into a single `final_acreage` column. Julia and Python write `osm_acreage` as the primary acreage column (OSM-only). CLAUDE.md's language-prefixed file separation rule (each Phase 3 script reads only its own `R_`, `Jl_`, or `Py_` output) means this does not break the pipeline — but Phase 3 scripts must reference the correct column name per language.

3. **MICE-target count asymmetry (explainable)**: R's Tigris Tier 2 recovers a subset of courses that remain unmatched after OSM processing. Julia and Python have no equivalent fallback. Consequently, R's final MICE_Target row count is lower than Julia's and Python's. The direction of this asymmetry is deterministic; the magnitude depends on the Tigris runtime download.

---


## Dependencies

- **Python**: `osmium` (pyosmium), `geopandas`, `pandas`, `shapely`
- **R**: `sf`, `dplyr`, `readr`, `future`, `furrr`
- **Julia**: `ArchGDAL`, `GeoDataFrames`, `DataFrames`, `CSV`, `ThreadsX`

---

## Next steps

- **Phase 3:** MICE imputation to fill the 4,687 missing `osm_acreage` values and 1,095 missing `Baseline_Value_Per_Acre` values using spatial, structural, and economic covariates.

---

## Code Standardization Pass (2026-04-30)

Scope: formatting and naming consistency only. No logic, formulas, spatial parameters, or filter thresholds were changed.

### Scripts standardized (11 total)

| Script | Language |
|--------|----------|
| `Bulk Tests/R/00 - Parse_osm_Golf_Polygons.R` | R |
| `Bulk Tests/R/01_Match_OSM.R` | R |
| `Bulk Tests/R/02_Match_Tigris.R` | R |
| `Bulk Tests/R/03_Finalize_Acreage.R` | R |
| `Bulk Tests/python/parse_osm_golf_polygons.py` | Python |
| `Bulk Tests/python/match_osm_to_courses.py` | Python |
| `Bulk Tests/Julia/01_ParseOSM.jl` | Julia |
| `Bulk Tests/Julia/02_MatchOSM.jl` | Julia |
| `Phase_2.R` | R master |
| `Phase_2.py` | Python master |
| `Phase_2.jl` | Julia master |

Four deprecated R prototypes (`area.R`, `match_osm_to_courses.R`, `mock_execute.R`, `polygons.R`) were confirmed unused and removed from the workflow by the user.

### Conventions applied across all 11 scripts

**Structure** — mandatory four sections with two blank lines between them:
`# === 1. LIBRARIES ===` / `# === 2. GLOBALS & PATHS ===` / `# === 3. FUNCTIONS ===` / `# === 4. EXECUTION ===`

**Naming**
- Path/config constants → `ALL_CAPS` (`SCRIPT_DIR`, `ROOT_DIR`, `PHASE1_CSV`, `OUT_CSV`, `TARGET_CRS`, `MAX_NEAREST_M`, `MIN_ACRES`, `MAX_ACRES`, `SQ_M_PER_ACRE`, `SQ_FT_PER_ACRE`, `SAFE_WORKERS`, `ALL_STATES`)
- R spatial objects → `_sf` suffix: `osm_golf_sf`, `tigris_golf_sf`, `courses_sf`, `miss_sf`
- Python/Julia spatial objects → `_geo` suffix: `osm_golf_geo`, `courses_geo`, `miss_geo`
- Tabular frames → `_df` suffix: `courses_df`, `acreage_df`, `baseline_df`
- Helper functions → `print_separator` (R); `format_number` / `format_decimal` (Julia)

**Methodology tags** — `# [METHODOLOGY]` on spatial reads, joins, CRS transforms, and geometric operations in all three languages.

**Language-specific**
- R: `library(wooldridge)` + `library(tidyverse)` in every script; redundant sub-library loads (`dplyr`, `readr`, `stringr`) removed; native pipe `|>` throughout; `options(tigris_use_cache = TRUE)` in Section 2 for any script using `tigris`
- Python: `pathlib.Path(__file__).parent`-based paths; `import os` and `os.path` removed everywhere; `os.path.normpath()` calls removed; `path.exists()` replaces `os.path.exists()`; `OUT_*.parent.mkdir(parents=True, exist_ok=True)` added before saves
- Julia: `using Statistics` replaces `import Statistics: median, mean`; `using ThreadsX` removed (unused — `Threads.@threads` is Base Julia); module-level `const` constants; wrapper functions (`run_parse_osm()`, `run_match_osm()`) replaced by `main()` entry points

### Architectural change: Julia master

`Phase_2.jl` was originally an orchestrator using `include()` + `run_parse_osm()` / `run_match_osm()`. Since wrapper functions are removed during bulk script standardization, the master was rebuilt as self-contained — all helper functions and both pipeline steps inlined into `main()`, matching the pattern of `Phase_1.jl`.

Additionally, `ENV["JULIA_NUM_THREADS"] = "24"` was removed from the top of the file. This assignment has no effect at runtime — Julia thread count must be set before the interpreter starts via `julia -t N` or the `JULIA_NUM_THREADS` environment variable.

### Note on deprecated bulk scripts (Step 1 in Julia)

`Phase_2.jl` previously had `run_parse_osm()` commented out (Step 1 intentionally skipped at runtime). In the self-contained master, Step 1 is now active and reads from `Data/Python/Py_Phase2_OSM_Golf_Polygons.gpkg` (the pyosmium output). The Julia master requires the Python pipeline to have been run first to produce this input file.
