---
title: "Phase 2 Summary: OSM Polygon Extraction & Acreage Matching"
author: "Michael"
date: "April 27, 2026"
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
