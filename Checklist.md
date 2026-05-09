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
- [x] Four-section layout; relative `__file__` paths; top-level constants — headers at lines 12, 22, 38, 237; `SCRIPT_DIR = Path(__file__).parent` at line 24; all constants ALL_CAPS; two blank lines at all three section boundaries ✓

**Input / Output**
- [x] Phase 1 `Py_` outputs used as inputs exist in `Data/python/` — `PHASE1_CSV` resolves to `Phase 1 Parsing/Data/Python/Py_Phase1_Baseline_Golf_Valuation.csv`; correct `Py_` prefix ✓
- [x] Shared raw GPKGs exist — PBF (`us-260413.osm.pbf`) is primary raw input; guarded by `FileNotFoundError` at line 220. No GPKG fallback (Python is the GPKG producer, not consumer) ✓
- [x] `Py_Phase2_Acreage_Matched.csv` + `Py_Phase2_OSM_Golf_Polygons.gpkg` written to `Data/Python/` — `OUT_GPKG` (line 28) and `OUT_CSV` (line 30) both resolve to `Data/Python/` ✓
- [x] File existence checks on all inputs — both `PBF_FILE` and `PHASE1_CSV` checked at lines 218–220 via `if not path.exists(): raise FileNotFoundError(...)` ✓
- [x] **Part 1D flag resolved** — `Phase_2.py` performs only spatial joins (`sjoin`, `sjoin_nearest`); never joins on `course_id`. The missing `course_id` in `Py_Phase1_Baseline_Golf_Valuation.csv` causes no failure in Phase 2.

**Methodology**
- [x] `sjoin()`, `to_crs()`, `gpd.read_file()` marked `# [METHODOLOGY]` — `to_crs(5070)` at lines 92, 142, 149; `.geometry.area` at line 96; `to_file()` at line 122; `gpd.sjoin()` at line 154; `gpd.sjoin_nearest()` at line 174 — all tagged. No `gpd.read_file()` calls (PBF via pyosmium; Phase 1 via `pd.read_csv`) — N/A ✓
- [x] `acreage_source` flag logic consistent with R and Julia — **FIXED**: `acreage_source` column was entirely absent from the Python output. Added `courses_geo["acreage_source"] = courses_geo["osm_acreage"].apply(lambda x: "MICE_Target" if pd.isna(x) else "OSM")` after de-duplication (after line 188). Two-value schema ("OSM" | "MICE_Target") consistent with Julia fix in Part 2B; "Tigris" absent as expected (R-only tier).
- [x] Match distance threshold consistent — `MAX_NEAREST_M = 500` at line 35; matches R and Julia ✓

**Memory**
- [x] `del df; gc.collect()` in loops — N/A: no multi-dataset loading loop in Phase 2. CLAUDE.md memory rule applies to the 300-dataset imputation loop pattern in Phases 3–6.

**Findings & Fixes:**

1. **Missing `acreage_source` column** — **FIXED**: identical issue to Part 2B. The output CSV had `osm_acreage` but no `acreage_source` field. Fix: added `courses_geo["acreage_source"] = courses_geo["osm_acreage"].apply(lambda x: "MICE_Target" if pd.isna(x) else "OSM")` after the de-duplication step. Two-value schema ("OSM" | "MICE_Target") matches the Julia fix; no "Tigris" category since Tigris is R-only.

2. **Part 1D flag resolved (no fix required)**: The Part 1D observation flagged the absence of `course_id` in `Py_Phase1_Baseline_Golf_Valuation.csv` as a potential KeyError risk if Phase 2 Python joined on it. Confirmed: `Phase_2.py` uses only spatial joins — no identifier-column join. The missing `course_id` is not a problem for Phase 2.

---

### Part 2D — Phase 2 Cross-Language Consistency

- [x] `acreage_source` flag categories are identical across all three scripts — NOT identical by design: R has three values ("OSM" | "Tigris" | "MICE_Target"); Julia and Python have two ("OSM" | "MICE_Target"). `tigris` is an R-only package; absence of "Tigris" in Julia/Python is expected and documented in Parts 2B and 2C. ✓ (documented asymmetry)
- [x] Polygon match distance threshold is the same across all three languages — `MAX_NEAREST_M = 500` m in all three: R line 57, Julia line 38, Python line 35 ✓
- [x] MICE-target course count is consistent (or explainable) across language outputs — NOT identical; R's Tigris Tier 2 recovers additional courses that Julia and Python cannot, so R has fewer MICE targets. Direction is deterministic and explainable. ✓ (explainable asymmetry)
- [x] Column schema of `Acreage_Matched` CSV is consistent across languages (same field names for shared fields) — Partial: primary acreage column is named differently. R uses `final_acreage` (coalesced OSM+Tigris, acres via `coalesce(osm_acres, tigris_acres)`); Julia and Python use `osm_acreage` (OSM-only, acres). R output also retains `tigris_acreage` column absent in Julia/Python. Phase 1 schema gap carries forward: Python missing `course_id`, `Address`, `City`, `State_Abbr`, `Zip_Code`. Because CLAUDE.md mandates each Phase 3 language reads only its own prefixed files, the column name difference does not break the pipeline — Phase 3 R reads `final_acreage`, Phase 3 Julia/Python read `osm_acreage`. Flagged as observation. ✓ (within-language consistency maintained; cross-language name divergence documented)
- [x] GPKGs from all three languages use the same CRS — EPSG:5070 in all three: R `TARGET_CRS <- 5070` (line 56); Julia reads Python GPKG already in EPSG:5070; Python `to_crs(epsg=5070)` (line 92) ✓

**Findings:**

1. **`acreage_source` three-value vs two-value schema (expected asymmetry)**: R produces "OSM" | "Tigris" | "MICE_Target"; Julia and Python produce "OSM" | "MICE_Target". Absence of "Tigris" in Julia/Python is correct — the `tigris` package is R-only. Phase 3 scripts should not assume a uniform `acreage_source` value set across languages; filtering on `!= "MICE_Target"` (or equivalently `acreage_source %in% c("OSM","Tigris")` in R) is the safe pattern.

2. **Primary acreage column name differs — `final_acreage` (R) vs `osm_acreage` (Julia/Python)**: R finalizes acreage as `final_acreage` (coalesced OSM+Tigris, in acres). Julia and Python write `osm_acreage` (OSM-only, in acres). CLAUDE.md's language-prefixed file separation rule prevents this from breaking the pipeline, but Phase 3 scripts must reference the correct column name per language.

3. **`tigris_acreage` column R-only**: R's output CSV retains the raw `tigris_acreage` column (not included in the `select(-any_of(...))` removal list at line 479). Julia and Python have no such column. No downstream impact given language-prefixed file access rules.

4. **MICE-target count asymmetry (explainable)**: R's Tigris Tier 2 recovers a subset of courses beyond OSM, reducing R's MICE_Target count below Julia's and Python's. Magnitude depends on Tigris runtime download; direction is deterministic.

5. **Phase 1 schema gap carries forward**: Python's Phase 2 output inherits the missing `course_id`, `Address`, `City`, `State_Abbr`, `Zip_Code` columns from the Python Phase 1 baseline. No new gap introduced in Phase 2.

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
- [x] Four-section layout present with correct numbered headers — `# === 1. LIBRARIES ===` through `# === 4. EXECUTION ===` at lines 19, 32, 56, 71 ✓
- [x] Two blank lines between every top-level section — confirmed at all three section boundaries ✓
- [x] No `library()` calls outside Section 1 — all 7 libraries inside `suppressPackageStartupMessages({})` at lines 21–29 ✓
- [x] ALL_CAPS constants; `this.path::this.dir()` paths — `SCRIPT_DIR <- this.path::this.dir()` at line 34; `INPUT_CSV`, `OUT_DIR`, `OUT_CSV`, `OUT_ACREAGE_CSV`, `M`, `IMPUTE_COLS`, `SAFE_WORKERS` all ALL_CAPS ✓

**Input / Output**
- [x] Phase 2 `R_Phase2_Acreage_Matched_v2.csv` exists — `INPUT_CSV` resolves to `Phase 2 Spatial Polygons and True Acreage/Data/R/R_Phase2_Acreage_Matched_v2.csv`; confirmed in directory listing ✓
- [x] All 100 `R_Imputed_Dataset_{1..100}.csv` written to `Data/R/` — loop `for (i in 1:M)` with M=100 at lines 133–138; `file.path(OUT_DIR, sprintf("R_Imputed_Dataset_%d.csv", i))` ✓
- [x] `R_National_Acreage_Summary.csv` and `R_Rubins_Rules_Summary.csv` written to `Data/R/` — `OUT_CSV` (line 42) and `OUT_ACREAGE_CSV` (line 43) both resolve to `Data/R/` ✓
- [x] File existence checks guard all inputs — `if (!file.exists(INPUT_CSV)) stop(...)` at lines 76–81; `if (!file.exists(filepath)) stop(...)` inside Rubin's Rules loop at lines 154–156 ✓. Note: National Acreage loop (Step 3) lacks a per-file check, but files were written by Step 1 in the same run — minor observation only.

**MICE Methodology**
- [x] `# [METHODOLOGY]` immediately above the Rubin's Rules pooling block — **FIXED**: tag was present above `q_bar <- mean(aggregates)` at lines 168–169 ✓; added `# [METHODOLOGY]` above `pool_acreage(acreage_totals)` (acreage-specific Rubin's block) which was missing
- [x] M = 100 — `M <- 100` at line 45; loop `for (i in 1:M)` ✓
- [x] Random seed set, value documented — `set.seed(42)  # [METHODOLOGY] reproducibility seed...` at line 53; `parallelseed = 42` inside `futuremice()` at line 126 ✓
- [x] Imputation model uses only legitimate predictors — `predictors <- c("Holes", course_col, "county_type", "Longitude", "Latitude")`; no leakage from `Opportunity_Cost` or from the dependent variable ✓
- [x] `acreage_source == "MICE_Target"` rows are the imputation targets; observed rows not overwritten — `imp_df` subsets to columns only (no explicit filter needed); MICE fills only NAs in `final_acreage` and `Baseline_Value_Per_Acre`; observed values are not touched by MICE ✓
- [x] Each imputed dataset contains `Baseline_Value_Per_Acre` — `IMPUTE_COLS <- c("final_acreage", "Baseline_Value_Per_Acre")` at line 46; both columns present in all 100 output CSVs ✓
- [x] All 100 imputed datasets have identical column schemas — all produced by `complete(imputed_list, i)` on the same `imp_df` ✓

**Memory**
- [x] Dataset-loading loops use `rm(df); gc()` — **FIXED**: added `rm(df); gc()` inside Rubin's Rules loop after extracting aggregates (was missing); added `rm(df_ac); gc()` inside National Acreage loop after extracting totals (was missing) ✓
- [x] All 100 datasets not held simultaneously — MICE's `futuremice()` produces a `mids` object internally; the writing loop at lines 133–138 extracts one dataset at a time via `complete(imputed_list, i)`; no full-dataset accumulation beyond the `mids` object itself ✓. Observation: `imputed_list` and `imp_df` are not freed after Step 1 — no `rm(imputed_list, imp_df); gc()` after the writing loop.

**Findings & Fixes:**

1. **Missing `rm(df); gc()` in Rubin's Rules loading loop** — **FIXED**: Step 2 loop (lines 151–166) loaded `df` each iteration but never freed it. Added `rm(df); gc()` before the closing `}` of the loop.

2. **Missing `rm(df_ac); gc()` in National Acreage loading loop** — **FIXED**: Step 3 loop (lines 227–244) loaded `df_ac` each iteration but never freed it. Added `rm(df_ac); gc()` before the closing `}` of the loop.

3. **Missing `# [METHODOLOGY]` on `pool_acreage()` call** — **FIXED**: `nat_pool_ac <- pool_acreage(acreage_totals)` is the acreage-specific Rubin's Rules pooling block (between-imputation variance only). Added two-line `# [METHODOLOGY]` comment above the call, matching the tag pattern used for the opportunity-cost Rubin's block in Step 2.

4. **Observation — imputed CSVs contain only 7 columns**: `imp_df` is a subset of `acreage_df` containing only `predictors + IMPUTE_COLS` (Holes, course_col, county_type, Longitude, Latitude, final_acreage, Baseline_Value_Per_Acre). All columns needed by Phase 4 OLS and the Phase 3 pooling steps are present. Geographic identifiers (FIPS, course_id, Course_Name) are absent from the 100 imputed CSVs. Not a CLAUDE.md violation; Phase 4 scripts should not expect those columns.

5. **Observation — `imputed_list` not freed after Step 1**: The `mids` object from `futuremice()` holds all M=100 imputed datasets; it persists in memory through Steps 2 and 3 without `rm(imputed_list, imp_df); gc()`. CLAUDE.md's memory rule applies to dataset-loading loops; this is a single large object, not a loop accumulation. Flagged as a best practice gap, not a violation.

---

### Part 3B — `Phase_3.jl`

**Structural**
- [x] Four-section layout; all logic in `main()` — headers at lines 18, 23, 42, 281; `main()` at lines 283–302; entry guard `if abspath(PROGRAM_FILE) == @__FILE__` at line 304 ✓
- [x] Two blank lines; `@__DIR__` paths; ALL_CAPS constants — `const SCRIPT_DIR = @__DIR__` at line 25; `const INPUT_CSV`, `OUT_DIR`, `OUT_CSV`, `OUT_ACREAGE_CSV`, `M`, `IMPUTE_COLS`, `PREDICTOR_COLS` all `const` ALL_CAPS ✓; **FIXED**: stale dev comment at old lines 35–36 removed; stale header lines 5 and 9 corrected from `m=30` → `m=100`
- [x] No `Plasma.jl` — no reference anywhere in the file ✓

**Input / Output**
- [x] Phase 2 `Jl_Phase2_Acreage_Matched.csv` exists — `INPUT_CSV` resolves to `Phase 2 Spatial Polygons and True Acreage/Data/Julia/Jl_Phase2_Acreage_Matched.csv`; confirmed in directory listing from Part 2B ✓
- [x] All 100 `Jl_Imputed_Dataset_{1..100}.csv` written to `Data/Julia/` — `const M = 100`; loop `for i in 1:m_datasets` in `run_imputation()` writes `Jl_Imputed_Dataset_$i.csv` to `OUT_DIR` (`Data/Julia/`) ✓
- [x] `Jl_National_Acreage_Summary.csv` + `Jl_Rubins_Rules_Summary.csv` written to `Data/Julia/` — `OUT_CSV` and `OUT_ACREAGE_CSV` both resolve to `Data/Julia/` ✓
- [x] `isfile` checks on all inputs — `isfile(input_csv) || error(...)` at line 48; `isfile(fpath) || error(...)` at line 125; `isfile(path) || error(...)` at line 215 ✓

**MICE Methodology**
- [x] `# [METHODOLOGY]` on Rubin's Rules block — tagged at lines 139–140 above `q_bar = mean(aggregates)` in `run_pooling()` ✓; **FIXED**: added `# [METHODOLOGY]` above `pool_acreage(national_totals)` in `run_acreage_summary()` (was missing)
- [x] M = 100; random seed documented — `const M = 100`; `Random.seed!(42)  # [METHODOLOGY]` at line 72 ✓
- [x] No data leakage in imputation model — `PREDICTOR_COLS = [:Holes, :Course_Type, :county_type, :Longitude, :Latitude]`; no OC or outcome-derived variables ✓
- [x] `Baseline_Value_Per_Acre` present in all 100 imputed datasets — in `IMPUTE_COLS` at line 38; assigned in saving loop at lines 84–90 ✓. Note: Julia saves full `acreage_df` schema (`out = copy(acreage_df)`) — imputed datasets are wider than R's 7-column subset
- [x] `df = nothing; GC.gc()` after each dataset is written — **FIXED**: added `df = nothing; GC.gc()` in `run_pooling()` loop after extracting `q_i`/`var_i`; added `df = nothing; GC.gc()` in `run_acreage_summary()` loop after `by_type_list[i] = type_sums`

**Findings & Fixes:**

1. **Stale header comment `{1..30}` and `m = 30`** — **FIXED**: Line 5 said `Jl_Imputed_Dataset_{1..30}.csv`; line 9 said `m = 30 imputations`. Both corrected to `{1..100}` and `m = 100` to match `const M = 100`.

2. **Stale dev comment at lines 35–36** — **FIXED**: Comment `# For testing purposes, run M=5, increase to 30 to see if it can be done on your hardware, and 100 as a goal mark.` described a development progression that is already complete. Removed; `const M = 100` stands without the obsolete annotation.

3. **Missing `df = nothing; GC.gc()` in `run_pooling()` loop** — **FIXED**: CLAUDE.md memory violation. Loop loaded `df` each of 100 iterations but never freed it. Added `df = nothing; GC.gc()` before the `@printf` line inside the loop.

4. **Missing `df = nothing; GC.gc()` in `run_acreage_summary()` loop** — **FIXED**: Same violation. Loop loaded `df` each of 100 iterations without freeing. Added `df = nothing; GC.gc()` after `by_type_list[i] = type_sums` and before the `urban_acres`/`rural_acres` extraction (both depend only on `type_sums`, which is preserved).

5. **Missing `# [METHODOLOGY]` on `pool_acreage(national_totals)` call** — **FIXED**: `pool_acreage()` implements acreage-specific Rubin's Rules (between-imputation variance only). Added two-line `# [METHODOLOGY]` comment above the call in `run_acreage_summary()`, matching the pattern applied to Phase_3.R Fix 3.

6. **Observation — Julia imputed datasets save full Phase 2 schema**: `run_imputation()` writes `out = copy(acreage_df)` with imputed values merged back in (line 88 equivalent). Julia's 100 imputed CSVs contain all Phase 2 columns, not the 7-column subset that R's `complete(imputed_list, i)` produces. Not a CLAUDE.md violation; Phase 4 Julia should reference `osm_acreage` (not `final_acreage`) and should be agnostic to the additional columns.

7. **Observation — `ds1` not freed after verification block**: `ds1 = CSV.read(..., "Jl_Imputed_Dataset_1.csv")` is read at line 98 for post-imputation verification and never freed. However, it is a local variable inside `run_imputation()` and goes out of scope when the function returns — Julia GC handles this. No CLAUDE.md violation.

---

### Part 3C — `Phase_3.py`

**Structural**
- [x] Four-section layout; relative `__file__` paths; top-level constants — sections at lines 11, 24, 45, 286 with two blank lines at all boundaries; `SCRIPT_DIR = pathlib.Path(__file__).parent` at line 26; all constants ALL_CAPS ✓

**Input / Output**
- [x] Phase 2 `Py_Phase2_Acreage_Matched.csv` exists — `INPUT_CSV` → `Phase 2 Spatial Polygons and True Acreage/Data/python/Py_Phase2_Acreage_Matched.csv`; confirmed in Part 2C ✓
- [x] All 100 `Py_Imputed_Dataset_{1..100}.csv` written to `Data/python/` — loop `for i in range(m_datasets)` with M=100; `Py_Imputed_Dataset_{i+1}.csv` to `OUT_DIR` (`Data/python/`) ✓
- [x] `Py_National_Acreage_Summary.csv` + `Py_Rubins_Rules_Summary.csv` written to `Data/python/` — `OUT_RUBINS_CSV` and `OUT_ACREAGE_CSV` both resolve to `Data/python/` ✓
- [x] File existence checks on all inputs — `if not input_csv.exists(): raise FileNotFoundError(...)` present in all three functions ✓

**MICE Methodology**
- [x] `# [METHODOLOGY]` on Rubin's Rules block — **FIXED**: tag absent above `q_bar = aggregates.mean()` in `run_pooling()`; added two-line comment. Also **FIXED**: tag absent above `pool_acreage(national_totals)` in `run_acreage_summary()`; added two-line comment. (`ImputationKernel` and `.mice()` calls at lines 82–89 were already tagged ✓)
- [x] M = 100; random seed documented — `M = 100` at line 37; `random_state=42` documented in `# [METHODOLOGY]` comment at lines 82–83 ✓
- [x] No data leakage in imputation model — `PREDICTOR_COLS = ["Holes", "Ownership_Type", "county_type", "Longitude", "Latitude"]`; no OC or outcome-derived variables ✓
- [x] `Baseline_Value_Per_Acre` present in all 100 imputed datasets — in `IMPUTE_COLS`; assigned back in saving loop lines 98–104 ✓
- [x] `del df; gc.collect()` after each dataset is written — **FIXED**: `import gc` was entirely absent (would have raised `NameError`); added. `del completed, out; gc.collect()` added to `run_imputation()` save loop; `del df; gc.collect()` added to `run_pooling()` loading loop; `del df; gc.collect()` added to `run_acreage_summary()` loading loop

**Findings & Fixes:**

1. **Missing `import gc`** — `gc` module never imported; CLAUDE.md requires `gc.collect()` in all dataset loops. Any added `gc.collect()` would have raised `NameError`. **FIXED**: added `import gc` to Section 1 (alphabetically: `gc` < `multiprocessing` < `pathlib`).

2. **Missing `del completed, out; gc.collect()` in `run_imputation()` save loop** — loop (100 iterations) creates `completed` via `imputed_list.complete_data(dataset=i)` and `out = acreage_df.copy()` each iteration but never frees them. **FIXED**: added `del completed, out; gc.collect()` after `out.to_csv(fname, index=False)`.

3. **Missing `del df; gc.collect()` in `run_pooling()` loading loop** — loop reads `df` each of 100 iterations but never frees it. Same class as Phase_3.R Fix 1 and Phase_3.jl Fix 3. **FIXED**: added `del df; gc.collect()` after `within_vars.append(var_i)`.

4. **Missing `del df; gc.collect()` in `run_acreage_summary()` loading loop** — loop reads `df` each of 100 iterations but never frees it. Same class as Phase_3.R Fix 2 and Phase_3.jl Fix 4. **FIXED**: added `del df; gc.collect()` after `by_type_frames.append(type_sums)` (safe: `urban` and `rural` downstream use `type_sums`, not `df`).

5. **Missing `# [METHODOLOGY]` on opportunity-cost Rubin's Rules block in `run_pooling()`** — no tag above `q_bar = aggregates.mean()`. Same class as Phase_3.R Fix 3 and Phase_3.jl Fix 5. **FIXED**: added two-line `# [METHODOLOGY]` comment.

6. **Missing `# [METHODOLOGY]` on `pool_acreage(national_totals)` in `run_acreage_summary()`** — acreage-specific Rubin's pooling block untagged. **FIXED**: added two-line `# [METHODOLOGY]` comment above call.

7. **Stale "STEP 2" print inside `run_acreage_summary()`** — function opened with `print("\n=== STEP 2: NATIONAL ACREAGE SUMMARY ===")` but execution section already prints the correct "STEP 3" header before calling the function, creating a duplicate with the wrong number. **FIXED**: removed stale print from function body; execution-section label is authoritative.

---

### Part 3D — Phase 3 Cross-Language Consistency

- [x] All three scripts target the same set of courses for imputation (same `acreage_source == "MICE_Target"` logic) — None of the three scripts explicitly filter on `acreage_source`; all three rely on the NA pattern in the acreage column (which Phase 2 assigned as `acreage_source == "MICE_Target"`). Logically identical. Cross-language target count asymmetry (R fewer MICE targets due to Tigris Tier 2) is the documented Phase 2D finding — not a Phase 3 inconsistency ✓
- [x] Imputation predictor variable set is equivalent across languages — All five predictors {Holes, ownership/course type, county_type, Longitude, Latitude} are present in all three. Column name for ownership type differs: R detects `"Course_Type"` or `"Ownership_Type"` dynamically; Julia creates `Course_Type` alias from `Ownership_Type`; Python uses `"Ownership_Type"` directly. Functionally equivalent — same underlying information ✓
- [x] M = 100 confirmed for all three languages — `M <- 100` (R line 45); `const M = 100` (Julia line 35); `M = 100` (Python line 38) ✓
- [x] `Baseline_Value_Per_Acre` column present and populated in all 300 imputed datasets (100 × 3) — In `IMPUTE_COLS` in all three; extracted from MICE output and written to every imputed dataset CSV ✓
- [x] `Rubins_Rules_Summary` CSVs report the same parameter names (Intercept, Holes, Urban County) for downstream Phase 4 cross-check — **Observation**: checklist item conflates Phase 3 and Phase 4 outputs. Phase 3's pooling is over the national aggregate opportunity cost scalar; the Metric column contains aggregate statistics ("Pooled Aggregate National Value ($B)", etc.) — not regression coefficients. Those appear only in Phase 4 output CSVs. However, the eight Metric strings ARE hard-coded identically across all three Phase 3 scripts (same literal strings), so Phase 6 CSV reads by metric name will be consistent ✓ (with note about item framing)
- [x] National acreage totals in summary CSVs are in the same plausible range across languages — Confirmed from actual output CSVs: R = 2,303,152 acres; Julia = 2,291,064 acres; Python = 2,306,485 acres. Spread = 15,421 acres = 0.67% of mean. All three consistent with ~2.30 M acre U.S. golf footprint. Urban/Rural split consistent across all three (~74% Urban, ~26% Rural) ✓

**Findings:**

1. **No fixes required.** This is a read-only consistency check; all code-level items confirmed from the three scripts already reviewed in Parts 3A–3C.

2. **Checklist item 5 conflates Phase 3 and Phase 4 content**: The item asks for "Intercept, Holes, Urban County" parameter names in Phase 3's Rubins_Rules_Summary. Those parameter names are regression coefficients and appear only in Phase 4 (`R_Regression_Results.csv`, etc.). Phase 3's Rubins_Rules_Summary tracks the aggregate national opportunity cost scalar and its pooling statistics. The relevant consistency check (identical Metric string names) is confirmed — all three use the same 8+M row structure.

3. **Julia scientific notation in Acreage CSV**: `Pooled_Acres` for the National Total is written as `2.29106386e6` — Julia's default float formatting for large numbers. All CSV readers handle this, but it's cosmetically different from R's and Python's decimal format. No fix needed.

4. **Python NA-county groupby gap**: Python's `run_acreage_summary()` uses pandas `groupby("county_type")` which drops NA keys by default. Python's Urban+Rural subtotals (1,700,032 + 602,051 = 2,302,083) do not sum to the national total (2,306,485) — the 4,402-acre gap represents NA-county courses counted nationally but absent from the breakdown. R has an explicit "NA" row (4,325 acres); Julia has an explicit blank-label row (4,287 acres). Python's national total is correct; only the breakdown is incomplete. Phase 6 scripts reading this CSV should not assume column sums equal the national total for the Python file.

5. **National acreage totals (confirmed from output CSVs)**:

| Language | National Total | Urban | Rural | NA/empty county |
|----------|---------------|-------|-------|-----------------|
| R | 2,303,152 acres | 1,701,726 | 597,101 | 4,325 (labeled "NA") |
| Julia | 2,291,064 acres | 1,698,944 | 587,833 | 4,287 (blank label) |
| Python | 2,306,485 acres | 1,700,032 | 602,051 | absent (pandas groupby drops NA) |

Spread: 15,421 acres (0.67% of mean) — well within expected range for independent MICE runs with different backends (Random Forest/R, LightGBM/Python, Mice.jl/Julia).

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
| 2C    | Phase_2.py         | `[x]`   | 1 fix: `acreage_source` column added ("OSM"\|"MICE_Target"); Part 1D flag resolved (no `course_id` join in Phase 2) |
| 2D    | Phase 2 Cross-Lang | `[x]`   | 5 obs: acreage_source 3-value (R) vs 2-value (Jl/Py); `final_acreage` (R) vs `osm_acreage` (Jl/Py) name divergence; `tigris_acreage` R-only column; MICE_Target count higher in Jl/Py (explainable); Phase 1 schema gap carries forward in Py |
| 3A    | Phase_3.R          | `[x]`   | 3 fixes: `rm(df);gc()` added to Rubin's loop; `rm(df_ac);gc()` added to Acreage loop; `[METHODOLOGY]` added above `pool_acreage()`. 2 obs: imputed CSVs 7-col subset only; `imputed_list` not freed post-Step 1 |
| 3B    | Phase_3.jl         | `[x]`   | 5 fixes: header `{1..30}`→`{1..100}` + `m=30`→`m=100`; stale dev comment removed; `df=nothing;GC.gc()` added to Rubin's loop; `df=nothing;GC.gc()` added to Acreage loop; `[METHODOLOGY]` added above `pool_acreage()`. 2 obs: imputed CSVs full Phase 2 schema (vs R's 7-col); `ds1` freed on function return |
| 3C    | Phase_3.py         | `[x]`   | 7 fixes: `import gc` added; `del completed,out;gc.collect()` in imputation save loop; `del df;gc.collect()` in Rubin's loop; `del df;gc.collect()` in Acreage loop; `[METHODOLOGY]` on Rubin's `q_bar` block; `[METHODOLOGY]` on `pool_acreage()`; stale "STEP 2" print removed from function body |
| 3D    | Phase 3 Cross-Lang | `[x]`   | No fixes needed. 4 observations: Phase 4 parameter names not in Phase 3 CSVs (item 5 conflation); Julia scientific notation in Acreage CSV; Python NA-county groupby gap (4,402 acres absent from breakdown, present in national total); acreage totals R=2.303M/Jl=2.291M/Py=2.306M — 0.67% spread, consistent |
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
