# `pool_oahu_oc()` Bug Fix Report
**Session:** 2026-05-12 | Phase 6 Visualization Orchestrator

---

## 1. Exact Diff — Changes Made Inside `pool_oahu_oc()`

Three iterations were required to reach the working fix. The final state of the code in `Phase_6.R` is:

### `get_acreage()` helper — added at lines 1624–1631 (inside `run_9_Oahu_Opportunity_Cost_Map()` functions block):

```diff
+    # Column-agnostic acreage extractor: returns the correct acreage vector from a
+    # data frame regardless of which column name the language group uses.
+    # R datasets use final_acreage; Python/Julia datasets use osm_acreage.
+    # Called via pick(everything()) inside mutate() so the full data frame is available.
+    get_acreage <- function(df) {
+        if ("osm_acreage" %in% names(df)) df[["osm_acreage"]] else df[["final_acreage"]]
+    }
```

### `pool_oahu_oc()` mutate — replaced at lines 1653–1663:

```diff
-                mutate(opp_cost = final_acreage * Baseline_Value_Per_Acre)
+                mutate(
+                    # [BUGFIX] R datasets carry only final_acreage (no osm_acreage column).
+                    # Python/Julia datasets carry only osm_acreage (no final_acreage column).
+                    # Inline if() inside mutate() fails because dplyr's data mask still tries to
+                    # resolve both branch symbols at parse time. The helper get_acreage() receives
+                    # the full row-slice via pick(everything()) and selects the correct column
+                    # vector by name at runtime — safely column-agnostic across all three language
+                    # groups. Without this fix, Py/Jl pools returned all-NA and the Grand Mean
+                    # degraded silently to R-only data.
+                    acreage  = get_acreage(pick(everything())),
+                    opp_cost = acreage * Baseline_Value_Per_Acre
+                )
```

### Why `coalesce()` variants were rejected

| Variant | Problem |
|---|---|
| `coalesce(final_acreage, osm_acreage)` | Fails on R datasets: `osm_acreage` column does not exist → "column not found" error |
| `if ("osm_acreage" %in% names(.)) ...` | `.` pronoun is only valid with `%>%` (magrittr). The native pipe `\|>` does not bind `.` → "object '.' not found" |
| `if ("osm_acreage" %in% names(cur_data())) coalesce(...)` | `cur_data()` is deprecated in dplyr 1.1+. More importantly, dplyr's data mask evaluates **both** branches of `if()` before the condition resolves → "object 'final_acreage' not found" on Py/Jl datasets |
| `get_acreage(pick(everything()))` ✅ | `pick(everything())` passes the complete data frame to the helper; `get_acreage()` inspects names outside dplyr's data mask using base R `names()` and `[[...]]` indexing — fully safe |

### Column inventory confirmed:

| Language | `final_acreage` | `osm_acreage` |
|---|---|---|
| R  | ✅ YES | ❌ NO  |
| Python | ❌ NO | ✅ YES |
| Julia  | ❌ NO | ✅ YES |

---

## 2. Output Files — Sizes and Timestamps

All four files are fresh from the 2026-05-12 09:02 run:

| File | Size | Last Modified |
|---|---|---|
| `9.141_Oahu_Opportunity_Cost_Map_GrandMean.png` | 901.8 KB | 2026-05-12 09:02:12 |
| `9.101_Oahu_Opportunity_Cost_Map_ObservedOnly.png` | 897.0 KB | 2026-05-12 09:02:13 |
| `15.141_Log_Residual_Map_GrandMean.png` | 1,933.8 KB | 2026-05-12 09:02:39 |
| `15.241_Dollar_Residual_Map_GrandMean.png` | 959.0 KB | 2026-05-12 09:02:41 |

> [!NOTE]
> The two residual map filenames (`15.141_Log_Residual_Map_GrandMean.png` and `15.241_Dollar_Residual_Map_GrandMean.png`) differ from the names specified in the task (`15.141_Residual_Map_GrandMean.png` and `15.241_Residual_Map_ObservedOnly.png`). This is a pre-existing naming discrepancy in the orchestrator that was **not changed** per the "do not touch other things" constraint. See anomalies section below.

---

## 3. Grand Mean — Tri-Language Confirmation

The Grand Mean Oahu map (`9.141`) is now computed from all three language groups rather than R-only. From the run log:

```
  [R]  Pooling 100 imputations...
  [Py] Pooling 100 imputations...
  [Jl] Pooling 100 imputations...

  Grand Mean Oahu total: $30.830B across 37 courses
  OC range: $286.6M – $2,271.8M
```

**All three sanity checks pass:**
- ✅ Subtitle reports **37 courses** (not the stale 28 from the old standalone script)
- ✅ Dollar scale is in the expected range: **$286.6M – $2,271.8M per course**
- ✅ Grand Mean is computed from all three language pools via `full_join` + `rowMeans(cbind(oc_r, oc_py, oc_jl), na.rm = TRUE)`

Before the fix, `pooled_py` and `pooled_jl` returned all-NA (because `osm_acreage` was used for OC in the imputed CSV but `pool_oahu_oc()` only referenced `final_acreage`). The `rowMeans(..., na.rm = TRUE)` then collapsed to R-only, producing a Grand Mean from 100 imputations instead of 300.

---

## 4. Anomalies Noticed But Not Fixed

The following issues were observed during the run. **None were modified.**

### A. Output Filename Mismatch for Script 15 (pre-existing)
The orchestrator saves:
- `15.141_Log_Residual_Map_GrandMean.png`
- `15.241_Dollar_Residual_Map_GrandMean.png`

The task brief specified:
- `15.141_Residual_Map_GrandMean.png`
- `15.241_Residual_Map_ObservedOnly.png`

Script 15 produces **two types of residual maps** (log-scale and dollar-scale), both Grand Mean only — there is no "ObservedOnly" residual variant. The naming may reflect an older design document that predates the current dual-map structure.

### B. Script 15 Log-Residual Range is NaN (pre-existing data issue)
The run reported:
```
Log-residual range: [NaN, NaN]  (0 = perfect fit)
```
The `log_residual` is computed as `log(final_acreage) - predicted_log`. The R imputed datasets carry `final_acreage`, so this should work. However, `NaN` suggests all `log_residual` values resolved to `NaN` or `Inf`. Likely cause: `final_acreage` contains 0 or negative values in some imputations that pass the `final_acreage > 0` filter due to floating-point precision (e.g., `1e-15 > 0` is TRUE but `log(1e-15)` is a very large negative, and the mean of those could be problematic). The dollar residual range is also extreme: `$-1.766e12` per county. This is a Script 15 data-quality issue unrelated to the pool_oahu_oc() fix. The map still renders and saves correctly.

### C. Script 8 Table 2 Missing Urban County Parameter
The run printed:
```
Parameter labels:
    Intercept
    Holes
```
Expected three parameters (Intercept, Holes, Urban County). The `factor(county_type)Urban` parameter appears to be absent from one or more of the three regression result CSVs, causing `inner_join` to drop that row. This is a pre-existing regression output issue.

### D. Map 2 `log-10 transformation infinite values` Warning
```
Warning: log-10 transformation introduced infinite values.
```
This indicates some counties have `pooled_opp_cost = 0`, which becomes `-Inf` under `log10`. The map renders correctly (gray for NA/zero counties), but the warning is cosmetically present.

### E. Script 15 `final_acreage` column not in `run_15_Residual_Map()` scope across language groups
Script 15 uses only **R** imputed datasets (`R_Imputed_Dataset_1..100.csv`) for residual computation — it does not pool Python or Julia residuals. The `log_residual = log(final_acreage) - predicted_log` formula is R-specific. If the intent is a tri-language residual Grand Mean (analogous to Script 9), Python and Julia datasets would need the `get_acreage()` pattern applied here too. Not changed — noted for follow-up.
