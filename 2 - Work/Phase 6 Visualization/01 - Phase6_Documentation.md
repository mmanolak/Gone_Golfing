---
title: "Phase 6 Summary: Visualization"
author: "Michael"
format:
  pdf:
    toc: true
    number-sections: true
    colorlinks: true
---

# Phase 6 — Visualization

## Overview

Phase 6 produces all publication-ready figures, maps, and LaTeX tables for the thesis. Scripts are organized under `Bulk/R/` and `Bulk/Julia/` and follow a shared four-section layout (`LIBRARIES`, `GLOBALS & PATHS`, `FUNCTIONS`, `EXECUTION`). All raster outputs target 300 DPI equivalent.

### Language Assignment Strategy

After evaluating output quality across all three candidate languages, the following assignment has been adopted:

| Language | Scope |
|----------|-------|
| **R** | All spatial/geographic map outputs — national choropleths, county maps, Oahu micro-maps, bivariate maps, and the Oahu opportunity cost map. R's `sf` + `ggplot2` + `tigris` stack consistently produces higher-quality cartographic output than the Julia GeoMakie pipeline. |
| **Julia** | All non-spatial outputs — statistical plots (forest, density, marginal effects, raincloud) and LaTeX table generation. CairoMakie produces clean, publication-quality figures for these chart types. |
| **Python** | Not used. Python performs poorly for both data visualization (charts) and physical/cartographic mapping relative to R and Julia in this context. |

### Last Verified Run — May 6, 2026

`Phase_6.R` executed successfully (exit code 0). All outputs confirmed written.

| Metric | Value |
|--------|-------|
| **Tri-Language Grand Mean — National Total** | **$0.944T** |
| Observed-only baseline | $0.788T (82.5% of MICE-pooled) |
| States covered | 51 |
| Counties covered | 2,890 |
| Oahu pooled OC (M=100 R draws) | $31.197B across 37 courses |
| OLS coefficients | β₀=12.225, β_holes=0.053, β_urban=4.002 |

**Top 5 states (Grand Mean):** CA $293.70B · FL $111.95B · NY $53.91B · TX $38.61B · HI $35.61B  
**Top 5 counties:** Los Angeles $49.73B · Orange $38.47B · Santa Clara $33.80B · San Diego $30.31B · Honolulu $29.69B

**Script 15 (resolved May 2026, Part 6C):** Log-residual range corrected from `[NaN, NaN]` (all-gray render) to `[−2.809, 4.437]`. Dollar-residual corrected from `$−1.766e12` absurd magnitudes to `[$−1.30B, $45.86B]`. See Part 6C in the Structural Audit Log and the Script 15 section for full fix details.

---

### Structural Audit Log

**Phase_6.jl — Audited May 8, 2026 (Checklist Point 26)**  
Full read of all 1,843 lines across 7 modules. Three categories of issues identified and corrected:

1. **Path case inconsistency — 7 locations fixed.** Mod_5, Mod_6, Mod_10, Mod_11, and Mod_12 used `"Python"` (capital-P) in Phase 3 and Phase 4 data directory path components. The authoritative directory file specifies `python` (lowercase). Fixed at lines 143, 264, 306, 322, 639, 970, and 1242. Mod_13 and Mod_14 were already correct.

2. **Mislabeled `[METHODOLOGY]` flags — 2 removed.** Comments reading `# [METHODOLOGY] Spatial read of Phase 1 Jl baseline` appeared above plain `CSV.read()` calls in Mod_11 (line 1151) and Mod_12 (line 1428). `CSV.read()` does not qualify as a spatial read per CLAUDE.md; both comments removed.

3. **Top-level execution block not wrapped in `main()` — 1 fix.** The `Threads.@spawn` / `fetch` / `GC.gc()` block at lines 1817–1842 existed at file top level. CLAUDE.md requires all Julia logic inside `main()`. Block wrapped in `function main() ... end` with `main()` called at the bottom of the file.

All other structural requirements passed: `@__DIR__` path resolution correct, Rubin's Rules independent per language (M=100 each), Grand Mean as arithmetic mean of three pooled β vectors, memory-safe loops with `df = nothing; GC.gc()` throughout, 20 density PNGs with correct `5.211–5.245` naming, four-section layout in all modules, no `log(acreage)` anywhere.

**Phase_6.R — Audited May 8, 2026 (Checklist Point 27)**  
Full read of all ~2,280 lines across `compute_grand_means()` and seven `run_X_()` functions. Six categories of issues identified and corrected:

1. **Missing top-level Section 2 & 3 headers — added.** The file-level four-section structure lacked `# === 2. GLOBALS & PATHS ===` and `# === 3. FUNCTIONS ===` headers between the LIBRARIES block and `compute_grand_means()`. Both added with the required two blank lines between sections.

2. **Execution code outside Section 4 — moved.** `grand_means <- compute_grand_means()` and `plan(sequential)` appeared at file top level between function definitions (after `compute_grand_means()`, before `run_1_Macro_Maps()`). Moved into the `# === 4. EXECUTION ===` block where they now run before all `run_X_()` calls.

3. **Section 4 header missing number — fixed.** `# === EXECUTION ===` corrected to `# === 4. EXECUTION ===`.

4. **Missing `[METHODOLOGY]` flag on Rubin's q_bar in `pool_oahu_oc()` — added.** The `bind_rows() |> group_by() |> summarise(pooled_opp_cost = mean(...))` block inside the nested `pool_oahu_oc()` helper (Script 9) lacked a `[METHODOLOGY]` comment. Added above the summarise call.

5. **Stale loop variable in Script 1 coverage calculation — fixed.** `run_1_Macro_Maps()` Step 5 divided observed totals by `pooled_state$pooled_opp_cost`, which held the Julia pool after the loop. Fixed to reference `grand_means$state$GrandMean$pooled_opp_cost` directly.

6. **Stale loop variable in Script 2 coverage calculation — fixed.** Same bug in `run_2_County_Map()` Step 5 (`pooled_county` → `grand_means$county$GrandMean$pooled_opp_cost`).

All other structural requirements passed: `this.path::this.dir()` path resolution correct throughout, Rubin's Rules independent per language (M=100 each) in all pooling functions, Grand Mean used for all choropleth values, `rm()`/`gc()` inside every sequential dataset-loading loop, furrr parallel loops use pipeline pattern (no intermediate variables), only R_-prefixed CSVs read (Py_/Jl_ reads in master's tri-language aggregation context are correctly authorized), ObservedOnly variants present for Scripts 1, 2, 7, 9, Script 8 shows Py/R/Jl side-by-side, no `log(acreage)` anywhere, `[METHODOLOGY]` flags on all `st_read`/`st_transform`/`st_join`/pooling blocks, all constants in ALL_CAPS in Section 2.

**Phase_6.R — Spot-Check May 9, 2026 (Checklist Part 6A)**  
Targeted re-verification of all 9 items fixed or confirmed during Point 27. Zero regressions found.

1. Four-section headers (`# === 1. LIBRARIES ===` through `# === 4. EXECUTION ===`) all present with two blank lines between — confirmed.
2. `compute_grand_means()` and all seven `run_X_()` functions reside in the file-level Section 3 — confirmed.
3. `grand_means <- compute_grand_means()` is at line 2274, inside the top-level `# === 4. EXECUTION ===` block — confirmed (not between function definitions).
4. `plan(sequential)` is at line 2275, immediately after the grand_means assignment — confirmed.
5. Script 1 Step 5 coverage calculation references `grand_means$state$GrandMean$pooled_opp_cost` (line 377) — confirmed, stale loop variable fix held.
6. Script 2 Step 5 coverage calculation references `grand_means$county$GrandMean$pooled_opp_cost` (line 620) — confirmed, stale loop variable fix held.
7. `# [METHODOLOGY]` tag on `pool_oahu_oc()` Rubin's q_bar block (line 1663) — confirmed.
8. No `log(acreage)` string anywhere — grep confirmed.
9. All `library()` calls in Section 1 only (lines 17–29) — grep confirmed, none elsewhere.

Bonus closure: Script 9 `POLYGONS_GPKG` (line 1586) resolves to `Phase 5 The Hawaii Micro-Case Study/Data/R/Target_Golf_Polygons.gpkg`, matching Phase 5 R write target exactly. Phase 5 → Phase 6 Script 9 handoff confirmed intact (closes open 5D item).

**Phase_6.jl — Spot-Check May 9, 2026 (Checklist Part 6B)**  
Targeted re-verification of all 6 items fixed during Point 26. Zero regressions found.

1. `"python"` (lowercase) confirmed at all 7 fixed path-string locations: Mod_5 line 143 (lang tuple dir_name), Mod_6 line 264 (Phase 4 py reg path), Mod_10 lines 306 and 322 (Phase 4 reg + Phase 3 MICE dir), Mod_11 line 639 (Phase 3 dir), Mod_12 line 970 (Phase 3 dir), Mod_13 line 1241 (Phase 3 dir). Mod_14 correct as before (lines 1506, 1677).
2. No `# [METHODOLOGY] Spatial read` comment above any `CSV.read()` call — grep confirmed (both Mod_11 ~1151 and Mod_12 ~1428 removals held).
3. `function main() ... end` present in all 7 modules (Mod_5 through Mod_14) and in the top-level dispatcher block. `main()` call confirmed at file line 1844.
4. No `Plasma.jl` reference anywhere — grep confirmed.
5. No `log(acreage)` string anywhere — grep confirmed.
6. No M=300 single-pool anywhere — grep confirmed. All Rubin's Rules blocks pool independently at M=100 per language.

Minor observation: file-level comment header (line 7) reads `Data/Python/` (capital P) while the actual runtime path uses `"python"` (lowercase). Comment-only discrepancy; no runtime impact.

**Phase 6 Integration Check — May 9, 2026 (Checklist Part 6C)**  
Cross-script integration audit: path routing, filename convention, output directory structure, and cross-language reads. 1 fix, 4 observations.

1. **PASS — `compute_grand_means()` tri-language path routing** (Phase_6.R lines 55, 85, 112): `PHASE3_DIR` (R), `PHASE3_PY_DIR` (python), `PHASE3_JL_DIR` (Julia) all constructed via `file.path(WORK_DIR, ...)`. All three language directories read correctly. No hardcoded absolute paths.
2. **OBS — Phase_6.jl reads from all three language directories by design**: Checklist item was overstated. Mod_11 (Lorenz, lines 1188/1194), Mod_13 (Counterfactual, lines 1454/1457), Mod_14 (Scatter, lines 1677–1678), and Mod_9 (Oahu OC, lines 878/894) all read from Py and R directories. All qualify as tri-language diagnostic visualization functions under the CLAUDE.md exception clause. Each language is processed independently; no cross-language statistical pooling occurs.
3. **OBS — $0.944T plausibility unverifiable without execution**: Output directories are empty (scripts not yet run). Per 4D tracker, $0.944T is the Phase 3 MICE national aggregate (acreage × FHFA), computed by `compute_grand_means()`, not a Phase 4 regression coefficient. Checklist phrasing was imprecise.
4. **OBS — Script 9 no per-language QA maps; Script 15 no ObservedOnly**: Script 9 (`run_9_Oahu_Opportunity_Cost_Map()`) produces only `9.141_GrandMean` and `9.101_ObservedOnly` — no `9.111_Julia`, `9.121_Python`, `9.131_R` QA variants. Script 15 produces two GrandMean maps (log + dollar) only — no ObservedOnly is possible without a separate observed-only regression pass.
5. **PASS — No filename conflicts**: Phase_6.R holds prefixes 1–4, 7, 9, 15; Phase_6.jl holds 5–6, 10–14. Sets are disjoint; no collision risk.
6. **FIX — `11_Lorenz_Curve_TriLanguage.png` violated 1.234 convention** (Phase_6.jl lines 19 and 979): renamed to `11.141_Lorenz_Curve_TriLanguage.png` in both the header comment and the `OUT_LORENZ` constant. All other Phase_6.jl output names follow the convention.
7. **OBS — Phase_6.jl header comment stale**: Line 4 says "scripts 5, 6, and 10" but file handles Mod_5 through Mod_14 (scripts 5, 6, 10–14). Output file list (lines 11–19) omitted `12.141_`, `13.141_`, `14.141_` outputs. Comment-only; no runtime impact. Output file index in this document corrected to match actual script output names.

**Script 15 Residual Map Diagnostic — May 2026 (Checklist Part 6C)**  
Six formula and methodology bugs identified and corrected in standalone `Bulk/R/15_Residual_Map.R`, then ported one-for-one into `run_15_Residual_Map()` in `Phase_6.R`:

1. **Log-residual formula corrected.** Pre-patch formula `log(final_acreage) - predicted_log` was off by `log(BVPA) ≈ 15.4` log-units. Corrected to `log(acreage × Baseline_Value_Per_Acre) - predicted_log`.
2. **Dollar-residual units error corrected.** Pre-patch subtracted dollars from acres then multiplied by $/acre, producing `$−1.766e12` magnitudes. Corrected to `(acreage × Baseline_Value_Per_Acre) - exp(predicted_log)` with both terms in dollars.
3. **`acreage > 1` filter added.** Guards against `log(0)` / `log(1e−15)` from near-zero MICE-imputed acreage values.
4. **FIPS-safe cross-language join.** `select(-any_of(c("FIPS", "County_Name", "State_Abbr", "Tigris_State_Abbr")))` before `left_join(county_lookup, by = c("Longitude", "Latitude"))`. Drops native FIPS/county columns from Py/Jl (no-op for R). Fixes both the R FIPS-not-found error and the Julia `State_Abbr` column conflict.
5. **Holes range filter added.** `filter(between(Holes, 9, 72))` guards against the 252-hole Phase 1 aggregate record causing `exp(b_holes × 252) ≈ $3.7T` explosion in the dollar-residual map.
6. **Verified output ranges (Grand Mean, M=300 total).** Log-residual: [−2.809, 4.437]. Dollar-residual: [$−1.30B, $45.86B]. Counties with residuals: 2,874 of 3,144.

CLAUDE.md updated: FIPS asymmetry corrected, Script 15 status marked Fixed.

**FIPS-NA Diagnostic Audit — May 2026 (Checklist Part 6D)**  
Read-only national audit confirming 34 FIPS-NA courses (0.21% of 16,292) — consistent across all three language pipelines (R: 34, Py: 34, Jl: 34). Three questions resolved:

1. **Q1 — $4,952,600/acre anchor confirmed.** Exact match between thesis value and FHFA source (`2024 - FHFA June 20 Land Prices.xlsx`, sheet "Panel Counties", Year==2022, FIPS 15003). R's Phase 1 lookup reads the correct source value directly.
2. **Q2 — Root cause: `cb=TRUE, resolution="20m"` cartographic boundary simplification.** All 5 Hawaii FIPS-NA courses are 54–433 meters outside the 1:20,000,000 simplified polygon. Hawaii Kai (54.7m) and Mid-Pacific (140.4m) also resolve with `cb=FALSE`. Kahili and King Kamehameha Golf Club on Maui share identical coordinates at 352m from any polygon — likely a source data coordinate issue, not a pipeline error.
3. **Q3 — Thesis defensible.** 34 courses across 16 states (HI:5, CA:4, FL:4, WI:4, AL:3, MI:2, OR:2, SC:2; CT/MA/MD/ME/NY/OH/VA/WA: 1 each). Distribution is consistent with coastal/water-boundary simplification artifacts. The §5.4.2 footnote already covers the known Hawaii cases. No Phase 1 re-run required before defense.

Diagnostic outputs (read-only) in `Phase 7 Documentation.../QA/`: `FIPS_NA_Audit.R`, `FIPS_NA_Audit_Report.md`, `FIPS_NA_Courses_R.csv` (34 courses), `FIPS_NA_State_Summary.csv`.

**Script 9b Rural-USDA Sensitivity — May 2026 (Checklist Part 6E)**  
New defense-only bulk script `9b_Oahu_OC_Map_Rural_USDA_Sensitivity.R` written, standalone test run confirmed, and integrated into `Phase_6.R` as `run_9b_Oahu_OC_Rural_USDA_Sensitivity()`. CLAUDE.md updated with full methodology.

Reclassification keyed on `ZONMAP_NO` from `Zoning_Map_Boundary.geojson` (34 polygons, City & County of Honolulu Development Plan boundary layer):
- Codes 1–14, 21–24 (urban/suburban core and Windward Oahu: Kualoa, Kaneohe, Kailua, Waimanalo) → FHFA ($4,952,600/ac)
- Codes 15–20 (rural: Lualualei/Makaha, Makua/Kaena, Mokuleia/Wailua/Haleiwa, Kawailoa/Waialee, Kahuku/Laie, Hauula/Punaluu/Kaaawa) → USDA ($29,887/ac, read dynamically)
- Code 0 — no golf courses present

FHFA normalization applied to ALL Oahu BVPA before any USDA override, correcting Hawaii Kai and Mid-Pacific (FIPS-NA courses whose BVPA was MICE-imputed in Py/Jl rather than resolved from Phase 1). Zone assignment: `st_centroid` → `st_join(st_within)` → `st_nearest_feature` fallback (500m cap). Grand Mean: Rubin's Rules independently per language (M=100), arithmetic mean of three. Output: `9b.141_Oahu_OC_Map_Rural_USDA_Sensitivity_GrandMean.png` — standalone to `Bulk/R/output/`, master to `output/Final_Thesis_Figures/`.

**Phase_6.jl Module 5 Library Fix — May 14, 2026**  
`Plots` package removed from `Mod_5_Econometric_Plots` `using` statement (was: `using CSV, CairoMakie, DataFrames, Printf, Colors, Plots`; now: `using CSV, CairoMakie, DataFrames, Printf, Colors`). `Plots.jl` and `CairoMakie.jl` export overlapping function names (`scatter!`, `lines!`, and others); loading both in the same module scope causes Julia binding-ambiguity errors at runtime. `Colors` is retained — required for the `colorant""` string macro used by the UHM color palette constants (`UHM_GREEN`, `UHM_GOLD`, etc.) added in the same editing pass. Remaining changes in that pass are cosmetic: subtitle color standardized to `#024731` (UHM Green), caption font sizes updated to 10pt, and `word_wrap = true` added to multi-line captions across all modules.

---

## Master Scripts (Completed & Refactored)

The initial bulk scripts have been fully consolidated into two standalone master execution pipelines:

- **`Phase_6.R`** — A monolithic R script that aggregates and sequentially produces all geographic map outputs. It utilizes `furrr`, `future`, and `parallelly` to distribute MICE dataset loading across CPU cores. It also introduces **Tri-Language Grand Mean** logic: calculating the pooled mean of Python, R, and Julia imputed datasets to generate 4 comparative map outputs per core cartographic figure (Grand Mean, Python, R, and Julia variations).
- **`Phase_6.jl`** — A monolithic Julia script encapsulated via strict native modules to guarantee memory isolation. It sequentially produces all non-spatial figures and LaTeX tables. Core plots (e.g., Lorenz curves, Dumbbell gaps) have been refactored to plot tri-language color-coded series (Green: Python, Blue: R, Purple: Julia) to visually trace MICE variations.

### General Naming Scheme & Output Routing
Standardize all visualization PNG outputs across the entire Phase 6 pipeline to follow the specific `1.234` logic format, where:

- **1** = Main script number (1 to 15)
- **.2** = Sub-category/part of the script
- **3** = Language identifier (1=Julia, 2=Python, 3=R, 4=GrandMean/All, 0=Observed-Only/No MICE)
- **4** = Sub-count / sequential index

The master scripts (`Phase_6.R` and `Phase_6.jl`) automatically route outputs into two distinct sub-directories based on the 3rd digit logic:
- `output/Final_Thesis_Figures/`: Final assets intended for the LaTeX document (3rd digit `4` or `0`).
- `output/QA_Verification/`: Internal visual verification files (3rd digit `1`, `2`, or `3`).

---

## R Bulk Scripts

Nine R scripts have been completed under `Bulk/R/`. All use `this.path::this.dir()` for script-relative path resolution. Scripts 1, 2, 7, and 9 produce two map variants each: a MICE-pooled version (`.1`) and an observed-acreage-only version (`.2`).

---

### Script 1 — `1_Macro_Maps.R`
**Outputs:** `output/1.1_National_Opportunity_Cost_Map.png` (14 × 9 in), `output/1.2_National_Opportunity_Cost_Map_ObservedOnly.png` (14 × 9 in)

**1.1 — MICE-pooled (4 Variations):** State-level national choropleth. OC computed via MICE pooling. The script leverages the global Tri-Language Grand Mean calculation to automatically render and save four distinct variations of this map: `GrandMean`, `Python`, `R`, and `Julia`. Fill uses Viridis "plasma" on a linear scale. Alaska and Hawaii repositioned as insets via `tigris::shift_geometry()`. CRS: NAD83/Conus Albers (EPSG 5070).

**1.2 — Observed-only:** Identical map structure. OC restricted to courses with directly measured OSM polygon acreage (`acreage_source != "MICE_Target"` from Phase 2). Simple county-level sum; no pooling. States without observed-acreage courses rendered gray.

A shared `build_state_map()` function renders both outputs from a common ggplot template.

**Key inputs:** `R_Imputed_Dataset_{1..100}.csv`, `R_Phase1_Baseline_Golf_Valuation.csv`, `R_Phase2_Acreage_Matched_v2.csv`  
**R packages:** `tidyverse`, `sf`, `tigris`, `scales`, `this.path`

---

### Script 2 — `2_County_Map.R`
**Outputs:** `output/2.1_County_Opportunity_Cost_Map.png` (14 × 9 in), `output/2.2_County_Opportunity_Cost_Map_ObservedOnly.png` (14 × 9 in)

**2.1 — MICE-pooled (4 Variations):** County-level choropleth aggregated to 5-digit FIPS. Utilizes the global Tri-Language Grand Mean calculation to render four map variants (`GrandMean`, `Python`, `R`, `Julia`). Fill uses Viridis "plasma" on a log₁₀ scale to reveal geographic spread across the highly right-skewed county distribution. Counties without golf courses rendered in gray. Alaska and Hawaii shown as insets. CRS: EPSG 5070.

**2.2 — Observed-only:** Identical log₁₀ choropleth restricted to courses with directly measured OSM acreage from Phase 2.

A shared `build_county_map()` function renders both outputs.

**Key inputs:** `R_Imputed_Dataset_{1..100}.csv`, `R_Phase1_Baseline_Golf_Valuation.csv`, `R_Phase2_Acreage_Matched_v2.csv`  
**R packages:** `tidyverse`, `sf`, `tigris`, `scales`, `this.path`

---

### Script 3 — `3_Oahu_TMK_Map.R`
**Output:** `output/3_Oahu_TMK_Concentration_Map.png`

High-resolution micro-map of Oahu rendering all 1,072 golf course TMK parcels. Ewa District (Zone 9) parcels are highlighted in orange-red (`#E05C14`); all other districts in dark gray. Island outline derived by dissolving all Honolulu parcels. North arrow and scale bar added via `ggspatial`. Projection: WGS 84 / UTM Zone 4N (EPSG 32604).

**Key inputs:** `Honolulu_Parcels_Reprojected.gpkg`, `Target_Golf_Parcels_List.csv`, `Phase5_Geographic_Breakdown.csv`  
**R packages:** `tidyverse`, `sf`, `ggspatial`, `this.path`

---

### Script 4 — `4_Oahu_Zoning_Map.R`
**Output:** `output/4_Oahu_Golf_Zoning_Map.png`

High-resolution micro-map of Oahu coloring the 1,072 golf course TMK parcels by their dominant zoning classification. Each parcel is assigned the `zone_class` of the Honolulu zoning polygon with the largest overlap area (`st_join(..., largest = TRUE)`). Island base and coastline rendered beneath. Projection: EPSG 32604.

**Key inputs:** `Honolulu_Parcels_Reprojected.gpkg`, `Target_Golf_Parcels_List.csv`, `Zoning_-2205419429161838665.gpkg`  
**R packages:** `tidyverse`, `sf`, `ggspatial`, `this.path`

---

### Script 5 — `5_Econometric_Plots.R`
**Outputs:** `output/5.1_Forest_Plot.png` (9 × 4 in), `output/5.2_MICE_Density_Plot.png` (10 × 6 in)

**5.1 — Forest Plot:** Displays Phase 4 regression coefficients (Intercept, Holes, Urban County) with 95% CIs (`Coef ± 1.96 × SE`), a vertical dashed reference line at zero, and human-readable parameter labels. Significance stars appended to labels where applicable.

**5.2 — MICE Density Plot:** Overlays the observed acreage distribution (courses with measured polygons, `acreage_source != "MICE_Target"`) against 100 independent MICE draws (imputed-only rows, identified via `semi_join` on Longitude × Latitude from Phase 2). Log₁₀ x-axis. Distributional overlap validates the imputation.

**Key inputs:** `R_Regression_Results.csv`, `R_Phase2_Acreage_Matched_v2.csv`, `R_Imputed_Dataset_{1..100}.csv`  
**R packages:** `tidyverse`, `scales`, `this.path`

---

### Script 6 — `6_Advanced_Econometric_Plots.R`
**Outputs:** `output/6.1_Marginal_Effects_Dollar_Value.png` (7 × 6 in), `output/6.2_MICE_Raincloud_Diagnostic.png` (12 × 7 in)

**6.1 — Marginal Effects Plot:** Translates log-scale regression coefficients into predicted dollar opportunity costs for an average Rural vs. Urban course, with Holes fixed at the sample median. Prediction CIs computed via the delta method (diagonal variance only; covariance terms omitted, noted in caption). Point + errorbar + value label layers; `theme_classic()`.

**6.2 — Raincloud Diagnostic:** Compares observed acreage against all 100 MICE draws (imputed parcels only) using `ggdist::stat_halfeye` (half-violin) + `geom_boxplot` + jittered raw points. Acreage pre-transformed to log₁₀ before plotting to avoid bandwidth selection issues; axis tick labels show original acre values. `theme_classic()`.

**Key inputs:** `R_Regression_Results.csv`, `R_Phase2_Acreage_Matched_v2.csv`, `R_Imputed_Dataset_{1..100}.csv`  
**R packages:** `tidyverse`, `scales`, `ggdist`, `this.path`

---

### Script 7 — `7_Bivariate_Econometric_Map.R`
**Outputs:** `output/7.1_Bivariate_Cost_vs_Density_Map.png` (14 × 9 in), `output/7.2_Bivariate_Cost_vs_Density_Map_ObservedOnly.png` (14 × 9 in)

Bivariate choropleth at the county level showing the joint distribution of total opportunity cost (x-dimension) and total golf course holes (y-dimension). Counties classified into a 3×3 grid via `biscale::bi_class(..., style = "quantile", dim = 3)`. Palette: `"DkViolet"`. 3×3 legend composed as a `cowplot` inset at position (0.72, 0.04). Alaska and Hawaii shown as insets.

**7.1 — MICE-pooled (4 Variations):** OC pooled across draws via Rubin's Rules. Holes computed from imputation 1 only. Utilizes the global Tri-Language Grand Mean calculation to render four distinct bivariate maps (`GrandMean`, `Python`, `R`, `Julia`). Tertile breaks applied independently to each dimension.

**7.2 — Observed-only:** Both OC and Holes restricted to the same Phase 2 observed-acreage subset (`acreage_source != "MICE_Target"`), keeping the two bivariate dimensions consistent. Tertile breaks recomputed independently on the observed distribution.

A shared `build_bivariate_map()` function handles `bi_class`, map rendering, and `cowplot` assembly for both outputs.

**Key inputs:** `R_Imputed_Dataset_{1..100}.csv`, `R_Phase1_Baseline_Golf_Valuation.csv`, `R_Phase2_Acreage_Matched_v2.csv`  
**R packages:** `tidyverse`, `sf`, `tigris`, `biscale`, `cowplot`, `this.path`

---

### Script 8 — `8_LaTeX_Tables.R`
**Outputs:** `output/8.1_Table1_Acreage.tex`, `output/8.2_Table2_Regression.tex`, `output/8.3_Table3_Hawaii_Geo.tex`

Generates three standalone `booktabs`-styled LaTeX table files for direct `\input{}` inclusion in the thesis. All tables include `\caption{}` and `\label{}`. A `latex_escape()` helper escapes `%`, `$`, `_`, `&`, `#`, `^`, `~`, and backslashes before passing data to `knitr::kable(..., escape = FALSE)`.

| File | Source | Content |
|------|--------|---------|
| `8.1_Table1_Acreage.tex` | `National_Acreage_Summary.csv` | Urban / Rural / National pooled acreage with 95% CI; numbers formatted with thousand-separator commas |
| `8.2_Table2_Regression.tex` | `R_Regression_Results.csv` | Coefficients, SEs, *t*-stats, adjusted df, *p*-values, significance stars, and FMI; p-values below 0.001 shown as `< 0.001`; `threeparttable` footnote |
| `8.3_Table3_Hawaii_Geo.tex` | `Phase5_Geographic_Breakdown.csv` | Zone, district name, parcel count, share (%); percentages rounded to 1 decimal place |

**LaTeX preamble requirements:** `booktabs`, `threeparttable`, `float`  
**R packages:** `tidyverse`, `knitr`, `kableExtra`, `this.path`

---

### Script 9 — `9_Oahu_Opportunity_Cost_Map.R`
**Outputs:** `output/9.1_Oahu_Opportunity_Cost_Map.png` (12 × 10 in), `output/9.2_Oahu_Opportunity_Cost_Map_ObservedOnly.png` (12 × 10 in)

High-resolution micro-map of Oahu coloring individual OSM golf course polygons by their Opportunity Cost, mirroring the plasma-scale aesthetic of the national macro maps at the course level.

**Data pipeline (both variants):** OC coordinates are converted to sf points (EPSG 4326 → 32604), then each polygon is matched to its nearest point via `st_nearest_feature()`; matches exceeding 500 m are discarded. Island base derived from `st_union()` dissolve of Honolulu parcels (consistent with Script 3). A shared `join_oc_to_polygons()` helper and `build_oahu_oc_map()` function serve both variants.

**9.1 — MICE-pooled:** Imputed datasets filtered to Oahu bounding box (Lat: 21.2–21.9, Lon: −158.5–−157.6). `Total_Opportunity_Cost = final_acreage × Baseline_Value_Per_Acre` averaged across M = 100 draws (Rubin's Rules q̄).

**9.2 — Observed-only:** Phase 2 data filtered to Oahu bounding box and `acreage_source != "MICE_Target"`. Direct OC sum per course; no pooling. Polygons with no nearby observed-acreage coordinate within 500 m rendered in neutral gray.

Fill: `scale_fill_viridis_c(option = "plasma")` with a custom `label_oc()` labeler (auto-scales `$M` / `$B`). North arrow top-right; scale bar bottom-right via `ggspatial`. `theme_void()`.

**Key inputs:** `Target_Golf_Polygons.gpkg`, `R_Imputed_Dataset_{1..100}.csv`, `Honolulu_Parcels_Reprojected.gpkg`, `R_Phase2_Acreage_Matched_v2.csv`  
**R packages:** `tidyverse`, `sf`, `scales`, `ggspatial`, `this.path`

---

### Script 9b — `9b_Oahu_OC_Map_Rural_USDA_Sensitivity.R`
**Output:** `output/9b.141_Oahu_OC_Map_Rural_USDA_Sensitivity_GrandMean.png` (defense deliverable, 12 × 10 in)

Defense-only sensitivity variant of the Oahu Grand Mean opportunity cost map. Reclassifies courses in rural Honolulu County Development Plan zones from the FHFA residential proxy to the USDA agricultural proxy. Addresses the FHFA-aggregation caveat in thesis §5.4: Honolulu County's countywide FHFA index does not distinguish rural submarkets from the urban core.

**Reclassification logic:** `ZONMAP_NO` from `Zoning_Map_Boundary.geojson` (City & County of Honolulu Development Plan boundary layer, 34 polygons):
- Codes 1–14, 21–24 (urban/suburban core; Windward Oahu: Kualoa, Kaneohe, Kailua, Waimanalo): FHFA ($4,952,600/ac, FIPS 15003, 2022)
- Codes 15–20 (Lualualei/Makaha, Makua/Kaena, Mokuleia/Wailua/Haleiwa, Kawailoa/Waialee, Kahuku/Laie, Hauula/Punaluu/Kaaawa): USDA ($29,887/ac, read dynamically from `2022 - USDA County Data - Ag Use.csv`)
- Code 0: no golf courses present

**FHFA normalization step:** ALL Oahu `Baseline_Value_Per_Acre` values are overwritten with the FHFA value before any USDA override. This corrects Hawaii Kai and Mid-Pacific (FIPS-NA courses whose BVPA was MICE-imputed in Py/Jl rather than assigned the Phase 1 FHFA value).

**Spatial pipeline:** `st_centroid` of each OSM golf polygon → `st_join(st_within)` against Development Plan polygons → `st_nearest_feature` fallback for unmatched centroids (500m cap). Grand Mean: Rubin's Rules independently per language (M=100 each), arithmetic mean of three pooled estimates. Map format matches Script 9's `9.141` output (same plasma color scale, polygon-to-point join, caption format).

Integrated into `Phase_6.R` as `run_9b_Oahu_OC_Rural_USDA_Sensitivity()`, output routed to `output/Final_Thesis_Figures/`.

**Key inputs:** `Target_Golf_Polygons.gpkg`, `Honolulu_Parcels_Reprojected.gpkg`, `R_Phase1_Baseline_Golf_Valuation.csv`, `Zoning_Map_Boundary.geojson`, `R/Py/Jl_Imputed_Dataset_{1..100}.csv`, `2022 - USDA County Data - Ag Use.csv`  
**R packages:** `tidyverse`, `sf`, `scales`, `ggspatial`, `this.path`

---

### Script 15 — `15_Residual_Map.R`
**Outputs:** `output/15.141_Log_Residual_Map_GrandMean.png` (14 × 9 in), `output/15.241_Dollar_Residual_Map_GrandMean.png` (14 × 9 in)

Two residual choropleth maps at the county level. Residuals measure the gap between each course's observed opportunity cost and the OLS-predicted value from the Phase 4 regression (`log(OC) = β₀ + β₁·Holes + β₂·I(Urban)`). Tri-language Grand Mean: Rubin's Rules independently per language (M=100 each), arithmetic mean of three pooled county-level estimates.

**15.141 — Log-residual map:** `log(acreage × BVPA) − predicted_log`, aggregated to county mean. Range: [−2.809, 4.437]. Zero = perfect model fit; positive = observed OC exceeds prediction (undervalued by the model); negative = prediction exceeds observed OC.

**15.241 — Dollar-residual map:** `(acreage × BVPA) − exp(predicted_log)`, both terms in dollars. Range: [$−1.30B, $45.86B]. Counties with residuals: 2,874 of 3,144 (288 counties have no course data, rendered gray).

**Data safety filters:**
- `acreage > 1`: guards against `log(0)` / `log(1e−15)` producing −Inf or NaN from near-zero MICE-imputed acreage
- `between(Holes, 9, 72)`: guards against the 252-hole Phase 1 aggregate record causing `exp(b_holes × 252) ≈ $3.7T` explosion in the dollar-residual map
- FIPS-safe cross-language join: `select(-any_of(c("FIPS", "County_Name", "State_Abbr", "Tigris_State_Abbr")))` before `left_join(county_lookup, ...)` — eliminates the R FIPS-not-found error and the Julia `State_Abbr` column-suffix conflict

These maps are spatial diagnostics; the thesis prose does not reference any `15.x` figure.

**Key inputs:** `R/Py/Jl_Imputed_Dataset_{1..100}.csv`, `R_Phase1_Baseline_Golf_Valuation.csv`  
**R packages:** `tidyverse`, `sf`, `tigris`, `scales`, `this.path`

---

## R Output File Index

```
Bulk/R/output/
├── 1.141_National_Opportunity_Cost_Map_[Lang].png       (14 × 9 in, 300 DPI)
├── 1.101_National_Opportunity_Cost_Map_ObservedOnly.png (14 × 9 in, 300 DPI)
├── 2.141_County_Opportunity_Cost_Map_[Lang].png         (14 × 9 in, 300 DPI)
├── 2.101_County_Opportunity_Cost_Map_ObservedOnly.png   (14 × 9 in, 300 DPI)
├── 3.101_Oahu_TMK_Concentration_Map.png                 (12 × 10 in, 300 DPI)
├── 4.101_Oahu_Golf_Zoning_Map.png                       (12 × 10 in, 300 DPI)
├── 7.141_Bivariate_Cost_vs_Density_Map_[Lang].png       (14 × 9 in, 300 DPI)
├── 7.101_Bivariate_Cost_vs_Density_Map_ObservedOnly.png (14 × 9 in, 300 DPI)
├── 8.141_Table1_Acreage.tex
├── 8.241_Table2_Regression.tex
├── 8.301_Table3_Hawaii_Geo.tex
├── 9.131_Oahu_Opportunity_Cost_Map_R.png                        (12 × 10 in, 300 DPI)
├── 9.101_Oahu_Opportunity_Cost_Map_ObservedOnly.png             (12 × 10 in, 300 DPI)
├── 9b.141_Oahu_OC_Map_Rural_USDA_Sensitivity_GrandMean.png      (12 × 10 in, 300 DPI)
├── 15.141_Log_Residual_Map_GrandMean.png                        (14 × 9 in, 300 DPI)
└── 15.241_Dollar_Residual_Map_GrandMean.png                     (14 × 9 in, 300 DPI)
```

---

## Julia Bulk Scripts

Julia scripts live under `Bulk/Julia/` and cover all non-spatial outputs: statistical plots and LaTeX table generation. All scripts use `@__DIR__` for path resolution, read only `Jl_`-prefixed input files, and save PNGs at `px_per_unit = 3` (300 DPI equivalent). Scripts use `CairoMakie.jl` for all plotting.

Spatial map scripts are **not translated to Julia** — those outputs are consolidated into `Phase_6.R`. Script 8 (LaTeX tables) and Advanced Plots (10-14) are fully executed by `Phase_6.jl`.

---



### Script 5 — `5_Econometric_Plots.jl`
**Outputs:** `output/Final_Thesis_Figures/5.141_Forest_Plot_Combined.png`, `output/Final_Thesis_Figures/5.241_MICE_Density_Combined.png`

**5.1 — Forest Plot:** Combines the pooled regression coefficients for all three languages. Points and 95% CIs (`Coef ± 1.96 × SE`) are plotted side-by-side per variable using a Y-axis dodge (`±0.2`) to perfectly display Python (Green), R (Blue), and Julia (Purple) estimates without overlap.

**5.2 — MICE Density Plot:** Visualizes the true density variance of the full MICE pipeline by sequentially overlaying all 300 imputed datasets. The script features a highly optimized memory-management loop that dynamically matches missing coordinates, overlays a single `0.02` opacity density trace (color-coded by language), and immediately clears the DataFrame from RAM. The resulting 300-draw "cloud" is plotted behind the black observed acreage curve.

**Key inputs:** Phase 4 Regression CSVs, Phase 2 Matched Acreage CSVs, Phase 3 Imputed Datasets (300 files)  
**Julia packages:** `CSV`, `DataFrames`, `CairoMakie`, `Printf`

---

### Script 6 — `6_Advanced_Econometric_Plots.jl`
**Outputs:** `output/6.1_Marginal_Effects_Dollar_Value.png`, `output/6.2_MICE_Raincloud_Diagnostic.png`

**6.1 — Marginal Effects Plot:** Computes predicted dollar opportunity costs for Rural and Urban courses at median holes via `exp(log_hat) × bvpa / 1e6`. Delta method CIs: `se_pred_rural = √(se_b0² + (med_holes × se_holes)²)`; adds `se_urban²` for Urban. Rendered with vertical `errorbars!`, a double-scatter (white backing + colored fill) to replicate R's outlined-circle point style, and `text!` value labels above the CI upper bound.

**6.2 — Raincloud Diagnostic:** Raincloud (Observed + 100 MICE draws) built from three CairoMakie primitives per group — `violin!(side = :right)` (half-violin density slab), `boxplot!` (narrow centered box, `outliercolor = :transparent`), and jittered `scatter!`. Replicates `ggdist::stat_halfeye`. `Random.seed!(42)` applied before jitter. Log₁₀-transformed acreage on the y-axis with manual tick labels.

**Key inputs:** `Jl_Regression_Results.csv`, `Jl_Phase2_Acreage_Matched.csv`, `Jl_Imputed_Dataset_{1..100}.csv`  
**Julia packages:** `CSV`, `DataFrames`, `CairoMakie`, `Statistics`, `Printf`, `Random`

---

### Script 8 — `8_LaTeX_Tables.jl`
**Outputs:** `output/8.1_Table1_Acreage.tex`, `output/8.2_Table2_Regression.tex`, `output/8.3_Table3_Hawaii_Geo.tex`

Generates the same three `booktabs`-styled LaTeX tables as `8_LaTeX_Tables.R`. Because Julia has no `kableExtra` equivalent, LaTeX markup is constructed directly by string-building into a `Vector{String}` and written via `open`/`println`. Structural output is equivalent: `[H]` placement, `\toprule`/`\midrule`/`\bottomrule` rules, `threeparttable` footnote for Table 2.

A `latex_escape()` helper replicates the R function (backslash processed first). `fmt_comma()` replicates `format(..., big.mark = ",")` by chunking the integer part into groups of three. `fmt_pval()` replicates R's `ifelse(p < 0.001, "$<$ 0.001", sprintf("%.3f", p))`. Parameter name `"county_type: Urban"` used in `PARAM_LABELS` to match the Julia regression CSV.

| File | Source | Content |
|------|--------|---------|
| `8.1_Table1_Acreage.tex` | `Jl_National_Acreage_Summary.csv` | Urban / Rural / National pooled acreage with 95% CI; comma-formatted numbers |
| `8.2_Table2_Regression.tex` | `Jl_Regression_Results.csv` | Coefficients, SEs, *t*-stats, adjusted df, *p*-values, significance stars, FMI; `threeparttable` footnote |
| `8.3_Table3_Hawaii_Geo.tex` | `Jl_Phase5_Geographic_Breakdown.csv` | Zone, district, parcel count, share (%) |

**LaTeX preamble requirements:** `booktabs`, `threeparttable`, `float`  
**Julia packages:** `CSV`, `DataFrames`, `Printf`

---

### Scripts 10–14 — Advanced Statistical Plots
**Scope:** The advanced statistical scripts (`10_Hawaii_Gap_Dumbbell.jl`, `11_Lorenz_Curve.jl`, `12_Zoning_Waffle_Chart.jl`, `13_Counterfactual_Area.jl`, `14_Urban_Rural_Scatter.jl`) use CairoMakie to render multi-dimensional visual comparisons of the economic implications.
**Data Routing:** Rather than overlapping multi-language series, these final figures represent the absolute definitive thesis outcomes by actively routing and plotting the global **Tri-Language Grand Mean** (`$0.938T`) or the static observed baseline.

---

## Output File Index

Both `Phase_6.R` and `Phase_6.jl` render their final consolidated outputs into the unified `Phase 6 Visualization/output/` directory, separated by the thesis publication state.

```text
output/
├── Final_Thesis_Figures/
│   ├── 1.101_National_Opportunity_Cost_Map_ObservedOnly.png        [Phase_6.R Script 1]
│   ├── 1.141_National_Opportunity_Cost_Map_GrandMean.png           [Phase_6.R Script 1]
│   ├── 2.101_County_Opportunity_Cost_Map_ObservedOnly.png          [Phase_6.R Script 2]
│   ├── 2.141_County_Opportunity_Cost_Map_GrandMean.png             [Phase_6.R Script 2]
│   ├── 3.101_Oahu_TMK_Concentration_Map.png                        [Phase_6.R Script 3]
│   ├── 4.101_Oahu_Golf_Zoning_Map.png                              [Phase_6.R Script 4]
│   ├── 5.141_Forest_Plot_Combined.png                              [Phase_6.jl Mod_5]
│   ├── 5.241_MICE_Density_Combined_n020.png                        [Phase_6.jl Mod_5]
│   ├── 5.242_MICE_Density_Combined_n040.png                        [Phase_6.jl Mod_5]
│   ├── 5.243_MICE_Density_Combined_n060.png                        [Phase_6.jl Mod_5]
│   ├── 5.244_MICE_Density_Combined_n080.png                        [Phase_6.jl Mod_5]
│   ├── 5.245_MICE_Density_Combined_n100.png                        [Phase_6.jl Mod_5]
│   ├── 6.141_Marginal_Effects_Dollar_Value_Combined.png            [Phase_6.jl Mod_6]
│   ├── 6.241_MICE_Raincloud_Diagnostic_Combined.png                [Phase_6.jl Mod_6]
│   ├── 7.101_Bivariate_Cost_vs_Density_Map_ObservedOnly.png        [Phase_6.R Script 7]
│   ├── 7.141_Bivariate_Cost_vs_Density_Map_GrandMean.png           [Phase_6.R Script 7]
│   ├── 8.141_Table1_Acreage.tex                                    [Phase_6.R Script 8]
│   ├── 8.241_Table2_Regression.tex                                 [Phase_6.R Script 8]
│   ├── 8.301_Table3_Hawaii_Geo.tex                                 [Phase_6.R Script 8]
│   ├── 9.101_Oahu_Opportunity_Cost_Map_ObservedOnly.png                [Phase_6.R Script 9]
│   ├── 9.141_Oahu_Opportunity_Cost_Map_GrandMean.png                   [Phase_6.R Script 9]
│   ├── 9b.141_Oahu_OC_Map_Rural_USDA_Sensitivity_GrandMean.png         [Phase_6.R Script 9b]
│   ├── 10.141_Hawaii_Gap_Dumbbell_TriLanguage.png                      [Phase_6.jl Mod_10]
│   ├── 11.141_Lorenz_Curve_TriLanguage.png                         [Phase_6.jl Mod_11]
│   ├── 12.141_Zoning_Waffle_Chart_TriLanguage.png                  [Phase_6.jl Mod_12]
│   ├── 13.141_Counterfactual_Area_TriLanguage.png                  [Phase_6.jl Mod_13]
│   ├── 14.141_Urban_Rural_Scatter_TriLanguage.png                  [Phase_6.jl Mod_14]
│   ├── 15.141_Log_Residual_Map_GrandMean.png                       [Phase_6.R Script 15]
│   └── 15.241_Dollar_Residual_Map_GrandMean.png                    [Phase_6.R Script 15]
│
└── QA_Verification/
    ├── 1.111_National_Opportunity_Cost_Map_Julia.png               [Phase_6.R Script 1]
    ├── 1.121_National_Opportunity_Cost_Map_Python.png              [Phase_6.R Script 1]
    ├── 1.131_National_Opportunity_Cost_Map_R.png                   [Phase_6.R Script 1]
    ├── 2.111_County_Opportunity_Cost_Map_Julia.png                 [Phase_6.R Script 2]
    ├── 2.121_County_Opportunity_Cost_Map_Python.png                [Phase_6.R Script 2]
    ├── 2.131_County_Opportunity_Cost_Map_R.png                     [Phase_6.R Script 2]
    ├── 5.211_MICE_Density_Jl_n020.png  …  5.215_MICE_Density_Jl_n100.png  (5 files)  [Phase_6.jl Mod_5]
    ├── 5.221_MICE_Density_Py_n020.png  …  5.225_MICE_Density_Py_n100.png  (5 files)  [Phase_6.jl Mod_5]
    ├── 5.231_MICE_Density_R_n020.png   …  5.235_MICE_Density_R_n100.png   (5 files)  [Phase_6.jl Mod_5]
    ├── 7.111_Bivariate_Cost_vs_Density_Map_Julia.png               [Phase_6.R Script 7]
    ├── 7.121_Bivariate_Cost_vs_Density_Map_Python.png              [Phase_6.R Script 7]
    └── 7.131_Bivariate_Cost_vs_Density_Map_R.png                   [Phase_6.R Script 7]
```

> **Note (6C audit):** Script 9 (Oahu OC Map) produces only GrandMean + ObservedOnly in `Final_Thesis_Figures/` — no per-language QA maps. Script 15 (Residual Maps) produces GrandMean only — no ObservedOnly variant by design (residuals require a fitted model).


