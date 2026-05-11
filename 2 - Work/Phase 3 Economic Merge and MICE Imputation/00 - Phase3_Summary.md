# Phase 3 - MICE Imputation & Rubin's Rules Valuation

Phase 3 closes the missing-data gap in the dataset and produces the headline national valuation. Two variables require imputation: the polygon-derived acreage (`osm_acreage`, 28.8% missing) and the economic baseline value (`Baseline_Value_Per_Acre`, 6.7% missing). The imputation method is Multiple Imputation by Chained Equations (MICE) with a Random Forest backend, and the resulting per-dataset estimates are pooled via Rubin's Rules to produce a national aggregate with a defensible confidence interval.

The pipeline runs MICE independently in **Python** (`miceforest` with a LightGBM gradient-boosted Random Forest), **R** (`mice` with `method = "rf"`), and **Julia** (`Mice.jl`). Each language produces $M = 100$ complete imputed datasets, yielding 300 imputed datasets in total across the tri-language design. I chose $M = 100$ over the $M = 5$ to $M = 10$ that early MICE literature recommended because the higher value follows modern guidance for stabilizing standard errors and eliminating Monte Carlo error, and is particularly important when the missing-data rate is as high as 28.8%. I preferred Random Forest over linear MICE backends because the relationship between course acreage and its predictors (number of holes, ownership type, urban/rural classification, latitude and longitude) is non-linear, and tree-based methods cannot produce impossible negative-valued imputations the way linear methods can.

Within each language, per-dataset opportunity costs are computed as `osm_acreage × Baseline_Value_Per_Acre` summed across courses, then pooled across the 100 imputations using Rubin's Rules: the pooled point estimate is the mean of the per-dataset sums, and the total variance combines within-imputation variance (the dispersion of estimates within a single completed dataset) and between-imputation variance (the dispersion of point estimates across the 100 datasets). The 95% confidence interval is the pooled estimate plus or minus 1.96 standard errors.

## Key result

All three languages converge on an aggregate national opportunity cost in the **$926B–$959B range**, with overlapping 95% confidence intervals: Python at $943.0B (CI: $936.3B–$949.7B), R at $936.0B (CI: $926.4B–$945.7B), and Julia at $951.4B (CI: $943.8B–$958.9B). The Grand Mean across the three implementations is approximately **$943 billion**. The cross-language spread of 1.6% on a ~$940B base is well within expected variation from independent Random Forest RNG seeds and internal MICE implementations, and is materially smaller than the natural between-imputation variance within any single language.

The diagnostic that between-imputation variance ($V_B$) is two to three orders of magnitude larger than within-imputation variance ($V_W$) confirms the model is well-specified: uncertainty in the aggregate estimate is driven by the genuine ambiguity of the missing values, not by measurement noise within any single completed dataset.

\newpage

## What was solved

The Julia implementation initially failed with world-age errors when `Mice.jl` functions were defined and called in the same top-level script execution context. I refactored `Phase_3.jl` to use `Mice.jl`'s `mice()` and `complete()` APIs in the documented order, with imputation logic isolated in its own function scope. This fix was load-bearing for the cross-language validation: without a working Julia pipeline, the tri-language design would have collapsed to a Python-vs-R comparison, which would not have demonstrated robustness against backend-specific MICE implementation choices.

Phase 3 also produces a national acreage summary aggregating the imputed footprint by urban/rural classification. The pooled total is approximately 2.30 million acres, with 1.70 million in urban counties and 600,000 in rural counties. This summary is a sanity check on imputation stability rather than a primary research output, and feeds directly into the regression and visualization work in Phases 4 and 6.

Outputs flow forward into Phase 4 (regression analysis and marginal effects estimation) and ultimately into Phase 6 (visualization and table generation for the thesis).