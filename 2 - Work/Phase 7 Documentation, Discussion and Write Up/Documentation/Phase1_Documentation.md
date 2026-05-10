---
title: "Phase 1 Summary: Spatial Parsing & Economic Baseline Valuation"
author: "Michael"
format: 
  pdf:
    toc: true
    number-sections: true
    colorlinks: true
---

**Working directory:** `2 - Work/Phase 1 Parsing/`

---

## Overview

Phase 1 establishes the baseline golf course dataset. The pipeline parses raw GPS
coordinates, spatially assigns them to US Counties via point-in-polygon joins, and
then merges economic proxy data (USDA Agricultural Land values and FHFA Residential
Land values) using 2023 Rural-Urban Continuum Codes (RUCC) to produce a per-course
`Baseline_Value_Per_Acre`.

To ensure robustness and cross-language replicability, the pipeline has been
independently implemented in **three languages** — Python, R, and Julia — each
producing its own prefixed output set.

---

## Script Inventory

| Script | Language | Outputs |
|--------|----------|---------|
| `Phase_1.py` | Python | `Py_*` CSVs |
| `Phase_1.R` | R | `R_*` CSVs |
| `Phase_1.jl` | Julia | `Jl_*` CSVs |

The Julia master script (`Phase_1.jl`) is an **orchestrator** — it `include()`s
three modular sub-scripts from `Bulk Tests/Julia/`:

| Sub-script | Function |
|------------|----------|
| `01_Parser.jl` | Parse raw CSV, extract `Course_Type` and `Holes` via regex, deduplicate |
| `02_SpatialJoin.jl` | Spatial point-in-polygon join to assign 5-digit FIPS county code |
| `03_Valuation.jl` | Merge USDA/FHFA proxies, apply RUCC classification, compute baseline |

Python and R each implement all three steps inline within their master scripts, with
`Bulk Tests/python/` and `Bulk Tests/R/` containing the corresponding modular
component scripts.

---

## Pipeline Workflow

### Step 1 — Spatial Parsing & County Assignment

Loads `Golf Courses-USA.csv` from the read-only data backup. Extracts `Course_Type`
and `Holes` via regex. Downloads official **2022 US Census County boundaries** via
language-appropriate APIs (`pygris` for Python, `tigris` for R, `Shapefile.jl` for
Julia) and performs a spatial point-in-polygon join to assign a `FIPS` code to
every GPS coordinate.

- **Key fix applied:** A FIPS **zero-padding bug** was identified and resolved across
  all three language implementations. County FIPS codes stored as integers lost their
  leading zeros (e.g., `1001` instead of `"01001"`), causing join mismatches with
  the USDA and FHFA datasets. The fix enforces 5-digit zero-padded string formatting
  before any join operation.

- **Cross-language standardization:** The pipeline standardizes the spatial output
  by mapping 2-letter state abbreviations to a consistent `Tigris_State_Abbr` column
  across all languages, avoiding full-name / abbreviation inconsistencies.

### Step 2 — Economic Proxy Merge

Cleans and standardizes two economic datasets, then joins both to the golf courses
on 5-digit `FIPS`:

| Dataset | Variable | Source |
|---------|----------|--------|
| 2022 USDA County Agricultural Land Values | `USDA_Ag_Value_Per_Acre` | USDA NASS Census of Agriculture |
| 2024 FHFA Residential Land Prices | `FHFA_Res_Value_Per_Acre` | FHFA Expanded-Data HPI |

### Step 3 — RUCC Classification & Baseline Valuation

Fetches **2023 USDA Rural-Urban Continuum Codes (RUCC)** and classifies each course:

| RUCC Code | Classification | Proxy Used |
|-----------|---------------|------------|
| 1 – 3 | **Urban** | `FHFA_Res_Value_Per_Acre` (residential market) |
| 4 – 9 | **Rural** | `USDA_Ag_Value_Per_Acre` (agricultural market) |

Courses that cannot be matched (missing county, data suppression, points outside
CONUS boundaries) result in a missing `Baseline_Value_Per_Acre` — these are the
target cases for MICE imputation in Phase 3.

---

## Output Comparison & Discrepancy Analysis

All three pipelines were run on the same source data and compared for consistency.
The FIPS zero-padding fix resolved the primary source of inter-language divergence.

| Metric | Python (`Py_`) | R (`R_`) | Julia (`Jl_`) | Notes |
|--------|---------------|---------|--------------|-------|
| **Total Rows** | 16,297 | 16,292 | 16,292 | Python retains 5 extra rows — different spatial join deduplication defaults in `geopandas` vs `sf`/`Shapefile.jl` |
| **Missing FIPS** | 34 | 34 | 34 | Consistent — points outside CONUS / over water |
| **USDA Hit Rate** | 16,036 | 15,997 | 15,997 | R & Julia match perfectly; Python captures a few dozen more due to row count |
| **FHFA Hit Rate** | 11,722 | 11,719 | 11,717 | All three match closely |
| **Urban / Rural** | 11,391 / 4,872 | 11,386 / 4,872 | 11,386 / 4,872 | R & Julia identical; Python +5 Urban from extra rows |
| **Missing Baseline Value** | **1,095** | **1,094** | **1,095** | **MICE Imputation target in Phase 3** — exceptionally consistent |

### Baseline Valuation Statistics (non-missing courses)

| Statistic | Python | R | Julia |
|-----------|--------|---|-------|
| **Min** | $325.00 | $325.00 | $325.00 |
| **Median** | $135,100.00 | $133,700.00 | $134,100.00 |
| **Mean** | $413,699.57 | $413,695.90 | $413,700.97 |
| **Max** | $24,324,800.00 | $24,324,800.00 | $24,324,800.00 |

The means converge to within $5 of each other across all three languages, confirming
that the pipelines are statistically equivalent despite minor row-count differences
at the margins.

---

## Key Changes Made (Ground-Up Revisions)

1. **FIPS zero-padding bug fixed** in all three language implementations. Prior to
   the fix, FIPS integer coercion caused silent join mismatches that suppressed
   hundreds of USDA/FHFA assignments.

2. **Julia pipeline refactored into orchestrator + modules.** `Phase_1.jl` now
   calls the three modular `01_Parser.jl`, `02_SpatialJoin.jl`, `03_Valuation.jl`
   sub-scripts via `include()`, resolving world-age errors that occurred when
   defining and calling functions in the same top-level script scope in earlier
   versions.

3. **Statistical parity verified** across all three languages post-fix. Pre-fix,
   R and Julia diverged significantly from Python on USDA hit rates (~200+ row gap);
   post-fix, R and Julia align with each other to within 1–2 rows and Python
   diverges by only ~39 rows attributable to the `geopandas` spatial deduplication
   behavior.

---

## File Inventory

| File | Type | Description |
|------|------|-------------|
| `Phase_1.py` | Python Master | End-to-end pipeline in Python |
| `Phase_1.R` | R Master | End-to-end pipeline in R |
| `Phase_1.jl` | Julia Master | Orchestrator — calls `Bulk Tests/Julia/` sub-scripts |
| `Bulk Tests/Julia/01_Parser.jl` | Julia Module | Parsing & deduplication |
| `Bulk Tests/Julia/02_SpatialJoin.jl` | Julia Module | Point-in-polygon spatial join |
| `Bulk Tests/Julia/03_Valuation.jl` | Julia Module | Economic proxy merge & RUCC classification |
| `Bulk Tests/R/` | R Modules | Equivalent R modular sub-scripts |
| `Bulk Tests/python/` | Python Modules | Equivalent Python modular sub-scripts |
| `Py_Phase1_Baseline_Golf_Valuation.csv` | Output | Final Python baseline dataset |
| `R_Phase1_Baseline_Golf_Valuation.csv` | Output | Final R baseline dataset |
| `Jl_Phase1_Baseline_Golf_Valuation.csv` | Output | Final Julia baseline dataset |
| `{Py|R|Jl}_Phase1_Parsed_Golf_Courses.csv` | Intermediate | Post-parsing, pre-spatial-join |
| `{Py|R|Jl}_Phase1_Spatial_Joined_Golf_Courses.csv` | Intermediate | Post-spatial-join, pre-valuation |

---

## Next Steps

- **Phase 2:** Extract golf course polygon boundaries from the OpenStreetMap PBF file
  to calculate true physical acreage (`osm_acreage`).
- **Phase 3:** Run MICE imputation on the ~1,094–1,095 courses missing a baseline
  value, using spatial and structural covariates from Phases 1 and 2.

---

## Code Standardization Pass (2026-04-30)

Scope: formatting and naming consistency only. No logic, formulas, spatial parameters, or filter thresholds were changed.

### Conventions applied across all 14 scripts

**Structure** — mandatory four sections with two blank lines between them:
`# === 1. LIBRARIES ===` / `# === 2. GLOBALS & PATHS ===` / `# === 3. FUNCTIONS ===` / `# === 4. EXECUTION ===`

**Naming**
- Path constants → `ALL_CAPS` (`SCRIPT_DIR`, `ROOT_DIR`, `DATA_DIR`, `RAW_CSV`, `USDA_IN`, etc.)
- Tabular frames → `_df` suffix (`courses_df`, `usda_df`, `fhfa_df`, `rucc_df`)
- R spatial objects → `_sf` suffix (`courses_sf`, `county_sf`)
- Python/Julia spatial objects → `_geo` suffix (`courses_geo`, `county_geo`)
- Overwrite pattern preferred over throwaway intermediates (`parsed_data`/`cleaned_data`/`golf_spatial`/`golf_val`/`final_df` → all collapsed to `courses_df`)

**Language-specific**
- R: `library(wooldridge)` + `library(tidyverse)` in every script; `readxl` kept explicitly; native pipe `|>` replacing `%>%`; `options(tigris_use_cache = TRUE)` in Section 2
- Python: `pathlib.Path(__file__).parent`-based paths; `_find_root()` removed everywhere
- Julia: `@__DIR__` for `SCRIPT_DIR`; `main()` entry point with `if abspath(PROGRAM_FILE) == @__FILE__` guard

**Methodology tags** — `# [METHODOLOGY]` on spatial join operations in all three languages.

**File existence checks** — all local inputs checked before read; remote URLs receive no check.

### Removals

| Script | Removed |
|--------|---------|
| R bulk (all) | Redundant `library(dplyr/tidyr/stringr/readr)` sub-loads |
| R (all) | `%>%` pipe → `|>` |
| Python (all) | `_find_root()`, `import os`, `_HERE`/`ROOT`/`_data`/`_py` intermediates |
| Julia `01_Parser.jl` | `using Printf` (unused); dead `extract_course_type()` + `rest()` helper (produced `:Course_Type` which was immediately dropped in `select()`) |
| Julia `02_SpatialJoin.jl` | `using ThreadsX` (never called; `Threads.@threads` is Base Julia) |
| Julia `03_Valuation.jl` | `using Downloads` (RUCC read from local CSV, not downloaded) |
| Julia bulk (all) | `run_parsing()` / `run_spatial_join()` / `run_valuation()` wrapper functions → replaced with `main()` |

### Architectural change: Julia master

The original `Phase_1.jl` orchestrated via `include()` + `run_parsing()`/`run_spatial_join()`/`run_valuation()`. Those wrapper functions were removed during bulk script standardization, breaking the master.

**Resolution:** `Phase_1.jl` rewritten as self-contained — all helper functions inlined, full pipeline in `main()` with per-step timing. Outputs write to `Data/Julia/` (not `Bulk Tests/Julia/`). Now matches the pattern of `Phase_1.R` and `Phase_1.py`.

### RUCC data source split (unchanged, documented)

- R master / Python master: fetches live from USDA ERS URL
- Julia bulk + Julia master: reads from `00 - Data Sources/Secondary/2023-rural-urban-continuum-codes.csv` (local mirror; original USDA URL was dead, mirrored from WeitzGroup/SciMap-Methods on GitHub)

---

## CLAUDE.md Compliance Review (2026-05-08)

Scope: structural and methodological compliance review of all three master scripts against
CLAUDE.md standards. One fix applied per script; observations noted for awareness.

### Fixes Applied

| Script | Fix | Location |
|--------|-----|----------|
| `Phase_1.R` | Added `# [METHODOLOGY] CRS: EPSG 4326 (WGS 84)...` above `st_transform(4326)` | Line 104 |
| `Phase_1.jl` | Added `# [METHODOLOGY] Spatial read — county boundaries in EPSG 4326...` above `GeoDataFrames.read(COUNTY_SHP)` | Line 193 |
| `Phase_1.py` | Added `# [METHODOLOGY] CRS: EPSG 4326 (WGS 84)...` above `.to_crs("EPSG:4326")` | Line 81 |

All three scripts now have `# [METHODOLOGY]` tags on every CRS transform and spatial file read,
consistent across languages.

### Observations (No Fix Required)

| Script | Observation |
|--------|-------------|
| `Phase_1.R` | `future`, `furrr`, `parallelly` loaded and `plan(multisession)` configured, but no `furrr`/`future_map` calls exist in Section 4. Unused parallel setup. |
| `Phase_1.jl` | `ENV["JULIA_NUM_THREADS"] = "24"` at line 19 is a runtime no-op; thread count must be set at launch (`julia -t 24`). |
| `Phase_1.jl` | `Downloads.download(COUNTY_CB, COUNTY_ZIP)` passes a local file path where a URL is expected — dead code path since `COUNTY_SHP` already exists. |
| `Phase_1.py` | `extract_holes()` returns `18` as default when regex fails (line 53); R returns `NA` for the same case. Minor cross-language inconsistency on unparseable rows. |
| `Phase_1.py` | `as_is_col` hardcoded as `"Land Value\n(Per Acre, As-Is)"` inside `main()` (line 125); R uses `grep()` for dynamic column detection. |

---

## Cross-Language Consistency Review (2026-05-08)

Scope: Part 1D of the master review checklist. Compared all three baseline output CSVs
for schema consistency, formula equivalence, CRS parity, and course count alignment.

### What is Consistent

| Check | Status |
|-------|--------|
| Raw input files | All three scripts read the same three source files and RUCC URL |
| Core economic fields | `FIPS`, `County_Name`, `Tigris_State_Abbr`, `USDA_Ag_Value_Per_Acre`, `FHFA_Res_Value_Per_Acre`, `RUCC_2023`, `county_type`, `Baseline_Value_Per_Acre` — identical column names in all three outputs |
| Baseline valuation formula | Urban → `FHFA_Res_Value_Per_Acre`; Rural → `USDA_Ag_Value_Per_Acre` — identical across all three |
| CRS | EPSG 4326 (WGS 84) in all three scripts |
| Course counts | R=16,292; Julia=16,292; Python=16,297 (the +5 Python rows are the documented `geopandas` deduplication difference) |

### Schema Discrepancies

| Column | R | Julia | Python |
|--------|---|-------|--------|
| `course_id` | ✓ | ✓ | ✗ missing |
| `Address` | ✓ | ✓ | ✗ missing |
| `City` | ✓ | ✓ | ✗ missing |
| `State_Abbr` | ✓ | ✓ | ✗ missing |
| `Zip_Code` | ✓ | ✓ | ✗ missing |
| `Details` | ✗ dropped | ✗ dropped | ✓ retained (raw unparsed column) |
| `Course_Name` content | Stripped (e.g., `"Seamountain Golf Course"`) | Raw with suffix (e.g., `"Seamountain Golf Course-HI"`) | Raw with suffix (same as Julia) |

**Highest-risk gap:** `course_id` is absent from Python's output. If Phase 2 or Phase 3
Python scripts attempt to join or merge on `course_id`, they will fail with a KeyError.
This must be verified in the Phase 2 Python review (Part 2C).

**`Course_Name` divergence:** R applies `str_remove(Name_State, "-.*$")` to strip the
city/state suffix; Julia and Python carry the raw string. Any cross-language match on
`Course_Name` would produce mismatches between R and Julia/Python. Downstream joins
that use `FIPS` or `course_id` are unaffected.
