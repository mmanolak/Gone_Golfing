# Phase 1–6 Master Script Review Checklist

**Purpose:** Systematic review of all main phase scripts for structural compliance,
methodological correctness, input/output integrity, and cross-language consistency.

**Execution rule:** One Part per Claude Code response. Mark each item `[x]` as
confirmed correct, or annotate inline with the issue found and fix applied.
Do not proceed to the next Part unless the user says to.

**Standards applied to all scripts** (per CLAUDE.md unless phase-specific exception noted):
- Four-section layout: `LIBRARIES`, `GLOBALS & PATHS`, `FUNCTIONS`, `EXECUTION`
- Two blank lines between top-level sections
- Relative path resolution only (no hardcoded absolute paths)
- Constants in `ALL_CAPS` in Section 2
- File existence checks before every input read
- Memory management (`rm()`/`gc()` in R; `df = nothing; GC.gc()` in Julia; `del df; gc.collect()` in Python) inside all dataset-loading loops
- `# [METHODOLOGY]` on all spatial joins, CRS transforms, spatial file reads, and Rubin's Rules pooling blocks
- No `log(acreage)` string in any label, comment, or output
- No synthetic or hardcoded data values; missing file = hard error

---

## Phase 1 — Parsing

**Purpose:** Parse raw OSM/Census golf course data, perform county-level spatial joins,
compute per-course baseline land valuations (Baseline_Value_Per_Acre).

**Expected outputs (per `Golfing Thesis Directory.txt`):**
- `Data/R/` → `R_Phase1_Baseline_Golf_Valuation.csv`, `R_Phase1_Parsed_Golf_Courses.csv`, `R_Phase1_Spatial_Joined_Golf_Courses.csv`, `R_Phase1_Valuation_Joined_Golf_Courses.csv`
- `Data/Julia/` → `Jl_Phase1_Baseline_Golf_Valuation.csv`, `Jl_Phase1_Parsed_Golf_Courses.csv`, `Jl_Phase1_Spatial_Joined_Golf_Courses.csv`
- `Data/python/` → `Py_Phase1_Baseline_Golf_Valuation.csv`, `Py_Phase1_Spatial_Joined_Golf_Courses.csv`, `Py_Phase1_Valuation_Joined_Golf_Courses.csv`

---

### Part 1A — `Phase_1.R`

**Pre-read:** Scan `Golfing Thesis Directory.txt` to confirm all raw input files Phase 1 reads actually exist in the directory listing.

**Structural**
- [x] Four-section layout present (`# === 1. LIBRARIES ===` through `# === 4. EXECUTION ===`)
- [x] Two blank lines between every top-level section
- [x] No `library()` calls outside Section 1
- [x] ALL_CAPS constants in Section 2
- [x] All paths resolved via `this.path::this.dir()` — zero hardcoded absolute paths

**Input / Output**
- [x] Every input file referenced in the script exists in the directory listing (`Original Data/` confirmed on disk)
- [x] All four `R_Phase1_*.csv` outputs written to `Data/R/` with correct filenames
- [x] `if (!file.exists(...)) stop(...)` guards every input read (loop at lines 58–60)

**Methodology**
- [x] Every `st_join()` call has `# [METHODOLOGY]` immediately above it (inline at line 108)
- [x] Every `st_transform()` call has `# [METHODOLOGY]` immediately above it — **FIXED**: added comment above `st_transform(4326)`
- [x] Every `st_read()` call has `# [METHODOLOGY]` immediately above it (N/A — no `st_read()` calls; tigris downloads dynamically)
- [x] Baseline valuation formula is consistent with thesis model (Urban → FHFA per-acre; Rural → USDA per-acre)
- [x] No `log(acreage)` string anywhere in the file
- [x] CRS used for spatial join documented in a comment — **FIXED**: EPSG 4326 now in code comment above `st_transform()`

**Memory**
- [x] Any loop over multiple datasets uses `rm(df); gc()` after extracting the needed value (N/A — no multi-dataset loop in Phase 1)
- [x] No bulk in-memory accumulation of datasets without disposal

**General**
- [x] No synthetic coordinates, fake FIPS codes, or hardcoded row data
- [x] Script would run to completion on any machine with the input files present

**Findings & Fixes:**

1. **Missing `# [METHODOLOGY]` on `st_transform()`** (was line 104–105): `counties(...) |> st_transform(4326)` had no methodology tag. Fixed — added `# [METHODOLOGY] CRS: EPSG 4326 (WGS 84)...` comment above the call. This also satisfies the "CRS documented in a comment" checklist item (the EPSG:4326 was only in a `cat()` print statement before).
2. **Observation (no fix):** `future`, `furrr`, and `parallelly` are loaded and `plan(multisession)` is configured but no `future_map`/`furrr` calls exist in Section 4. Unused parallel setup — adds overhead without benefit. Not a CLAUDE.md violation; flagged for user awareness.

---

### Part 1B — `Phase_1.jl`

**Structural**
- [x] Four-section layout present (lines 12/17/41/116)
- [x] Two blank lines between every top-level section
- [x] All logic wrapped in `main()` called at the bottom of the file (lines 118–387; call at lines 389–391)
- [x] ALL_CAPS constants in Section 2
- [x] All paths via `@__DIR__` — zero hardcoded absolute paths
- [x] No `Plasma.jl` anywhere in the file

**Input / Output**
- [x] Every input file referenced exists in the directory listing (all four inputs confirmed on disk)
- [x] All three `Jl_Phase1_*.csv` outputs written to `Data/Julia/` with correct filenames
- [x] `isfile(path) || error(...)` guards every input read (loop at lines 119–123)

**Methodology**
- [x] All spatial joins, CRS transforms, and spatial file reads marked `# [METHODOLOGY]` — **FIXED**: added tag above `GeoDataFrames.read(COUNTY_SHP)`; `Threads.@threads` join and `ArchGDAL.intersects()` were already tagged
- [x] Baseline valuation formula is equivalent to Phase_1.R (Urban → FHFA; Rural → USDA)
- [x] No `log(acreage)` string anywhere

**Memory**
- [x] `df = nothing; GC.gc()` in every dataset-loading loop (N/A — no multi-dataset loop in Phase 1)

**General**
- [x] No synthetic or hardcoded data values

**Findings & Fixes:**

1. **Missing `# [METHODOLOGY]` on `GeoDataFrames.read(COUNTY_SHP)`** (was line 193): Spatial file read had no methodology tag. Fixed — added `# [METHODOLOGY] Spatial read — county boundaries in EPSG 4326 (WGS 84)...` above the call.
2. **Observation:** `ENV["JULIA_NUM_THREADS"] = "24"` at line 19 is a runtime no-op; Julia thread count must be set at launch (`julia -t 24`). `Threads.@threads` loop still runs using whatever thread count Julia was started with. Not a CLAUDE.md violation.
3. **Observation:** `Downloads.download(COUNTY_CB, COUNTY_ZIP)` passes a local path where a URL is expected — would fail if ever executed. Dead code path since the SHP already exists in `Original Data/`. Not a CLAUDE.md violation.

---

### Part 1C — `Phase_1.py`

**Structural**
- [x] Four-section layout present — all four `# === N. ... ===` headers present (lines 12, 23, 42, 56) with two blank lines between each
- [x] All constants defined at top of file — `SCRIPT_DIR`, `ROOT_DIR`, `DATA_DIR`, `OUTPUT_DIR`, `RAW_CSV`, `USDA_IN`, `FHFA_IN`, `RUCC_URL`, `OUT_*` all ALL_CAPS in Section 2
- [x] All paths via `Path(__file__).parent` — `SCRIPT_DIR = Path(__file__).parent` at line 25; zero hardcoded absolute paths

**Input / Output**
- [x] Every input file referenced exists in the directory listing (`Golf Courses-USA.csv`, `2022 - USDA County Data - Ag Use.csv`, `2024 - FHFA June 20 Land Prices.xlsx` all confirmed on disk)
- [x] All three `Py_Phase1_*.csv` outputs written to `Data/python/` with correct filenames (`OUT_SPATIAL`, `OUT_VAL_JOIN`, `OUT_BASELINE` all match the `Py_Phase1_*.csv` pattern)
- [x] `if not path.exists(): raise FileNotFoundError(...)` guards every input (lines 59–61; `pathlib` `.exists()` is functionally equivalent to `os.path.isfile()`)

**Methodology**
- [x] Every `sjoin()` call marked `# [METHODOLOGY]` — inline at line 84 ✓
- [x] Every `to_crs()` call marked `# [METHODOLOGY]` — **FIXED**: added comment above `.to_crs("EPSG:4326")` at line 81
- [x] Every `gpd.read_file()` call marked `# [METHODOLOGY]` — N/A: no `gpd.read_file()` calls; county boundaries fetched via `pygris.counties()`
- [x] Baseline valuation formula equivalent to R and Julia (Urban → `FHFA_Res_Value_Per_Acre`; Rural → `USDA_Ag_Value_Per_Acre`; `np.nan` otherwise — lines 155–159)
- [x] No `log(acreage)` string anywhere in the file

**Memory**
- [x] `del df; gc.collect()` in every dataset-loading loop — N/A: no multi-dataset loop in Phase 1

**General**
- [x] No synthetic or hardcoded data values (note: `extract_holes()` returns `18` as default for unmatched regex — a domain assumption for standard 18-hole courses, not synthetic data)

**Findings & Fixes:**

1. **Missing `# [METHODOLOGY]` on `.to_crs("EPSG:4326")`** (line 81): `counties(...).to_crs("EPSG:4326")` had no methodology tag. Fixed — added `# [METHODOLOGY] CRS: EPSG 4326 (WGS 84)...` above the call. Consistent with fix applied to `Phase_1.R` `st_transform()` and `Phase_1.jl` `GeoDataFrames.read()`.
2. **Observation:** `extract_holes()` returns `18` as a hardcoded default when the `"(\d+) Holes?"` regex fails (line 53). R returns `NA` for the same case. This creates a minor cross-language inconsistency: Python records 18 holes for unparseable rows while R/Julia leave them as missing. Not a CLAUDE.md violation.
3. **Observation:** `as_is_col = "Land Value\n(Per Acre, As-Is)"` is a hardcoded column name literal inside `main()` (line 125). R uses `grep("Per Acre, As-Is", names(fhfa_df), value = TRUE)` for dynamic detection. If the Excel column header changes, the Python script silently fails to find the column. Not a CLAUDE.md violation.

---

### Part 1D — Phase 1 Cross-Language Consistency

- [x] All three scripts parse the same raw source files (`Golf Courses-USA.csv`, `2022 - USDA County Data - Ag Use.csv`, `2024 - FHFA June 20 Land Prices.xlsx`, RUCC URL) ✓
- [x] Core economic fields consistent across all three outputs: `FIPS`, `County_Name`, `Tigris_State_Abbr`, `USDA_Ag_Value_Per_Acre`, `FHFA_Res_Value_Per_Acre`, `RUCC_2023`, `county_type`, `Baseline_Value_Per_Acre` — all present and identically named ✓  
  **BUT** Python baseline CSV is missing `course_id`, `Address`, `City`, `State_Abbr`, `Zip_Code` (present in R and Julia) and retains `Details` (raw unparsed column, absent in R/Julia). Schema parity is partial. Flagged — see Findings.
- [x] Baseline valuation formula is mathematically identical: Urban → `FHFA_Res_Value_Per_Acre`; Rural → `USDA_Ag_Value_Per_Acre`; otherwise NA/NaN — confirmed in all three scripts ✓
- [x] CRS consistent: all three use EPSG 4326 for spatial join — confirmed in code review (Parts 1A–1C) ✓
- [x] Course counts in plausible range: R=16,292; Julia=16,292; Python=16,297 — the +5 Python rows are documented as attributable to `geopandas` spatial deduplication behavior ✓

**Findings:**

1. **Schema discrepancy — Python output missing 5 columns**: `course_id`, `Address`, `City`, `State_Abbr`, `Zip_Code` are in both R and Julia baseline CSVs but absent from Python's output. Python also retains the raw `Details` column not present in R/Julia. The core economic fields used for downstream modeling are all consistent; the gap is in administrative and identifier columns.

2. **`course_id` absent in Python (highest-risk gap)**: R and Julia assign a sequential `course_id` during deduplication. Python never creates this field. If Phase 2 or Phase 3 Python scripts join on `course_id`, this will raise a KeyError. Flag for verification in Part 2C — check whether `Phase_2.py` uses `course_id` for joining.

3. **`Course_Name` content differs across languages**: R strips the city/state suffix via `str_remove(Name_State, "-.*$")` (e.g., `"Seamountain Golf Course"`). Julia and Python carry the full raw string (e.g., `"Seamountain Golf Course-HI"`). Any downstream match on `Course_Name` between R and Julia/Python outputs would fail. Not an immediate issue if downstream joins use `FIPS` or `course_id`, but worth noting.

4. **Row counts**: R=16,292; Julia=16,292; Python=16,297. The +5 Python rows are already documented in `00 - Phase_1_Summary.md` and reflect `geopandas` retaining duplicate spatial join hits that `sf` drops. Consistent with prior analysis — no action needed.

---

## Phase 2 — Spatial Polygons and True Acreage

**Purpose:** Match golf courses to OSM polygon geometries; compute true measured acreage;
flag which courses need MICE imputation (`acreage_source == "MICE_Target"`) vs. have
directly measured acreage.

**Expected outputs (per directory):**
- `Data/R/` → `R_Phase2_Acreage_Matched_v2.csv`, `R_Phase2_OSM_Golf_Polygons.gpkg`
- `Data/Julia/` → `Jl_Phase2_Acreage_Matched.csv`, `Jl_Phase2_OSM_Golf_Polygons.gpkg`
- `Data/python/` → `Py_Phase2_Acreage_Matched.csv`, `Py_Phase2_OSM_Golf_Polygons.gpkg`

---

### Part 2A — `Phase_2.R`

**Structural**
- [x] Four-section layout present with correct numbered headers (lines 31, 45, 82, 89)
- [x] Two blank lines between every top-level section — confirmed at all three section boundaries
- [x] No `library()` calls outside Section 1 — none found in Sections 2–4
- [x] ALL_CAPS constants in Section 2; `this.path::this.dir()` paths — `SCRIPT_DIR <- this.path::this.dir()` at line 71; all constants (`TARGET_CRS`, `MAX_NEAREST_M`, `MIN_ACRES`, `MAX_ACRES`, `SQ_M_PER_ACRE`, `SQ_FT_PER_ACRE`, `ALL_STATES`, `PBF_FILE`, `PY_GPKG`, `OSM_GPKG_OUT`, `PHASE1_CSV`, `OUT_CSV`) in ALL_CAPS ✓

**Input / Output**
- [x] Phase 1 `R_` output files used as inputs exist in `Data/R/` — `PHASE1_CSV` resolves to `Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv`, confirmed in directory listing ✓
- [x] Any shared raw GPKGs read are in the directory listing — `PY_GPKG` (`Py_Phase2_OSM_Golf_Polygons.gpkg`) confirmed in directory listing; `PBF_FILE` (`us-260413.osm.pbf`) not in text listing but handled via graceful try/catch fallback — see Observation 1
- [x] `R_Phase2_Acreage_Matched_v2.csv` written to `Data/R/` — `OUT_CSV` at line 79 ✓
- [x] `R_Phase2_OSM_Golf_Polygons.gpkg` written to `Data/R/` — `OSM_GPKG_OUT` at line 76 ✓
- [x] File existence checks guard all inputs — `PHASE1_CSV` guarded by `stop()` at lines 106–108; Python GPKG guarded by `stop()` at lines 151–156 if both PBF and GPKG unavailable ✓

**Methodology**
- [x] `st_join()`, `st_transform()`, `st_read()` all marked `# [METHODOLOGY]` — both `st_read()` calls (lines 130, 160); all three `st_transform()` calls (lines 179, 260, 401); both `st_join()` calls (lines 269, 420); `st_write()` (line 212); `st_as_sf()` (lines 255, 413); `st_area()` calls (lines 180, 245, 402) all tagged ✓
- [x] `acreage_source` flag correctly distinguishes directly measured courses from MICE targets — "OSM" (lines 319–321), "Tigris" (line 439), "MICE_Target" (line 456); consistent with header comment at line 17 ✓
- [x] Acreage computed from polygon geometry area (not estimated or hardcoded) — `st_area()` used for both OSM and Tigris acreage; final_acreage = `coalesce(osm_acres, tigris_acres)` ✓
- [x] Match distance threshold (if applicable) documented in a comment — `MAX_NEAREST_M <- 500` defined as named constant in Section 2; variable name is self-documenting (see Observation 2 for methodological basis)
- [x] CRS of output GPKG documented — `# [METHODOLOGY] EPSG:5070 — equal-area CRS` on all `st_transform()` calls; output GPKG written in EPSG:5070 ✓

**Memory**
- [x] `rm(df); gc()` in any loops — `rm(osm_chunks, osm_processed); gc(full = TRUE)` after Step 0 (lines 215–216) ✓; CLAUDE.md memory rule targets dataset-loading loops only; line 337 `rm()` is post-join cleanup (not a loop) — see Observation 3
- [x] No synthetic data — all acreage from `st_area()` geometry; no hardcoded row values ✓

**Findings & Fixes:**

No CLAUDE.md violations found. No fixes applied.

1. **Observation — PBF path documentation mismatch**: `Phase 2 Summary` header states the 11 GB PBF is read from `00 - Data Sources/Original Data - Backup/`; but `PBF_FILE` in the script points to `00 - Data Sources/Original Data/` (line 74). If the PBF resides only in the backup path, the primary PBF read silently fails and the script falls back to the Python GPKG — which is handled correctly, but the documentation is misaligned with the script path.

2. **Observation — 500 m threshold lacks methodological comment**: `MAX_NEAREST_M <- 500` defines the nearest-neighbour cutoff distance but has no inline comment explaining the methodological basis for 500 m. The constant name is self-documenting; no CLAUDE.md violation.

3. **Observation — `rm()` without `gc()` at line 337**: Large spatial objects (`courses_sf`, `osm_golf_sf`, `intersects_result`, `intersects_df`) are freed via `rm()` but no `gc()` call follows. CLAUDE.md's memory rule specifically applies to dataset-loading loops; this is post-join cleanup outside a loop, so not a strict violation. However, releasing ~several GB of spatial objects without a GC hint is a best practice gap.

---

### Part 2B — `Phase_2.jl`

**Structural**
- [x] Four-section layout; all logic in `main()` — headers at lines 21, 26, 41, 66; all pipeline code inside `main()` (line 68); `if abspath(PROGRAM_FILE) == @__FILE__ main() end` guard at lines 257–259 ✓
- [x] Two blank lines; `@__DIR__` paths; ALL_CAPS constants — `const SCRIPT_DIR = @__DIR__` at line 28; all nine constants (`PY_GPKG`, `OSM_GPKG_OUT`, `PHASE1_CSV`, `OUT_CSV`, `MIN_ACRES`, `MAX_ACRES`, `SQ_M_PER_ACRE`, `MAX_NEAREST_M`) ALL_CAPS; two blank lines confirmed at all three section boundaries ✓
- [x] No `Plasma.jl` — no reference anywhere in the 259-line file ✓

**Input / Output**
- [x] Phase 1 `Jl_` outputs used as inputs exist in `Data/Julia/` — `PHASE1_CSV` resolves to `Phase 1 Parsing/Data/Julia/Jl_Phase1_Baseline_Golf_Valuation.csv`; correct `Jl_` prefix ✓
- [x] Shared raw GPKGs exist in directory listing — `PY_GPKG` (`Data/Python/Py_Phase2_OSM_Golf_Polygons.gpkg`) confirmed in directory; this is the Python Step 1 output consumed by Julia ✓
- [x] `Jl_Phase2_Acreage_Matched.csv` + `Jl_Phase2_OSM_Golf_Polygons.gpkg` written to `Data/Julia/` — `OSM_GPKG_OUT` at line 30 and `OUT_CSV` at line 33 both resolve to `Data/Julia/` ✓
- [x] `isfile` checks on all inputs — `isfile(PY_GPKG) || error(...)` at line 89; `isfile(PHASE1_CSV) || error(...)` at line 141 ✓

**Methodology**
- [x] Spatial joins, CRS transforms, spatial reads marked `# [METHODOLOGY]` — `GeoDataFrames.read(PY_GPKG)` (line 93); area loop `Threads.@threads` (line 99); `GeoDataFrames.write(...)` (line 127); `ArchGDAL.createcoordtrans(...)` (line 157); intersect loop (line 176); nearest-neighbor block (line 193) — all tagged ✓
- [x] `acreage_source` flag logic equivalent to Phase_2.R — **FIXED**: `acreage_source` column was entirely absent from the Julia output. Added `courses_df.acreage_source = ifelse.(ismissing.(courses_df.osm_acreage), "MICE_Target", "OSM")` after line 214. Note: Tigris tier is R-only; "Tigris" category will never appear in Julia output (expected).
- [x] Match distance threshold consistent with R script — `const MAX_NEAREST_M = 500.0` at line 38; matches `MAX_NEAREST_M <- 500` in Phase_2.R ✓

**Memory**
- [x] `df = nothing; GC.gc()` in loops — N/A: no multi-dataset loading loop in Phase 2 Julia; `Threads.@threads` loops are parallel computation loops, not sequential dataset-accumulation loops. CLAUDE.md memory rule targets the 300-dataset imputation loop pattern in Phases 3–6.

**Findings & Fixes:**

1. **Missing `acreage_source` column** — **FIXED**: The Julia script computed `osm_acreage` but never assigned the `acreage_source` flag. The output CSV written by Phase_2.jl had no `acreage_source` column, making Phase 3 Julia unable to identify MICE imputation targets by this field. Fix: added `courses_df.acreage_source = ifelse.(ismissing.(courses_df.osm_acreage), "MICE_Target", "OSM")` immediately after `courses_df.osm_acreage = acreage_results`. Two-value schema ("OSM" | "MICE_Target") vs R's three-value schema ("OSM" | "Tigris" | "MICE_Target") — the absence of "Tigris" is expected since the `tigris` landmarks API is R-only.

2. **Observation — no Tigris second tier**: Phase_2.R runs a full three-tier pipeline (OSM → Tigris landmarks → MICE_Target). Phase_2.jl is single-tier (OSM intersect + 500m nearest → MICE_Target). Tigris cannot be replicated in Julia (R-only package). This is a structural asymmetry between the R and Julia Phase 2 pipelines; the Julia MICE-target count will be higher than R's as a result.

---

### Part 2C — `Phase_2.py`

**Structural**
- [ ] Four-section layout; relative `__file__` paths; top-level constants

**Input / Output**
- [ ] Phase 1 `Py_` outputs used as inputs exist in `Data/python/`
- [ ] Shared raw GPKGs exist
- [ ] `Py_Phase2_Acreage_Matched.csv` + `Py_Phase2_OSM_Golf_Polygons.gpkg` written to `Data/python/`
- [ ] File existence checks on all inputs

**Methodology**
- [ ] `sjoin()`, `to_crs()`, `gpd.read_file()` marked `# [METHODOLOGY]`
- [ ] `acreage_source` flag logic consistent with R and Julia
- [ ] Match distance threshold consistent

**Memory**
- [ ] `del df; gc.collect()` in loops

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 2D — Phase 2 Cross-Language Consistency

- [ ] `acreage_source` flag categories are identical across all three scripts
- [ ] Polygon match distance threshold is the same across all three languages
- [ ] MICE-target course count is consistent (or explainable) across language outputs
- [ ] Column schema of `Acreage_Matched` CSV is consistent across languages (same field names for shared fields)
- [ ] GPKGs from all three languages use the same CRS

**Findings:**
_(document any cross-language discrepancies here)_

---

## Phase 3 — Economic Merge and MICE Imputation

**Purpose:** Merge Phase 2 acreage data with economic land value estimates; impute missing
acreage via MICE (M = 100 per language); write 100 imputed datasets per language plus
Rubin's Rules summary CSVs.

**Expected outputs (per directory):**
- `Data/R/` → `R_Imputed_Dataset_{1..100}.csv`, `R_National_Acreage_Summary.csv`, `R_Rubins_Rules_Summary.csv`
- `Data/Julia/` → `Jl_Imputed_Dataset_{1..100}.csv`, `Jl_National_Acreage_Summary.csv`, `Jl_Rubins_Rules_Summary.csv`
- `Data/python/` → `Py_Imputed_Dataset_{1..100}.csv`, `Py_National_Acreage_Summary.csv`, `Py_Rubins_Rules_Summary.csv`

**Note:** Read `00 - Phase3_Summary.md` at the start of Part 3A for full context.

---

### Part 3A — `Phase_3.R`

**Structural**
- [ ] Four-section layout present with correct numbered headers
- [ ] Two blank lines between every top-level section
- [ ] No `library()` calls outside Section 1
- [ ] ALL_CAPS constants; `this.path::this.dir()` paths

**Input / Output**
- [ ] Phase 2 `R_Phase2_Acreage_Matched_v2.csv` and any economic data inputs exist
- [ ] All 100 `R_Imputed_Dataset_{1..100}.csv` written to `Data/R/`
- [ ] `R_National_Acreage_Summary.csv` and `R_Rubins_Rules_Summary.csv` written to `Data/R/`
- [ ] File existence checks guard all inputs

**MICE Methodology**
- [ ] `# [METHODOLOGY]` immediately above the Rubin's Rules pooling block
- [ ] M = 100 (not 99, not 101 — verify the loop range)
- [ ] Random seed set, value documented in a comment
- [ ] Imputation model uses only legitimate predictors — no leakage from the dependent variable
- [ ] `acreage_source == "MICE_Target"` rows are the imputation targets; observed rows are not overwritten
- [ ] Each imputed dataset contains `Baseline_Value_Per_Acre` column for downstream OC calculation
- [ ] All 100 imputed datasets have identical column schemas

**Memory**
- [ ] Dataset-writing loop uses `rm(df); gc()` after each dataset is written
- [ ] All 100 datasets are NOT held in memory simultaneously at any point

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 3B — `Phase_3.jl`

**Structural**
- [ ] Four-section layout; all logic in `main()`
- [ ] Two blank lines; `@__DIR__` paths; ALL_CAPS constants
- [ ] No `Plasma.jl`

**Input / Output**
- [ ] Phase 2 `Jl_Phase2_Acreage_Matched.csv` exists
- [ ] All 100 `Jl_Imputed_Dataset_{1..100}.csv` written to `Data/Julia/`
- [ ] `Jl_National_Acreage_Summary.csv` + `Jl_Rubins_Rules_Summary.csv` written to `Data/Julia/`
- [ ] `isfile` checks on all inputs

**MICE Methodology**
- [ ] `# [METHODOLOGY]` on Rubin's Rules block
- [ ] M = 100; random seed documented
- [ ] No data leakage in imputation model
- [ ] `Baseline_Value_Per_Acre` present in all 100 imputed datasets
- [ ] `df = nothing; GC.gc()` after each dataset is written

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 3C — `Phase_3.py`

**Structural**
- [ ] Four-section layout; relative `__file__` paths; top-level constants

**Input / Output**
- [ ] Phase 2 `Py_Phase2_Acreage_Matched.csv` exists
- [ ] All 100 `Py_Imputed_Dataset_{1..100}.csv` written to `Data/python/`
- [ ] `Py_National_Acreage_Summary.csv` + `Py_Rubins_Rules_Summary.csv` written to `Data/python/`
- [ ] File existence checks on all inputs

**MICE Methodology**
- [ ] `# [METHODOLOGY]` on Rubin's Rules block
- [ ] M = 100; random seed documented
- [ ] No data leakage in imputation model
- [ ] `Baseline_Value_Per_Acre` present in all 100 imputed datasets
- [ ] `del df; gc.collect()` after each dataset is written

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 3D — Phase 3 Cross-Language Consistency

- [ ] All three scripts target the same set of courses for imputation (same `acreage_source == "MICE_Target"` logic)
- [ ] Imputation predictor variable set is equivalent across languages
- [ ] M = 100 confirmed for all three languages
- [ ] `Baseline_Value_Per_Acre` column present and populated in all 300 imputed datasets (100 × 3)
- [ ] `Rubins_Rules_Summary` CSVs report the same parameter names (Intercept, Holes, Urban County) for downstream Phase 4 cross-check
- [ ] National acreage totals in summary CSVs are in the same plausible range across languages

**Findings:**
_(document any cross-language discrepancies here)_

---

## Phase 4 — Econometric Modeling

**Purpose:** Run OLS regression of `log(Opportunity_Cost)` on Holes and Urban County indicator
across all M = 100 imputed datasets per language; apply Rubin's Rules independently per language
group; write pooled regression result CSVs and model objects.

**Expected outputs (per directory):**
- `Data/R/` → `R_Regression_Results.csv`, `R_model_results.rds`
- `Data/Julia/` → `Jl_Regression_Results.csv`, `Jl_model_results.jls`
- `Data/python/` → `Py_Regression_Results.csv`, `Py_model_results.pkl`

**Note:** Read `00 - Phase4_Summary.md` at the start of Part 4A for full context.

---

### Part 4A — `Phase_4.R`

**Structural**
- [ ] Four-section layout present with correct numbered headers
- [ ] Two blank lines between every top-level section
- [ ] No `library()` calls outside Section 1
- [ ] ALL_CAPS constants; `this.path::this.dir()` paths

**Input / Output**
- [ ] All 100 `R_Imputed_Dataset_{1..100}.csv` referenced via correct relative path to `Data/R/`
- [ ] `R_Regression_Results.csv` written to `Data/R/`
- [ ] `R_model_results.rds` written to `Data/R/`
- [ ] File existence check on at least one sentinel input (e.g., dataset 1) before loop starts

**Econometric Methodology**
- [ ] Dependent variable is `log(Opportunity_Cost)` — confirm formula or column name in code
- [ ] No `log(acreage)` string anywhere in the file
- [ ] Independent variables: Holes, Urban County indicator (confirm variable names match imputed dataset columns)
- [ ] `# [METHODOLOGY]` immediately above Rubin's Rules pooling block
- [ ] Pooling uses M = 100 coefficient vectors (not a single merged dataset)
- [ ] Between-imputation variance (`B`) computed correctly: variance of the M coefficient estimates
- [ ] Within-imputation variance (`W`) computed correctly: mean of M squared standard errors
- [ ] Total variance `T = W + (1 + 1/M) × B`
- [ ] FMI (fraction of missing information) computed and stored in output CSV

**Memory**
- [ ] Dataset-loading loop uses `rm(df); gc()` after fitting each model and extracting coefficients
- [ ] Coefficients extracted to a list/vector before dataset is dropped

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 4B — `Phase_4.jl`

**Structural**
- [ ] Four-section layout; all logic in `main()`
- [ ] Two blank lines; `@__DIR__` paths; ALL_CAPS constants
- [ ] No `Plasma.jl`

**Input / Output**
- [ ] All 100 `Jl_Imputed_Dataset_{1..100}.csv` referenced via correct relative path to `Data/Julia/`
- [ ] `Jl_Regression_Results.csv` + `Jl_model_results.jls` written to `Data/Julia/`
- [ ] `isfile` check before loop starts

**Econometric Methodology**
- [ ] Dependent variable is `log(Opportunity_Cost)`; no `log(acreage)` anywhere
- [ ] Same independent variable set as Phase_4.R
- [ ] `# [METHODOLOGY]` on Rubin's Rules block
- [ ] M = 100; B, W, T variance components correct; FMI computed
- [ ] `df = nothing; GC.gc()` after each model fit

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 4C — `Phase_4.py`

**Structural**
- [ ] Four-section layout; relative `__file__` paths; top-level constants

**Input / Output**
- [ ] All 100 `Py_Imputed_Dataset_{1..100}.csv` referenced via correct relative path to `Data/python/`
- [ ] `Py_Regression_Results.csv` + `Py_model_results.pkl` written to `Data/python/`
- [ ] File existence check before loop starts

**Econometric Methodology**
- [ ] Dependent variable is `log(Opportunity_Cost)`; no `log(acreage)` anywhere
- [ ] Same independent variable set as R and Julia
- [ ] `# [METHODOLOGY]` on Rubin's Rules block
- [ ] M = 100; B, W, T variance components correct; FMI computed
- [ ] `del df; gc.collect()` after each model fit

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 4D — Phase 4 Cross-Language Consistency

- [ ] All three regression CSVs use the same parameter names (Intercept, Holes, Urban County)
- [ ] Coefficient point estimates are in the same plausible range across languages (no order-of-magnitude divergence)
- [ ] Standard errors and FMI columns present in all three result CSVs
- [ ] `p_value` column is numeric (not a string) in all three CSVs
- [ ] The three β̂ estimates for each parameter are the inputs to Phase 6's Grand Mean computation — confirm they are plausible basis for `$0.944T`

**Findings:**
_(document any cross-language discrepancies here)_

---

## Phase 5 — Hawaii Micro-Case Study

**Purpose:** Isolate Oahu-specific golf courses; perform district and zoning breakdowns;
compute Hawaii-specific opportunity cost estimates; produce geographic breakdown tables
used by Phase 6 Scripts 3, 4, and 9.

**Expected outputs (per directory):**
- `Data/R/` → `Phase5_Geographic_Breakdown.csv`, `Phase5_Oahu_Comparison.csv`, `Phase5_Step6_Zone_Golf_Penetration.csv`, `Phase5_Step6_Zoning_Percentages.csv`, `Honolulu_Parcels_Reprojected.gpkg`, `Target_Golf_Parcels_List.csv`, `Target_Golf_Polygons.gpkg`
- `Data/Julia/` → `Jl_Phase5_Geographic_Breakdown.csv`, `Jl_Phase5_Oahu_Comparison.csv`, `Jl_Phase5_Step6_Zone_Golf_Penetration.csv`, `Jl_Phase5_Step6_Zoning_Percentages.csv`
- `Data/python/` → `Py_Phase5_Oahu_Comparison.csv`, `Py_Phase5_Step5_Geographic_Breakdown.csv`, `Py_Phase5_Step6_Zone_Golf_Penetration.csv`, `Py_Phase5_Step6_Zoning_Percentages.csv`

---

### Part 5A — `Phase_5.R`

**Structural**
- [ ] Four-section layout present with correct numbered headers
- [ ] Two blank lines between every top-level section
- [ ] No `library()` calls outside Section 1
- [ ] ALL_CAPS constants; `this.path::this.dir()` paths

**Input / Output**
- [ ] All Phase 2/3 `R_` inputs and any raw GPKGs exist per directory listing
- [ ] All seven `Data/R/` output files written with correct filenames
- [ ] File existence checks guard all inputs

**Methodology**
- [ ] `st_join()`, `st_transform()`, `st_read()` all marked `# [METHODOLOGY]`
- [ ] Oahu isolation uses consistent filter (Honolulu County FIPS = 15003, or equivalent bounding box)
- [ ] Zoning join uses largest-overlap rule (`st_join(..., largest = TRUE)`) — this feeds Script 4 in Phase 6
- [ ] `Honolulu_Parcels_Reprojected.gpkg` written in EPSG 32604 (UTM Zone 4N)
- [ ] The 37 Ewa District (Zone 9) courses referenced in Phase 6 Summary are traceable to this script
- [ ] No `log(acreage)` string anywhere

**Memory**
- [ ] `rm(df); gc()` in any dataset loops

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 5B — `Phase_5.jl`

**Structural**
- [ ] Four-section layout; all logic in `main()`
- [ ] Two blank lines; `@__DIR__` paths; ALL_CAPS constants
- [ ] No `Plasma.jl`

**Input / Output**
- [ ] Phase 2/3 `Jl_` inputs exist in `Data/Julia/`
- [ ] All four `Jl_Phase5_*.csv` outputs written to `Data/Julia/`
- [ ] `isfile` checks on all inputs

**Methodology**
- [ ] Spatial joins, CRS transforms, spatial reads marked `# [METHODOLOGY]`
- [ ] Oahu filter consistent with Phase_5.R
- [ ] Zoning join methodology consistent with R

**Memory**
- [ ] `df = nothing; GC.gc()` in loops

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 5C — `Phase_5.py`

**Structural**
- [ ] Four-section layout; relative `__file__` paths; top-level constants

**Input / Output**
- [ ] Phase 2/3 `Py_` inputs exist in `Data/python/`
- [ ] All four `Py_Phase5_*.csv` outputs written to `Data/python/`
- [ ] File existence checks on all inputs

**Methodology**
- [ ] `sjoin()`, `to_crs()`, `gpd.read_file()` marked `# [METHODOLOGY]`
- [ ] Oahu filter consistent with R and Julia
- [ ] Zoning classification categories consistent across languages

**Memory**
- [ ] `del df; gc.collect()` in loops

**Findings & Fixes:**
_(document any issues and fixes applied here)_

---

### Part 5D — Phase 5 Cross-Language Consistency

- [ ] Oahu golf course count is consistent across all three language outputs (or any divergence is explained)
- [ ] The 37-course Ewa District (Zone 9) count referenced in Phase 6 Summary is confirmed by Phase_5.R output
- [ ] District/zone classification categories are identical across language outputs
- [ ] `Phase5_Geographic_Breakdown.csv` column schema is equivalent across languages
- [ ] `Target_Golf_Polygons.gpkg` (R-only) is the canonical polygon source correctly consumed by Phase 6 Script 9

**Findings:**
_(document any cross-language discrepancies here)_

---

## Phase 6 — Visualization (Final Verification Pass)

**Purpose:** Confirm the two master scripts remain structurally and methodologically correct
after the Point 26 (Phase_6.jl) and Point 27 (Phase_6.R) audit fixes.
This is a targeted spot-check, not a full re-read.

---

### Part 6A — `Phase_6.R` (Spot-Check)

Verify only the specific items that were fixed or confirmed during the Point 27 audit:

- [ ] `# === 1. LIBRARIES ===` through `# === 4. EXECUTION ===` all present with two blank lines between
- [ ] `compute_grand_means()` and all seven `run_X_()` functions are in Section 3
- [ ] `grand_means <- compute_grand_means()` is in Section 4 (not between function defs)
- [ ] `plan(sequential)` is in Section 4
- [ ] Script 1 Step 5 coverage calc references `grand_means$state$GrandMean$pooled_opp_cost` (not stale loop var)
- [ ] Script 2 Step 5 coverage calc references `grand_means$county$GrandMean$pooled_opp_cost` (not stale loop var)
- [ ] `# [METHODOLOGY]` present above `pool_oahu_oc()` Rubin's q_bar block (Script 9)
- [ ] No `log(acreage)` string anywhere in the file (grep confirm)
- [ ] All `library()` calls are in Section 1 only (grep confirm)

**Findings:**
_(note any regressions from Point 27 fixes)_

---

### Part 6B — `Phase_6.jl` (Spot-Check)

Verify only the specific items fixed during the Point 26 audit:

- [ ] `python` (lowercase) in all Phase 3/4 directory path strings — confirm at the 7 fixed locations (Mod_5 line ~143, Mod_6 ~264, Mod_10 ~306, Mod_10 ~322, Mod_11 ~639, Mod_12 ~970, Mod_13 ~1242)
- [ ] No `[METHODOLOGY] Spatial read` comment above plain `CSV.read()` calls (2 removed in Mod_11 ~1151, Mod_12 ~1428)
- [ ] `function main() ... end` wrapper present with `main()` call at the bottom of the file
- [ ] No `Plasma.jl` reference anywhere in the file (grep confirm)
- [ ] No `log(acreage)` string anywhere (grep confirm)
- [ ] Rubin's Rules pooled independently per language (M=100 each) — grep for any single M=300 pool

**Findings:**
_(note any regressions from Point 26 fixes)_

---

### Part 6C — Phase 6 Integration Check

- [ ] `Phase_6.R` `compute_grand_means()` reads from `Data/Julia/`, `Data/python/`, and `Data/R/` — paths resolve correctly relative to script location
- [ ] `Phase_6.jl` reads from `Data/Julia/` only (no cross-language CSV reads in Julia master)
- [ ] Grand Mean ($0.944T) plausibility: sum from `compute_grand_means()` is consistent with Phase 4 regression results
- [ ] `output/Final_Thesis_Figures/` contains GrandMean and ObservedOnly variants for all spatial scripts (Scripts 1, 2, 7, 9, 15)
- [ ] `output/QA_Verification/` contains per-language variants (Julia, Python, R) for Scripts 1, 2, 7, 9
- [ ] No output filename produced by `Phase_6.R` conflicts with any output filename produced by `Phase_6.jl`
- [ ] Phase 6 output naming follows `1.234` convention throughout both scripts

**Findings:**
_(document any integration issues here)_

---

## Summary Tracker

| Part  | Script             | Status  | Issues Found |
|-------|--------------------|---------|--------------|
| 1A    | Phase_1.R          | `[x]`   | 1 fix: `[METHODOLOGY]` added to `st_transform()`; 1 obs: unused parallel libs |
| 1B    | Phase_1.jl         | `[x]`   | 1 fix: `[METHODOLOGY]` added to `GeoDataFrames.read()`; 2 obs: runtime thread env var no-op, dead Downloads path |
| 1C    | Phase_1.py         | `[x]`   | 1 fix: `[METHODOLOGY]` added to `.to_crs()`; 2 obs: `extract_holes()` returns `18` default (R returns NA), `as_is_col` hardcoded string vs R's dynamic grep |
| 1D    | Phase 1 Cross-Lang | `[x]`   | Core economic fields consistent; 3 discrepancies: Python missing `course_id`/address cols + retains `Details`; `Course_Name` content differs R vs Jl/Py; +5 Python rows (known) |
| 2A    | Phase_2.R          | `[x]`   | No fixes; 3 obs: PBF path mismatch vs. summary doc, 500m threshold undocumented, `rm()` without `gc()` post-join |
| 2B    | Phase_2.jl         | `[x]`   | 1 fix: `acreage_source` column added ("OSM"\|"MICE_Target"); 1 obs: no Tigris tier (R-only package, expected) |
| 2C    | Phase_2.py         | `[ ]`   |              |
| 2D    | Phase 2 Cross-Lang | `[ ]`   |              |
| 3A    | Phase_3.R          | `[ ]`   |              |
| 3B    | Phase_3.jl         | `[ ]`   |              |
| 3C    | Phase_3.py         | `[ ]`   |              |
| 3D    | Phase 3 Cross-Lang | `[ ]`   |              |
| 4A    | Phase_4.R          | `[ ]`   |              |
| 4B    | Phase_4.jl         | `[ ]`   |              |
| 4C    | Phase_4.py         | `[ ]`   |              |
| 4D    | Phase 4 Cross-Lang | `[ ]`   |              |
| 5A    | Phase_5.R          | `[ ]`   |              |
| 5B    | Phase_5.jl         | `[ ]`   |              |
| 5C    | Phase_5.py         | `[ ]`   |              |
| 5D    | Phase 5 Cross-Lang | `[ ]`   |              |
| 6A    | Phase_6.R          | `[ ]`   |              |
| 6B    | Phase_6.jl         | `[ ]`   |              |
| 6C    | Phase 6 Integration| `[ ]`   |              |
