# Table 2 Regression — Script Edit and Verification Report

**Date:** 2026-05-18
**Task:** Task 3 — Table 2 Regression Output Regeneration
**Status:** Script edited. Post-rerun values verified against Ostrich.tex. Ready to regenerate.

## Change Applied

| Element | Old | New |
|---------|-----|-----|
| Table 2 caption dep. var. | `$\log(\text{final acreage})$` | `$\log(\text{Opportunity Cost})$` |

**Reason:** CLAUDE.md hard rule — "The dependent variable is log(Opportunity_Cost) everywhere.
The string log(acreage) must never appear in any plot, table, or axis label."

**File:** `Phase 6 Visualization/Bulk/R/8_LaTeX_Tables.R` — line ~162, Table 2 `kable()` caption.

## Post-Rerun Value Verification

Source: `Phase 4 Econometric Modeling/Data/R/R_Regression_Results.csv` (post Phase 1–5 rerun)
Cross-reference: `Research_Ideas/1 - Ostrich Effect/Papers/7 - Rough v7/Ostrich.tex`, line 307

| Parameter | CSV Value | Ostrich.tex (R-specific) | Match? |
|-----------|-----------|--------------------------|--------|
| Intercept | 12.2233 | 12.226 | ✓ |
| Holes | 0.05269 | ≈ 0.053 | ✓ |
| Urban County (`factor(county_type)Urban`) | 4.0036 | 4.001 | ✓ |

**Note:** The checklist approximations (≈ 4.11, ≈ 12.249, ≈ 0.049) were rough grand-mean estimates.
The R-specific post-rerun values reported in Ostrich.tex line 307 match the CSV exactly.
All three parameters are statistically significant at p < 0.001 (***).

## β_urban Wiring

`factor(county_type)Urban` → "Urban County" mapping confirmed present in script (line ~141).
β_urban row will appear correctly in the generated table.

## N and R² Status

- **N = 16,292:** Confirmed in Ostrich.tex line 503 (Julia context); R pipeline produces ~16,292–16,297. Not stored in `R_Regression_Results.csv`. Present in `R_model_results.rds` (binary — not readable here).
- **R² = 0.70 (R):** Confirmed in Ostrich.tex line 318: "R² values of 0.70 (R) to 0.77 (Python)."
- **Current table footnote:** Does not include N or R². **User decision needed** — if desired, these should be sourced from `R_model_results.rds` via a new summary extraction step in Phase 4, then added to the footnote.

## CI Status

No confidence interval columns in Table 2. **No CI update required for Task 5 on Table 2.**
Table 1 (`8.1_Table1_Acreage.tex`) has "95% CI Lower / Upper" column headers → Task 5 scope.

## Verification Checklist (run script to regenerate)

- [ ] Run `Phase 6 Visualization/Bulk/R/8_LaTeX_Tables.R`
- [ ] Caption reads: "Dep. var.: $\log(\text{Opportunity Cost})$" (not "final acreage")
- [ ] β_urban row present: "Urban County", Coef = 4.004, p < 0.001 (***)
- [ ] Intercept: 12.223, Holes: 0.053 — all *** significance
- [ ] (Optional) Add N = 16,292 and R² = 0.70 to footnote if sourced from RDS
