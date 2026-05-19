# Phase 6 — v2 Slide Deck Update Checklist

**Session goal:** Update Phase 6 figure-generation scripts to support the v2 slide deck
(`Gone Golfing - Presentation.tex` in `Research_Ideas/1 - Ostrich Effect/Slides - General/Version 2/`).

Tasks proceed **one at a time**. Claude stops after each and waits for explicit "proceed" before starting the next.

> **Rerun note (2026-05-18):** User confirmed a ground-up rerun of all mainline scripts Phase 1 → Phase 5 completed successfully. Post-rerun outputs verified against Ostrich.tex canonical values during Task 3. All downstream tasks (4, 5) are operating against post-rerun data.

---

## Step 0 — Project Rules & Post-Rerun Verification

**Status: COMPLETE**

- [x] Read `999 - Late Stage/CLAUDE.md`
- [x] Read `999 - Late Stage/Notes.md`
- [x] Read `Research_Ideas/1 - Ostrich Effect/Papers/7 - Rough v7/Ostrich.tex` — §5.4 and Preservation Paradox
- [x] Read `Phase 6 Visualization/Phase_6.R` — structure and wired functions confirmed

**Canonical values confirmed (Ostrich.tex, line 364 and 402):**

| Metric | Value | Source |
|--------|-------|--------|
| Oahu OC Grand Mean | **$26.67B** | Rubin-pooled across R/Py/Jl |
| → R sub-pool | $26.68B | — |
| → Python sub-pool | $26.79B | — |
| → Julia sub-pool | $26.54B | — |
| Preservation/Federal tier | **$21.8B (81.7%)** | acreage share |
| Agriculture tier | **$3.7B (13.8%)** | acreage share |
| Resort/Residential/Other | **$1.2B (4.5%)** | acreage share |

No regeneration will occur until the value cross-check confirmed above.

---

## Task 1 — Oahu Map Legend Repositioning (Layout Only)

**Status: COMPLETE (scripts edited; regeneration pending)**

**Affected figures:**
- [ ] `9.141_Oahu_Opportunity_Cost_Map_GrandMean.png` — needs regeneration
- [ ] `9.101_Oahu_Opportunity_Cost_Map_ObservedOnly.png` — needs regeneration
- [ ] `9b.141_Oahu_OC_Map_Rural_USDA_Sensitivity_GrandMean.png` — needs regeneration
- [ ] Per-language Oahu OC map variants in `QA_Verification/` — produced by bulk script rerun

**Changes applied:**
- [x] Heat legend: `guide_colorbar` → `barwidth = 0.5cm, barheight = 5cm`; `legend.position = "right"`, `legend.direction = "vertical"`
- [x] Scale bar: `annotation_scale(location = "tl")` — moved to top-left
- [x] Compass rose: `annotation_north_arrow(location = "tl", pad_y = unit(1.5, "cm"))` — clusters below scale bar

**Scripts edited:**
- [x] `Phase 6 Visualization/Bulk/R/9_Oahu_Opportunity_Cost_Map.R` — `build_oahu_oc_map()`
- [x] `Phase 6 Visualization/Phase_6.R` — `run_9_Oahu_Opportunity_Cost_Map()` → `build_oahu_oc_map()`
- [x] `Phase 6 Visualization/Phase_6.R` — `run_9b_Oahu_OC_Rural_USDA_Sensitivity()` → `build_oahu_oc_map()`

**Deliverable:** [x] `QA/data/Oahu_Legend_Reposition_Done.md` written.

---

## Task 2 — Waffle Chart (12.141) Regeneration

**Status: COMPLETE (script edited; regeneration pending)**

**Affected figures:**
- [ ] `12.141_Zoning_Waffle_Chart_TriLanguage.png` — needs regeneration
- [ ] Per-language QA variants in `QA_Verification/` — needs regeneration

**Changes applied:**
- [x] Agriculture squares: 10 → **14** (13.8% rounded); Other squares: 8 → **4** (4.5% rounded)
- [x] Tier labels updated with canonical dollar values: $21.8B · 81.7% / $3.7B · 13.8% / $1.2B · 4.5%
- [x] Grand Mean total added to title: **$26.67B**
- [x] In-chart text: "82%" → "**81.7%**"
- [x] Color legend: `fig[2,1]` horizontal → `fig[1,2]` **vertical-right**
- [x] CIs: **not present** in this script — no CI update required

**Script edited:** `Phase 6 Visualization/Bulk/Julia/12_Zoning_Waffle_Chart.jl`

**Deliverable:** [x] `QA/data/Waffle_Regeneration_Done.md` written.

---

## Task 3 — Table 2 Regression Output Regeneration

**Status: COMPLETE (script edited; full regeneration blocked on Phase 4 rerun)**

**Affected file:**
- [ ] `8.241_Table2_Regression.tex` — needs regeneration after Phase 4 rerun

**Changes / verifications:**
- [x] Located generating script: `Phase 6 Visualization/Bulk/R/8_LaTeX_Tables.R`
- [x] Caption dep. var. fixed: `log(final acreage)` → **`log(Opportunity Cost)`** (CLAUDE.md hard rule)
- [x] β_urban row: **wiring confirmed and post-rerun verified** — CSV: 4.004, Ostrich.tex (R): 4.001 ✓
- [x] Intercept: CSV 12.223 = Ostrich.tex 12.226 (R) ✓
- [x] Holes: CSV 0.0527 = Ostrich.tex ≈ 0.053 (R) ✓  — checklist approx. ≈4.11 / 12.249 / 0.049 were grand-mean estimates; R-specific values confirmed
- [⚠] N = 16,292 confirmed in paper (Ostrich.tex line 503); R² = 0.70 (R) confirmed (line 318) — **not in CSV; add to footnote requires RDS extraction (user decision)**
- [x] CIs in Table 2: **none present** — no CI update needed (Table 1 has 95% CI columns; will be addressed in Task 5)

**Deliverable:** [x] `QA/data/Table2_Regeneration_Done.md` written.

---

## Task 4 — Magnitude Argument Bar Chart (New Figure)

**Status: COMPLETE (scripts written; regeneration pending)**

**New figure:** `16.141_Magnitude_Comparison_TriLanguage.png`

**Confirmed values (user, 2026-05-18):**
| Category | Acres | Source |
|----------|-------|--------|
| U.S. Utility-Scale Solar | 644,000 | EIA Aug 2024, 107.4 GW × 6 ac/MW (SEIA central) |
| Delaware + Rhode Island | 1,908,730 | U.S. Census 2010, land area only |
| U.S. Golf Courses | 2,300,521 | This thesis, Phase 2 OSM aggregate |
| NREL Full-Solar Scenario | 10,000,000 | PV Magazine USA, June 2024 (forward-looking) |

**Headline statistics (subtitle):**
- Golf footprint is **3.6×** total U.S. utility-scale solar
- Golf footprint exceeds Delaware + Rhode Island by **21%**

**Affected figures:**
- [ ] `16.141_Magnitude_Comparison_TriLanguage.png` — needs regeneration

**Design:**
- [x] Horizontal bar chart, sorted ascending by acres
- [x] Golf bar: UHM_GREEN `#024731`; comparison bars: UHM_SILVER `#B2B2B2`; NREL bar: lighter gray `#D8D8D8`
- [x] Bar-end labels; x-axis in million acres
- [x] Subtitle encodes golf vs. solar ratio and golf vs. DE+RI percent difference
- [x] Full citations in caption

**Scripts created/edited:**
- [x] `Phase 6 Visualization/Bulk/R/16_Magnitude_Chart.R` — created
- [x] `Phase 6 Visualization/Phase_6.R` — `run_16_Magnitude_Chart()` added and wired

**Deliverable:** [x] `QA/data/Magnitude_Chart_Generation_Done.md` written.

---

## Task 5 — Project-Wide 95% → 99% CI Update

**Status: COMPLETE (2026-05-18)**

**Audit complete — scope confirmed by user:**

| File | Lines | Change |
|------|-------|--------|
| `5_Econometric_Plots.jl` | 69–70 | `1.96` → `2.576` (forest plot CI bounds) |
| `6_Advanced_Econometric_Plots.jl` | 101 | `log(acreage)` → `log(Opportunity Cost)` (CLAUDE.md bonus fix) |
| `6_Advanced_Econometric_Plots.jl` | 103 | `"95% CI"` → `"99% CI"` (caption string) |
| `6_Advanced_Econometric_Plots.jl` | 234 | `z = 1.96` → `z = 2.576` (make_row default) |
| `8_LaTeX_Tables.R` | 118 | `95\\% CI Lower/Upper` → `99\\% CI Lower/Upper` (Table 1 headers) |
| `Phase_6.R` | ~1514 | same Table 1 header change (inline copy) |

**Clean (zero CI hits):** `7_Bivariate_Econometric_Map.R`, `11_Lorenz_Curve.jl`, `13_Counterfactual_Area.jl`, `14_Urban_Rural_Scatter.jl`, `15_Residual_Map.R`

**Audit targets (Phase 6 scripts):**
- [x] `5_Econometric_Plots.jl` — forest plot (5.141), MICE density (5.241–5.245)
- [x] `6_Advanced_Econometric_Plots.jl` — marginal effects (6.141)
- [x] `7_Bivariate_Econometric_Map.R` — bivariate cost-vs-density (7.141) ✓ clean
- [x] `11_Lorenz_Curve.jl` — Lorenz curve (11.141) ✓ clean
- [x] `13_Counterfactual_Area.jl` — counterfactual area (13.141) ✓ clean
- [x] `14_Urban_Rural_Scatter.jl` — urban-rural scatter (14.111–14.141) ✓ clean
- [x] `15_Residual_Map.R` — log-residual (15.141), dollar-residual (15.241) ✓ clean
- [x] `8_LaTeX_Tables.R` — Table 1 has 95% CI column headers (Table 2 clean)
- [x] `Phase_6.R` master — inline copy of Table 1 headers

**Additional user-approved scope (same pass):**
- [x] Regenerate: `5_Econometric_Plots.jl` ✓, `6_Advanced_Econometric_Plots.jl` ✓, `8_LaTeX_Tables.R` ✓
- [x] Cross-language grep Phase 4/5: Phase 4 clean; Phase 5 hits found and updated (all 6 scripts)
- [x] Write `QA/data/CI_99pct_Project_Update.md`

**Scope expansion discovered during audit:**
- Phase 3 upstream CI sources (`rubins_rules_pooling.R/jl/py`, `Phase_3_National_Acreage_Summary.R`) also updated and CSV regenerated — required for Table 1 header to be truthful
- Phase 5 `1.96` found in all 3 language mains + 3 Step3 bulk scripts — updated for consistency (console output only, no figure feeds)

**Ostrich.tex prose flag (future pass):** Lines ~307, ~312, ~596 still reference "95% confidence intervals" — must be updated in thesis prose edit pass.

**Substitution mapping:**
| Old | New |
|-----|-----|
| `level = 0.95` | `level = 0.99` |
| `qnorm(0.975)` / `1.96` | `qnorm(0.995)` / `2.576` |
| `qt(0.975, df=...)` | `qt(0.995, df=...)` |
| `"95% CI"` string literals | `"99% CI"` |
| `alpha = 0.05` | `alpha = 0.01` |
| Python `norm.ppf(0.975)` | `norm.ppf(0.995)` |
| Julia `quantile(Normal(), 0.975)` | `quantile(Normal(), 0.995)` |

**Substitution mapping:**
| Old | New |
|-----|-----|
| `level = 0.95` | `level = 0.99` |
| `qnorm(0.975)` / `1.96` | `qnorm(0.995)` / `2.576` |
| `qt(0.975, df=...)` | `qt(0.995, df=...)` |
| `"95% CI"` string literals | `"99% CI"` |
| `alpha = 0.05` | `alpha = 0.01` |
| Python `norm.ppf(0.975)` | `norm.ppf(0.995)` |
| Julia `quantile(Normal(), 0.975)` | `quantile(Normal(), 0.995)` |

**Rubin's Rules:** pooled SE formula unchanged; only the z/t multiplier changes.

**Deliverable:** After regeneration, write comprehensive `QA/data/CI_99pct_Project_Update.md` listing every script touched, line numbers, and sample old vs. new CI bounds.


# Task 6 — Dual-CI Extension (95% and 99% coexisting)

**Status: IN PROGRESS**

**Scope (user-approved 2026-05-18):**

| Target | Change |
|--------|--------|
| Forest plot (`5.1_Forest_Plot.png`) | Dual CI bands: 99% outer (dark, thick), 95% inner (light, thin); legend makes layering explicit |
| Marginal effects plot (`6.141`) | Single CI at 99% — no dual ribbon; caption notes "99% CI shown; 95% CI available in supplementary data" |
| Table 1 (`8.1_Table1_Acreage.tex`) | Single CI at 99%; footnote: "99% confidence intervals reported; 95% intervals available in the replication package." |
| Phase 3 CSVs (R/Python/Julia) | Both `CI_95_*` and `CI_99_*` as parallel columns; fix column-name mismatch (values were 99% but columns said 95%) |
| Rubin's Rules scripts (3 languages) | Both CI computations in `rubins_rules()` / `run_pooling()` functions; dual rows in output CSVs |
| `CI_99pct_Project_Update.md` | New section documenting dual-CI extension and column-rename rationale |

**Script edits:**
- [x] `Phase 6 Visualization/Bulk/Julia/5_Econometric_Plots.jl` — dual `rangebars!` layers, legend, subtitle update
- [x] `Phase 3/Bulk Tests/R/Phase_3_National_Acreage_Summary.R` — `pool_acreage()` returns both CI levels; CSV adds `CI_99_*` columns, renames `CI_95_*` to correct 95% values
- [x] `Phase 3/Bulk Tests/R/rubins_rules_pooling.R` — `rubins_rules()` returns `CI95_*` and `CI99_*`; CSV rows fixed and expanded
- [x] `Phase 3/Bulk Tests/Julia/Rubins_Pooling.jl` — dual CI; fix wrong "95% CI" labels (held 99% values); add proper 95% rows
- [x] `Phase 3/Bulk Tests/python/rubins_rules_pooling.py` — same as Julia
- [x] `Phase 6 Visualization/Bulk/R/8_LaTeX_Tables.R` — `select(CI_99_*)` before mutate; add `footnote()` to tbl1
- [x] `Phase 6 Visualization/Phase_6.R` — mirror Table 1 changes from `8_LaTeX_Tables.R`

**Regeneration:**
- [ ] `National_Acreage_Summary.csv` — rerun `Phase_3_National_Acreage_Summary.R`
- [ ] `5.1_Forest_Plot.png` — rerun `5_Econometric_Plots.jl`
- [ ] `8.1_Table1_Acreage.tex` — rerun `8_LaTeX_Tables.R`

**Deliverable:**
- [ ] `QA/data/CI_99pct_Project_Update.md` amended with dual-CI extension section + β_urban four-bound sanity check

**Cross-language consistency note:** Forest plot reads coefficient SEs inline and applies two z multipliers (1.96 and 2.576) to the same SEs. Statistically valid; SE is unchanged.

---

## Notes

- All output paths preserved (`Final_Thesis_Figures/` and `QA_Verification/`).
- Source data is read-only. Only figure-generating scripts and output PNG/TEX files are touched.
- UHM_GREEN `#024731` and existing UHM color palette must be preserved throughout.
- Stop on ambiguity; report missing files or unsourceable values rather than substituting.
