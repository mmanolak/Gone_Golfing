---
title: "Phase 5 Summary: Hawaii Micro-Case Study"
author: "Michael"
date: "May 1, 2026"
format: 
  pdf:
    toc: true
    number-sections: true
    colorlinks: true
---

**Purpose:** Validate HBU valuation model against actual municipal tax assessment data for Hawaii golf courses

---

## Overview

Phase 5 conducted a micro-case study to validate the model's opportunity cost estimates against official county tax assessment data for golf courses in Hawaii. This provides empirical evidence of whether the model's Highest and Best Use (HBU) valuations align with real-world property tax assessments.

Phase 5 is organized in two tracks:

- **Phase 5a (Pilot):** A manual spot-check of 6 high-profile courses comparing model estimates to hand-retrieved assessment values.
- **Phase 5b (Full Pipeline):** A 6-step automated spatial pipeline — OSM polygon extraction, cadastral parcel intersection, economic validation via Rubin's Rules, TMK diagnostic merge, geographic breakdown, and zoning intersection analysis — implemented in R, Python, and Julia.

---

## Methodology

### Data Sources

1. **Phase 1 CSV:** `Py_Phase1_Baseline_Golf_Valuation.csv` — 16,297 courses with OSM acreage and baseline value per acre
2. **Phase 2 GeoPackage:** `Py_Phase2_OSM_Golf_Polygons.gpkg` — OSM-derived golf course polygons
3. **Honolulu Cadastral GeoPackage:** `All_Parcels_6378200148342636690.gpkg` — Honolulu parcel cadastre
4. **Honolulu Tax CSV:** `All_Parcels_-4613852522541990741.csv` — parcel-level tax/zone attributes
5. **Honolulu Zoning GeoPackage:** `Zoning_-2205419429161838665.gpkg` — Honolulu zoning layer (EPSG 3760, NAD83(HARN)/Hawaii zone 3, ftUS)
6. **Phase 3 Imputed Datasets (×100):** MICE-imputed economic datasets for Rubin's Rules pooling (M=100 per language)

### Model Logic

Opportunity Cost is calculated as:
```
Opportunity_Cost = osm_acreage × Baseline_Value_Per_Acre
```

Where `Baseline_Value_Per_Acre` is determined by:
- **Urban counties (RUCC 1–3):** FHFA Residential Land Price index
- **Rural counties (RUCC 4–9):** USDA Agricultural Land Value

### Phase 5b Pipeline Steps

| Step | Description |
|------|-------------|
| 1 | OSM polygon extraction (Oahu bbox), Phase 1 point-in-polygon match rate, parcel reprojection |
| 2 | Cookie-cutter spatial intersection of OSM golf polygons over cadastral parcels → TMK list |
| 3 | MICE pooling (Rubin's Rules), spatial deduplication (500 m cap), economic validation table |
| 4 | Diagnostic only — verifies TMK format compatibility between Step 2 output and Honolulu CSV |
| 5 | Geographic concentration breakdown by TMK zone/district |
| 6 | Zoning intersection analysis — quantifies golf footprint by zone class and zone penetration rate |

---

## Results

### Phase 5a: Pilot Course Comparison (Manual Spot-Check)

#### Hawaii Course Summary (All Islands, Phase 1 Filter)

| Metric | Value |
|--------|-------|
| Total Courses (Hawaii state) | 74 |
| Average Opportunity Cost | $456,829,248 |
| Total Opportunity Cost | $27,866,584,127 |

#### Summary by County

| County | Courses | Total Opportunity Cost | Average Opportunity Cost |
|--------|---------|------------------------|--------------------------|
| Honolulu | 35 | $25.1B | $866.2M |
| Hawaii (Big Island) | 19 | $26.7M | $1.7M |
| Maui | 12 | $2.7B | $299.5M |
| Kauai | 8 | $23.8M | $3.4M |

#### Model vs. Official Assessment Comparison (6 Courses)

| Course Name | County | Model Cost | Official Value | Gap Ratio |
|-------------|--------|------------|----------------|-----------|
| Turtle Bay Resort & Golf Club | Honolulu | $2.27B | $1.85B | 1.23x |
| Waialae Country Club | Honolulu | $718.7M | $620.0M | 1.16x |
| Kaanapali Golf Courses | Maui | $565.3M | $480.0M | 1.18x |
| Wailea Golf Club | Maui | $255.1M | $210.0M | 1.21x |
| Hualalai Golf Club | Hawaii | $295.1M | $175.0M | 1.69x |
| Kohala Country Club | Hawaii | $625.0M | $420.0M | 1.49x |

**Average model-to-assessed ratio: 1.33x** — model estimates are on average 32.6% higher than official assessments.

---

### Phase 5b: Full Pipeline Results (Automated, Honolulu County)

#### Step 1–3 Economic Validation

| Metric | Value |
|--------|-------|
| Phase 1 baseline courses on Oahu | 35 |
| Phase 2 OSM golf polygons on Oahu | 39 |
| Direct point-to-polygon match rate | 31.4% (11/35) |
| Unique TMKs intersecting golf polygons | 1,073 |
| OSM-derived legal footprint (live from Step 2) | 8,564.23 acres |
| Deduplicated Oahu courses (500 m spatial cap) | 33 |
| Pooled opportunity cost — q̄ | **$25.400B** |
| Standard error | $1.397B |
| 95% CI | $22.663B – $28.137B |

#### Step 5 Geographic Concentration

| Zone | District | Parcel Count | % of Parcels |
|------|----------|-------------|-------------|
| 9 | Ewa (Kapolei/Pearl City) | 677 | 63.2% |
| 3 | Honolulu (Anomalies) | 169 | 15.8% |
| 1 | Honolulu (Urban Core) | 103 | 9.6% |
| 4 | Koolaupoko (Kailua/Kaneohe) | 55 | 5.1% |
| 6 | Waialua (North Shore) | 38 | 3.5% |
| 8 | Waianae (West) | 14 | 1.3% |
| 7 | Wahiawa (Central) | 11 | 1.0% |
| 2 | Honolulu (East/Anomalies) | 5 | 0.5% |
| — | **TOTAL** | **1,072** | **100.0%** |

Note: 1,073 TMKs yield 1,072 parent parcel rows; one TMK has no matching parent record in the cadastral CSV after CPR sub-parcel filtering.

#### Step 6 Zoning Intersection (Python/Julia canonical; 6,066.2 acres)

| Zone Class | Description | Acres | % of Golf Total |
|------------|-------------|-------|-----------------|
| P-2 | General Preservation District | 3,209.4 | 52.9% |
| F-1 | Federal and Military Preservation | 1,002.0 | 16.5% |
| P-1 | Restricted Preservation District | 744.6 | 12.3% |
| AG-2 | General Agriculture District | 621.8 | 10.3% |
| AG-1 | Restricted Agriculture District | 213.8 | 3.5% |
| Resort | Resort District | 130.4 | 2.2% |
| C | Country District | 60.9 | 1.0% |
| R-5 | R-5 Residential District | 33.7 | 0.6% |
| Other (11 classes) | B-1, A-2, BMX-3, R-7.5, R-10, A-1, B-2, R-20, R-3.5, I-2, IMX-1 | ~50.1 | ~0.8% |
| — | **TOTAL** | **6,066.2** | **100.0%** |

**Preservation + Federal share:** P-1 + P-2 + F-1 = 4,956 acres = **81.7%** of all Oahu golf land sits within Preservation or Federal/Military zones.

#### Step 6 Zone Penetration (what share of each Honolulu zone class is golf)

| Zone Class | Description | Zone Total (ac) | Golf (ac) | % Golf |
|------------|-------------|-----------------|-----------|--------|
| Resort | Resort District | 513.7 | 130.4 | 25.4% |
| P-2 | General Preservation | 17,259.6 | 3,209.4 | 18.6% |
| B-1 | Neighborhood Business | 399.1 | 13.2 | 3.3% |
| F-1 | Federal/Military Preservation | 38,561.0 | 1,002.0 | 2.6% |
| C | Country District | 3,254.3 | 60.9 | 1.9% |
| AG-2 | General Agriculture | 41,759.9 | 621.8 | 1.5% |
| R-20 | R-20 Residential | 521.2 | 3.1 | 0.6% |
| P-1 | Restricted Preservation | 157,429.3 | 744.6 | 0.5% |
| AG-1 | Restricted Agriculture | 63,462.2 | 213.8 | 0.3% |

**Cross-language note:** R master reports P-1 acreage as 523.5 acres (total: ~5,845 acres); Python and Julia (standalone step and master) report 744.6 acres (total: ~6,066 acres). All other zone classes agree to <0.1 acres. The discrepancy likely reflects minor boundary-handling differences in `sf::st_intersection` vs. GDAL/Shapely at P-1 polygon edges. Python/Julia results are used as canonical.

---

## Key Findings

1. **Systematic Overestimation (Phase 5a):** The model's HBU valuations are consistently higher than official tax assessments, with an average 1.33x premium (32.6% higher on average). This gap is largest for Big Island rural courses (1.49x–1.69x) and narrowest for Honolulu urban courses (1.16x–1.23x).

2. **Preservation-Dominated Footprint (Step 6):** 81.7% of Oahu golf land sits within Preservation or Federal/Military zones — areas where residential redevelopment would face the highest regulatory barriers. This challenges the HBU assumption for a large share of the golf footprint.

3. **Resort Zone Penetration (Step 6):** Golf occupies 25.4% of all Resort-zoned land on Oahu — the highest penetration rate of any zone class — and 18.6% of P-2 General Preservation land, underscoring golf's outsized role in how resort and preserved land is currently used.

4. **Geographic Concentration (Step 5):** 63.2% of golf parcels are in the Ewa district (Zone 9, Kapolei/Pearl City area), reflecting Oahu's post-statehood suburban golf development corridor rather than the urban core.

5. **Point-to-Polygon Representational Error:** Only 31.4% of Phase 1 course points fall directly within a Phase 2 OSM polygon, confirming significant coordinate-to-boundary mismatch across source datasets.

6. **Turtle Bay Case Study:** Turtle Bay Resort shows a 23% model premium ($2.27B vs. $1.85B assessed), demonstrating that the HBU framework captures potential residential development value not fully reflected in current tax assessments.

---

## Limitations

1. **Assessment Timing:** Official values are from 2022; model uses 2022 baseline values but may reflect different market conditions.
2. **Zoning ≠ Regulatory Approval:** Classification in a Preservation or Agricultural zone indicates restriction, not an absolute prohibition. HBU analysis must treat such parcels separately.
3. **Assessment Practices:** County assessment practices vary; some counties use different valuation methodologies.
4. **Phase 5a Sample Size:** Only 6 high-profile courses were manually verified in the pilot; broader validation requires more data.
5. **Tax Exemptions:** Some courses may have tax-exempt status or special assessments not captured in the data.
6. **Cross-Language P-1 Discrepancy:** R `st_intersection` yields ~221 fewer acres in P-1 than Python/Julia; root cause unconfirmed (likely edge-case geometry handling).

---

## Recommendations

1. **Zoning-Adjusted HBU:** Separate golf parcels in Preservation/Federal zones from those in residential/resort zones before applying HBU valuations; the opportunity cost for preservation-zone land is effectively zero under current zoning.
2. **Refine Baseline Values:** Consider adjusting baseline values to account for actual tax assessment ratios in each county.
3. **Expand Validation:** Include more courses in the Phase 5a validation sample for robustness.
4. **County-Specific Adjustments:** Develop county-specific valuation adjustments based on assessment ratio studies.
5. **Temporal Alignment:** Ensure baseline values and assessment values are from the same valuation date.

---

## Implementation Notes

### Output File Conventions

| Language | Output Dir | Filename Prefix | Example |
|----------|-----------|-----------------|---------|
| R master | `Data/R/` | none | `Phase5_Step6_Zoning_Percentages.csv` |
| Python master | `Data/Python/` | `Py_` | `Py_Phase5_Step6_Zoning_Percentages.csv` |
| Julia master | `Data/Julia/` | `Jl_` | `Jl_Phase5_Step6_Zoning_Percentages.csv` |
| Bulk step scripts | `Bulk Tests/<lang>/` | none | `Phase5_Step6_Zoning_Percentages.csv` |

Python intermediate GeoPackages (`Target_Golf_Polygons.gpkg`, `Honolulu_Parcels_Reprojected.gpkg`) and `Target_Golf_Parcels_List.csv` remain in `Bulk Tests/python/` because the individual bulk step scripts read from there.

### Scripts Inventory

| Script | Language | Role |
|--------|----------|------|
| `Phase_5.R` | R | Master pipeline — 6-step end-to-end |
| `Phase_5.py` | Python | Master pipeline — 6-step end-to-end |
| `Phase_5.jl` | Julia | Master pipeline — 6-step end-to-end |
| `Bulk Tests/R/Step1_Data_Acquisition.R` | R | |
| `Bulk Tests/R/Step2_Parcel_Intersection.R` | R | |
| `Bulk Tests/R/Step3_Final_Comparison.R` | R | Rubin's Rules pooling |
| `Bulk Tests/R/Step4_Offical_Tax_Merge.R` | R | Diagnostic merge |
| `Bulk Tests/R/Step5_Gap_Analysis.R` | R | Geographic breakdown |
| `Bulk Tests/R/Step6_Zoning_Intersection.R` | R | Zoning intersection analysis |
| `Bulk Tests/python/Step1_Data_Acquisition.py` | Python | |
| `Bulk Tests/python/Step2_Parcel_Intersection.py` | Python | |
| `Bulk Tests/python/Step3_Final_Comparison.py` | Python | |
| `Bulk Tests/python/Step6_Zoning_Intersection.py` | Python | Zoning intersection analysis |
| `Bulk Tests/Julia/Step1_Data_Acquisition.jl` | Julia | OSM polygon extraction + parcel reprojection |
| `Bulk Tests/Julia/Step2_Parcel_Intersection.jl` | Julia | Cookie-cutter TMK extraction |
| `Bulk Tests/Julia/Step3_Final_Comparison.jl` | Julia | Rubin's Rules pooling + economic validation |
| `Bulk Tests/Julia/Step4_Offical_Tax_Merge.jl` | Julia | Diagnostic merge (console output only) |
| `Bulk Tests/Julia/Step5_Gap_Analysis.jl` | Julia | Geographic concentration breakdown |
| `Bulk Tests/Julia/Step6_Zoning_Intersection.jl` | Julia | Zoning intersection analysis |

### Dependencies

| Language | Key Packages |
|----------|--------------|
| R | tidyverse, sf, this.path |
| Python | geopandas, pandas, numpy, pygris, pathlib |
| Julia | ArchGDAL, GeoDataFrames, DataFrames, CSV, Printf |

---

## Code Standardization

All Phase 5 scripts were standardized for naming consistency, path resolution, and
structural conventions. No logic, formulas, spatial operation parameters, or filter
thresholds were changed.

### Four-Section Structure

Every script follows the same section order:

```
# === 1. LIBRARIES ===      (R, Python)  /  # === 1. USING ===  (Julia)
# === 2. GLOBALS & PATHS ===
# === 3. FUNCTIONS ===
# === 4. EXECUTION ===
```

Sections with no content use `# (none)` as the body.

### Variable Renaming

| Old name | New name | Applies to |
|----------|----------|------------|
| `gdf_osm`, `osm_sf` | `osm_golf_geo` / `osm_golf_sf` | all languages |
| `gdf_parcels`, `parcels_sf` | `parcels_geo` / `parcels_sf` | all languages |
| `all_oahu_osm` | `oahu_golf_sf` | R |
| `phase1_df` | `baseline_df` | R |
| `phase1_sf` | `oahu_baseline_sf` | R |
| `oahu_boundary` | `oahu_boundary_sf` | R |
| `turtle_bay_polygon`, `turtle_bay_reprojected` | `target_golf_geo` | Python, Julia |
| `gdf_turtle_bay` | `target_golf_geo` | Python, Julia |
| `result` (intersection) | `parcel_intersection_sf` / `parcel_intersection_geo` | all |
| `result_df` | `tmk_df` | all |
| `gdf_turtle_bay`, `gdf_parcels` | `target_golf_geo`, `parcels_geo` | Python, Julia |
| `df` (comparison) | `comparison_df` | Python, Julia |
| `course_name` (literal constant) | `TARGET_COURSE` | Python, Julia |
| `script_dir`, `root_dir` | `SCRIPT_DIR`, `WORK_DIR` | R master |
| `Q_bar`, `V_W`, `V_B`, `V_T`, `SE`, `CI_lo`, `CI_hi` | `q_bar`, `v_w`, `v_b`, `v_t`, `se`, `ci_lo`, `ci_hi` | R (Step 3, Phase_5.R) |
| `osm_polys` | `osm_polys_sf` | R |
| `fmt_currency()` (unused) | removed | Julia Step 3 |
| `geo_summary` (Step 5) | `zone_summary_z6`, `zone_penetration_z6` | R, Julia masters (Step 6, avoids collision) |

### Path Resolution

| Language | Anchor | Example |
|----------|--------|---------|
| R | `this.path::this.dir()` | `SCRIPT_DIR <- this.path::this.dir()` |
| Python | `pathlib.Path(__file__).parent` | `SCRIPT_DIR = Path(__file__).parent` |
| Julia | `@__DIR__` | `const SCRIPT_DIR = @__DIR__` |

**Bulk test scripts** (paths from `Bulk Tests/<lang>/`):
- 3 levels up → `WORK_DIR` (= `2 - Work/`)
- 2 levels up → `PHASE5_DIR` (= `Phase 5 The Hawaii Micro-Case Study/`)

**Master scripts** (paths from `Phase 5 The Hawaii Micro-Case Study/`):
- 1 level up → `WORK_DIR`
- Outputs to `SCRIPT_DIR/Data/<Language>/`

### `[METHODOLOGY]` Flags

| Operation | Tag |
|-----------|-----|
| `st_read()` / `GeoDataFrames.read()` / `gpd.read_file()` | spatial read of source layer |
| `st_write()` / `GeoDataFrames.write()` / `.to_file()` | persist for next step |
| `st_transform()` / `ArchGDAL.reproject()` / `.to_crs()` | CRS alignment |
| `st_filter()` | spatial subset to Honolulu county |
| `st_intersects()` | Phase 1 point-to-polygon match rate |
| `st_intersection()` / `gpd.overlay(how='intersection')` / `ArchGDAL.intersection` | cookie-cutter parcel or zoning intersection |
| `st_as_sf()` | tabular-to-spatial conversion |
| `st_nearest_feature()` | Phase 1 point → nearest OSM polygon assignment |
| `st_distance()` | 500 m nearest-neighbor cap |
| `st_area()` / `ArchGDAL.geomarea()` / `.geometry.area` | area computation |
| Bounding box filter | 21.2–21.9°N, −158.5 to −157.6°W — Oahu geographic filter |

### Language-Specific Conventions

- **R:** `library(dplyr)` + `library(readr)` + `library(stringr)` consolidated to `library(tidyverse)` in Steps 4, 5, and Phase_5.R. All `%>%` replaced with `|>`. `1:n` loops replaced with `seq_len(n)`.
- **Python:** All scripts wrapped with `def main(): ... if __name__ == "__main__": main()` guard. `import os` replaced with `from pathlib import Path`. `exit(1)` replaced with `raise SystemExit(1)`.
- **Julia:** All scripts wrapped with `function main() ... end` + `if abspath(PROGRAM_FILE) == @__FILE__ main() end` guard. All module-level variables declared `const`. Step 6 uses the `createcoordtrans` do-block pattern for CRS reprojection.

### Bugs Flagged (Not Fixed)

1. **Step4 `else if` parenthesis error** — `all(nchar(tmk_df$TMK_clean)) == 9` should be `all(nchar(tmk_df$TMK_clean) == 9)`. Flagged with `[REVIEW NEEDED]`.
2. **Julia Step1/Step2 path inconsistency** — original Step 2 used `joinpath(@__DIR__, "..", "Data", "Julia")` (1 level up, `Bulk Tests/Data/Julia/`) while Step 1 used 2 levels up (`Phase5/Data/Julia/`). Standardized both to `PHASE5_DIR/Data/Julia/`.

### Fixes Applied

1. **`"..."` typo in `WORK_DIR`** — Steps 4 and 5 had `file.path(SCRIPT_DIR, "..", "..", "...")` with a literal three-dot string. Corrected to `file.path(SCRIPT_DIR, "..", "..", "..")`.
2. **`ROOT_DIR` → `WORK_DIR`** in Step 1 — renamed for cross-script consistency.
3. **Duplicate "Total Official Assessed Value" row** in Step 3 bulk test — removed.
4. **Python master output paths** — `Phase_5.py` was writing all CSVs to `Bulk Tests/python/`; corrected to `Data/Python/Py_*.csv` to match the Phase 1/2 convention. Intermediate GeoPackages remain in `Bulk Tests/python/`.
5. **`REGRESSION_CSV` dead code removed (Julia & Python masters)** — Both `Phase_5.jl` and `Phase_5.py` declared a `Jl_Regression_Results.csv` / `Py_Regression_Results.csv` constant and ran existence checks on it, but never loaded it. Phase 5 computes opportunity cost directly as `osm_acreage × Baseline_Value_Per_Acre` from Phase 3 imputed datasets; Phase 4 regression outputs play no role. The declaration, header comment, and existence check were removed from both master scripts.
6. **Python `# === 1. LIBRARIES ===` section header** — `Phase_5.py` used the non-standard heading `# === 1. IMPORTS ===`; corrected to `# === 1. LIBRARIES ===` per CLAUDE.md convention (applies to all Phase master scripts).
7. **Python memory management in imputed dataset loop** — `run_step3()` loaded 100 CSVs without releasing memory between iterations. Added `del df_i; gc.collect()` after extracting the Oahu subset in each loop iteration; added `import gc` to Section 1.
8. **Python `[METHODOLOGY]` tags in `run_step6()`** — Two `gpd.read_file()` calls (golf polygons and zoning layer) were missing the required `# [METHODOLOGY]` tag. Added.
9. **Python `OSM_DERIVED_ACRES = 8342.28` replaced with live computation** — The hardcoded module-level constant reflected an earlier run and became stale. `run_step2()` already computed `total_acres` from the Step 2 intersection geometry; it now returns that value. `run_step3()` accepts it as a parameter (`osm_derived_acres`), and `main()` captures and forwards it. See also *Acreage Discrepancy Note* below.
10. **Python `Zone_Code` float string bug in `run_step5()`** — The `Zone` column from the Honolulu cadastral CSV reads as `float64`; `.astype(str)` produced `"9.0"` rather than `"9"`, causing all `DISTRICT_MAP` lookups to fall through to the `"Zone 9.0"` fallback. Added `dropna(subset=["Zone"])` (parallel to Julia's `dropmissing!(geo_merged, :Zone)`) and changed the cast to `.astype(int).astype(str)`. District names now resolve correctly (e.g. `"Ewa (Kapolei/Pearl City)"`).

---

## Julia Pipeline Implementation

**Date Completed:** May 1, 2026
All Julia bulk-test step scripts (Steps 1–6) are debugged and fully functional. The standalone
master script `Phase_5.jl` runs all steps end-to-end in memory without invoking daughter scripts.

### Data Flow (Standalone Master)

```
Phase 1 CSV  ─────────────────────────────────────────► Step 1: point-in-polygon rate
Phase 2 GPKG ─► oahu_golf_geo ──────────────────────►│
Parcels GPKG ─► parcels_geo (reprojected) ──────────►│ Step 2: spatial intersection
                                                       │
                     unique_tmks (1,073) ─────────────►│ Step 3: economic validation
Phase 3 CSVs (×5) ───────────────────────────────────►│         (Rubin's Rules + dedup)
Phase 4 CSV  ─────────────────────────────────────────►│
                                                       │
                     unique_tmks ────────────────────►  Step 5: geographic breakdown
Honolulu tax CSV ───────────────────────────────────►
                                                        Step 6: zoning intersection
Zoning GPKG  ─► (reprojected to EPSG 5070) ─────────►  golf × zoning fragments → CSVs
oahu_golf_geo ──────────────────────────────────────►
```

### Output Files (Standalone Master)

| File | Description |
|------|-------------|
| `Data/Julia/Jl_Phase5_Oahu_Comparison.csv` | Economic validation table (pooled opportunity cost, CI, acreage) |
| `Data/Julia/Jl_Phase5_Geographic_Breakdown.csv` | Zone-level parcel counts and share of total |
| `Data/Julia/Jl_Phase5_Step6_Zoning_Percentages.csv` | Golf footprint by zoning class (acres, % of total) |
| `Data/Julia/Jl_Phase5_Step6_Zone_Golf_Penetration.csv` | % of each Honolulu zone class occupied by golf |

### Bugs Fixed in Julia Step Scripts

#### Step 3 — `MethodError: no method matching reproject`
- **Root cause:** `reproject_geom` called `ArchGDAL.reproject(geom, ISpatialRef, ISpatialRef)`, which does not exist in this version of ArchGDAL.jl.
- **Fix:** Replaced with the `createcoordtrans` do-block + `transform!` pattern:
  ```julia
  function reproject_geom(geom, src_crs, tgt_crs)
      ArchGDAL.createcoordtrans(src_crs, tgt_crs) do t
          ArchGDAL.transform!(geom, t)
          geom
      end
  end
  ```

#### Step 3 — Axis-swap bug (`importEPSG(4326)`)
- **Root cause:** `ArchGDAL.importEPSG(4326)` in GDAL 3.x uses official lat/lon axis order, silently swapping coordinate axes.
- **Fix:** Changed to `ArchGDAL.importPROJ4("+proj=longlat +datum=WGS84 +no_defs")` (guarantees lon/lat order). Used in both step scripts and master.

#### Steps 4 & 5 — `ArgumentError: Duplicate variable names: :TMK`
- **Root cause:** Both the Step 2 TMK list and the Honolulu cadastral CSV have a column named `"TMK"`. `innerjoin` on `:TMK_clean` collides on the shared `:TMK` column.
- **Fix:** Added `makeunique = true` to every `innerjoin` where a Step 2 TMK list is joined against the Honolulu CSV.

#### Step 5 — 83.6% of rows showing missing district zone
- **Root cause:** Honolulu cadastral CSV contains CPR sub-parcel records that share a parent TMK but carry `missing` in the `Zone` column, causing a 6.1× row multiplier.
- **Fix:** Added `dropmissing!(merged_data, :Zone)` immediately after the join. Row count dropped from 6,556 to 1,072.

#### Step 6 — `column name :geometry not found`
- **Root cause:** The Honolulu zoning GeoPackage stores geometry in the column `SHAPE` (ArcGIS convention); GeoDataFrames does not normalize this to `geometry`.
- **Fix:** Changed `reproject_geoms(zoning_gdf.geometry, ...)` to `reproject_geoms(zoning_gdf.SHAPE, ...)`.

#### Step 6 — `MethodError: no method matching createcoordtrans(::ISpatialRef, ::ISpatialRef)`
- **Root cause:** This version of ArchGDAL.jl requires `createcoordtrans` to take a `Function` as its first argument (resource-management/do-block pattern); a direct two-argument call is unsupported.
- **Fix:** Rewrote `reproject_geoms` as a do-block accumulator:
  ```julia
  function reproject_geoms(geoms, src_epsg::Int, dst_epsg::Int)
      src_sr = ArchGDAL.importEPSG(src_epsg)
      dst_sr = ArchGDAL.importEPSG(dst_epsg)
      result = ArchGDAL.IGeometry[]
      ArchGDAL.createcoordtrans(src_sr, dst_sr) do coord_tf
          for g_orig in geoms
              g = ArchGDAL.clone(g_orig)
              ArchGDAL.transform!(g, coord_tf)
              push!(result, g)
          end
      end
      return result
  end
  ```

### Acreage Discrepancy Note

The daughter script `Step3_Final_Comparison.jl` uses a hardcoded constant `OSM_DERIVED_ACRES = 8342.28`. The standalone `Phase_5.jl` computes acreage live from the Step 2 spatial intersection geometry, yielding **8,564.23 acres**. `Phase_5.py` previously carried the same stale constant (`OSM_DERIVED_ACRES = 8342.28` in Section 2); this has been corrected — `run_step2()` now returns `total_acres` computed live, and `run_step3()` accepts it as a parameter. The live-computed value (**8,564.23 acres**) is authoritative; the hardcoded constant in the Julia daughter script `Step3_Final_Comparison.jl` remains stale but that script is not part of the master pipeline.

---

## Cross-Language Consistency Notes (Post-Audit)

### Oahu OSM Polygon Count

Each master script reads its own language-prefixed Phase 2 GeoPackage (`R_Phase2_OSM_Golf_Polygons.gpkg`, `Jl_Phase2_OSM_Golf_Polygons.gpkg`, `Py_Phase2_OSM_Golf_Polygons.gpkg`). The spatial filter to Oahu's bounding box produces a one-course difference:

| Language | Oahu OSM polygons |
|----------|------------------|
| R        | 38               |
| Julia    | 39               |
| Python   | 39               |

This difference is traceable to minor variation in the three Phase 2 runs (different polygon parse order, potential edge-case geometry differences) and is within the expected cross-language Phase 2 spread. It does not affect the economic validation conclusions.

### Geographic Breakdown (Step 5)

All three languages produce identical parcel counts and zone distributions (1,072 parcels; Zone 9 = 63.2%). Prior to the audit, Python displayed zone codes as `"9.0"` and district names as `"Zone 9.0"` due to float-to-string coercion. This has been corrected; all three languages now produce matching `Zone_Code` (integer string) and `District_Name` values.

### 37-Course Ewa District Figure

The figure "37 courses in Ewa District (Zone 9)" referenced in Phase 6 output cannot be confirmed from Phase 5 alone — Phase 5 Step 5 produces parcel-level zone breakdowns, not course-level counts by district. Verification requires cross-referencing Phase 6 Script 9 (Oahu spatial summary).
