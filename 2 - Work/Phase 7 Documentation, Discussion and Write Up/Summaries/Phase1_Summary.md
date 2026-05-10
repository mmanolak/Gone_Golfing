# Phase 1 - Spatial Parsing & Baseline Valuation

Phase 1 builds the foundational dataset for the entire thesis. The pipeline ingests a raw CSV of 16,297 U.S. golf courses with GPS coordinates, spatially joins each course to its U.S. county, and merges in two economic proxies - the FHFA Residential Land Price index for urban counties and the USDA Agricultural Land Value for rural counties - producing a per-course `Baseline_Value_Per_Acre` that anchors all subsequent analysis.

The urban–rural classification follows the 2023 USDA Rural-Urban Continuum Codes: counties scored 1–3 are treated as urban and receive the FHFA proxy, while counties scored 4–9 are treated as rural and receive the USDA proxy. The dual-proxy approach is a design choice I made deliberately. Applying a single residential proxy nationally would systematically overstate opportunity costs in rural markets where housing demand cannot support development; applying a single agricultural proxy nationally would understate the regulatory scarcity premium that defines urban land prices. The bifurcation lets each course be valued against the counterfactual that is plausible for its actual market.

The pipeline is implemented independently in **Python**, **R**, and **Julia**. All three stacks read identical source files (the raw golf CSV, the 2022 U.S. Census county boundaries via Tigris, the 2022 USDA NASS agricultural land values, the 2024 FHFA residential land prices, and the 2023 RUCC table) and produce independently named outputs prefixed `Py_`, `R_`, and `Jl_`. Cross-language convergence is the robustness check: any meaningful divergence in row counts, hit rates, or summary statistics signals a pipeline defect rather than a substantive finding.

## Key result

After the pipeline runs, 15,197–15,198 of the 16,297 courses have a complete baseline value, with the remaining ~1,095 courses missing either FIPS, USDA, or FHFA data. These are the imputation targets for Phase 3. The mean baseline value per acre converges to within five dollars across all three language implementations ($413,696 in R, $413,700 in Python, $413,701 in Julia), confirming statistical equivalence.

## What was solved

The most consequential bug fix was a silent FIPS zero-padding error: county FIPS codes coerced to integers lose their leading zeros (Alabama's `01001` became `1001`), which caused hundreds of USDA and FHFA join failures before I identified the fix. The fix enforces 5-digit zero-padded string formatting before every join across all three languages. This single correction tightened cross-language agreement substantially - pre-fix, R and Julia diverged from Python by 200+ rows on USDA hit rate; post-fix, R and Julia agree exactly and Python differs by only 39 rows attributable to a documented `geopandas` deduplication default.

Outputs flow forward into Phase 2 (polygon-based acreage extraction), Phase 3 (MICE imputation of the missing baseline values), and the regression model in Phase 4.