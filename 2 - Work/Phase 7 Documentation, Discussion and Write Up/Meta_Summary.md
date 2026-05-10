<div style="text-align: center; margin-top: 250px;">
  <h1>Meta Summary</h1>
  <h3>The Full Summary Statement for Each Phase</h3>
  <br><br>
  <p><strong>Michael</strong></p>
  <p>Econ 699 — Spring 2026</p>
</div>

<div style="page-break-after: always;"></div>

- [Phase 1 - Spatial Parsing \& Baseline Valuation](#phase-1---spatial-parsing--baseline-valuation)
  - [Key result](#key-result)
  - [What was solved](#what-was-solved)
- [Phase 2 - OSM Polygon Extraction, Acreage Matching](#phase-2---osm-polygon-extraction-acreage-matching)
  - [Key result](#key-result-1)
  - [What was solved](#what-was-solved-1)
- [Phase 3 - MICE Imputation \& Rubin's Rules Valuation](#phase-3---mice-imputation--rubins-rules-valuation)
  - [Key result](#key-result-2)
  - [What was solved](#what-was-solved-2)
- [Phase 4 - Econometric Modeling](#phase-4---econometric-modeling)
  - [Key result](#key-result-3)
  - [What was solved](#what-was-solved-3)
- [Phase 5 - Hawaii Micro-Study \& Empirical Validation](#phase-5---hawaii-micro-study--empirical-validation)
  - [Key result](#key-result-4)
  - [What was solved](#what-was-solved-4)
- [Phase 6 - Visualization and Viewable Ready Output](#phase-6---visualization-and-viewable-ready-output)
  - [Key result](#key-result-5)
  - [What was solved](#what-was-solved-5)
- [Phase 7 - Cross-Phase Synthesis](#phase-7---cross-phase-synthesis)
  - [The arc across the six computational phases](#the-arc-across-the-six-computational-phases)
  - [Why the design is shaped this way](#why-the-design-is-shaped-this-way)
  - [What follows from these findings](#what-follows-from-these-findings)
  - [Disclosure of generative AI tool use](#disclosure-of-generative-ai-tool-use)
    - [Web-hosted agents](#web-hosted-agents)
    - [Locally-hosted agents](#locally-hosted-agents)
    - [Hardware](#hardware)
    - [Statement of authorial responsibility](#statement-of-authorial-responsibility)

<div style="page-break-after: always;"></div>

# Phase 1 - Spatial Parsing & Baseline Valuation

Phase 1 builds the foundational dataset for the entire thesis. The pipeline ingests a raw CSV of 16,297 U.S. golf courses with GPS coordinates, spatially joins each course to its U.S. county, and merges in two economic proxies - the FHFA Residential Land Price index for urban counties and the USDA Agricultural Land Value for rural counties - producing a per-course `Baseline_Value_Per_Acre` that anchors all subsequent analysis.

The urban–rural classification follows the 2023 USDA Rural-Urban Continuum Codes: counties scored 1–3 are treated as urban and receive the FHFA proxy, while counties scored 4–9 are treated as rural and receive the USDA proxy. The dual-proxy approach is a design choice I made deliberately. Applying a single residential proxy nationally would systematically overstate opportunity costs in rural markets where housing demand cannot support development; applying a single agricultural proxy nationally would understate the regulatory scarcity premium that defines urban land prices. The bifurcation lets each course be valued against the counterfactual that is plausible for its actual market.

The pipeline is implemented independently in **Python**, **R**, and **Julia**. All three stacks read identical source files (the raw golf CSV, the 2022 U.S. Census county boundaries via Tigris, the 2022 USDA NASS agricultural land values, the 2024 FHFA residential land prices, and the 2023 RUCC table) and produce independently named outputs prefixed `Py_`, `R_`, and `Jl_`. Cross-language convergence is the robustness check: any meaningful divergence in row counts, hit rates, or summary statistics signals a pipeline defect rather than a substantive finding.

## Key result

After the pipeline runs, 15,197–15,198 of the 16,297 courses have a complete baseline value, with the remaining ~1,095 courses missing either FIPS, USDA, or FHFA data. These are the imputation targets for Phase 3. The mean baseline value per acre converges to within five dollars across all three language implementations ($413,696 in R, $413,700 in Python, $413,701 in Julia), confirming statistical equivalence.

## What was solved

The most consequential bug fix was a silent FIPS zero-padding error: county FIPS codes coerced to integers lose their leading zeros (Alabama's `01001` became `1001`), which caused hundreds of USDA and FHFA join failures before I identified the fix. The fix enforces 5-digit zero-padded string formatting before every join across all three languages. This single correction tightened cross-language agreement substantially - pre-fix, R and Julia diverged from Python by 200+ rows on USDA hit rate; post-fix, R and Julia agree exactly and Python differs by only 39 rows attributable to a documented `geopandas` deduplication default.

Outputs flow forward into Phase 2 (polygon-based acreage extraction), Phase 3 (MICE imputation of the missing baseline values), and the regression model in Phase 4.

<div style="page-break-after: always;"></div>

# Phase 2 - OSM Polygon Extraction, Acreage Matching

Phase 2 measures the physical footprint of each golf course. Phase 1 produced a per-course land value, but value-per-acre is meaningless without acreage, and the raw golf course CSV does not report it. To recover the missing dimension, Phase 2 extracts golf course boundary polygons from a national OpenStreetMap (OSM) extract and spatially matches them to the Phase 1 course list.

The OSM PBF file is approximately 11 GB and contains the entirety of mapped U.S. geography. The Python pipeline streams it directly via `pyosmium` to bypass GDAL corruption issues that occur on files of this size; R and Julia read the verified extraction Python produces, since I judged that independent PBF parsing in three languages would be wasteful and would produce inconsistent results. After extraction, all three languages reproject the polygons to EPSG:5070 (NAD83 / Conus Albers) so that acreage can be computed on a planar projection rather than in meaningless square degrees, then filter out mapping artifacts (polygons below 5 acres or above 1,500 acres) and compute true per-polygon acreage from the planar area.

The matching step joins the Phase 1 courses to these polygons via a two-pass strategy. The primary join is a direct `intersects` test: courses whose listed point coordinate falls inside an OSM polygon are matched directly. The fallback is a `nearest` join with a 500-meter cap, which captures the substantial fraction of courses where the listed coordinate refers to a clubhouse, parking lot, or driving range outside the mapped fairway. Together these two passes recover acreage for 71.2% of the course list (11,605 of 16,292), leaving the remaining 28.8% (4,687 courses) flagged as `MICE_Target` for imputation in Phase 3.

## Key result

The 15,166 retained polygons have a median area of 138 acres after matching, with a mean of 148 acres and a maximum of 1,327 acres. This distribution is the empirical foundation for Phase 3's imputation model: the MICE algorithm draws missing acreage values from a distribution shaped by the 11,605 directly measured courses, ensuring that imputed values follow the actual size structure of U.S. golf courses rather than collapsing toward a synthetic mean.

<br>
<br>

## What was solved

I implemented a complementary fallback against the U.S. Census Tigris landmarks dataset in R as a second-tier source for course polygons, but did not extend it to Python or Julia. Tigris underwent an API change between versions that made the national landmarks query require per-state iteration, and I judged the marginal recovery insufficient to justify the orchestration cost. R retains a three-tier `acreage_source` schema (`OSM` / `Tigris` / `MICE_Target`); Python and Julia carry a two-tier schema (`OSM` / `MICE_Target`). The downstream consequence is that Phase 3 scripts filter on `acreage_source != "MICE_Target"` rather than on a positive value, which keeps the imputation logic correct across all three implementations.

Outputs flow forward into Phase 3, which uses the 11,605 observed acreage values plus spatial and structural covariates to impute the missing 4,687.

<div style="page-break-after: always;"></div>

# Phase 3 - MICE Imputation & Rubin's Rules Valuation

Phase 3 closes the missing-data gap in the dataset and produces the headline national valuation. Two variables require imputation: the polygon-derived acreage (`osm_acreage`, 28.8% missing) and the economic baseline value (`Baseline_Value_Per_Acre`, 6.7% missing). The imputation method is Multiple Imputation by Chained Equations (MICE) with a Random Forest backend, and the resulting per-dataset estimates are pooled via Rubin's Rules to produce a national aggregate with a defensible confidence interval.

The pipeline runs MICE independently in **Python** (`miceforest` with a LightGBM gradient-boosted Random Forest), **R** (`mice` with `method = "rf"`), and **Julia** (`Mice.jl`). Each language produces $M = 100$ complete imputed datasets, yielding 300 imputed datasets in total across the tri-language design. I chose $M = 100$ over the $M = 5$ to $M = 10$ that early MICE literature recommended because the higher value follows modern guidance for stabilizing standard errors and eliminating Monte Carlo error, and is particularly important when the missing-data rate is as high as 28.8%. I preferred Random Forest over linear MICE backends because the relationship between course acreage and its predictors (number of holes, ownership type, urban/rural classification, latitude and longitude) is non-linear, and tree-based methods cannot produce impossible negative-valued imputations the way linear methods can.

Within each language, per-dataset opportunity costs are computed as `osm_acreage × Baseline_Value_Per_Acre` summed across courses, then pooled across the 100 imputations using Rubin's Rules: the pooled point estimate is the mean of the per-dataset sums, and the total variance combines within-imputation variance (the dispersion of estimates within a single completed dataset) and between-imputation variance (the dispersion of point estimates across the 100 datasets). The 95% confidence interval is the pooled estimate plus or minus 1.96 standard errors.

## Key result

All three languages converge on an aggregate national opportunity cost in the **$926B–$959B range**, with overlapping 95% confidence intervals: Python at $943.0B (CI: $936.3B–$949.7B), R at $936.0B (CI: $926.4B–$945.7B), and Julia at $951.4B (CI: $943.8B–$958.9B). The Grand Mean across the three implementations is approximately **$943 billion**. The cross-language spread of 1.6% on a ~$940B base is well within expected variation from independent Random Forest RNG seeds and internal MICE implementations, and is materially smaller than the natural between-imputation variance within any single language.

The diagnostic that between-imputation variance ($V_B$) is two to three orders of magnitude larger than within-imputation variance ($V_W$) confirms the model is well-specified: uncertainty in the aggregate estimate is driven by the genuine ambiguity of the missing values, not by measurement noise within any single completed dataset.

<br>
<br>
<br>
<br>
<br>
<br>
<br>
<br>

## What was solved

The Julia implementation initially failed with world-age errors when `Mice.jl` functions were defined and called in the same top-level script execution context. I refactored `Phase_3.jl` to use `Mice.jl`'s `mice()` and `complete()` APIs in the documented order, with imputation logic isolated in its own function scope. This fix was load-bearing for the cross-language validation: without a working Julia pipeline, the tri-language design would have collapsed to a Python-vs-R comparison, which would not have demonstrated robustness against backend-specific MICE implementation choices.

Phase 3 also produces a national acreage summary aggregating the imputed footprint by urban/rural classification. The pooled total is approximately 2.30 million acres, with 1.70 million in urban counties and 600,000 in rural counties. This summary is a sanity check on imputation stability rather than a primary research output, and feeds directly into the regression and visualization work in Phases 4 and 6.

Outputs flow forward into Phase 4 (regression analysis and marginal effects estimation) and ultimately into Phase 6 (visualization and table generation for the thesis).

<div style="page-break-after: always;"></div>

# Phase 4 - Econometric Modeling

Phase 4 fits a regression model that decomposes per-course opportunity cost into its structural and geographic determinants. The model is a logarithmic OLS regression with heteroskedasticity-robust (HC1) standard errors, fit independently on each of the 100 imputed datasets produced by Phase 3 and then pooled across imputations using Rubin's Rules. The result is a set of three statistically valid coefficient estimates per language (Python, R, Julia), with confidence intervals that correctly account for both within-imputation sampling variance and between-imputation imputation variance.

I deliberately specified a parsimonious model. The dependent variable is the natural log of per-course opportunity cost (`log(osm_acreage × Baseline_Value_Per_Acre)`), and the right-hand side carries two regressors: the number of holes (a continuous structural proxy for course size) and a binary indicator for whether the course sits in an urban county (RUCC 1–3 versus 4–9). I considered adding more covariates and rejected the addition: course type (public/private/municipal) and ownership type would have absorbed variance that the urban indicator already explains structurally, and including latitude/longitude would have produced spatial autocorrelation issues without methodologically clean correction. The specification I chose produces clean coefficient interpretations and tight cross-language convergence.

For each language, the pipeline runs in two steps: (1) fit OLS with HC1 robust standard errors on each of the 100 imputed datasets and serialize the coefficient and variance vectors; (2) pool across the 100 fits using Rubin's Rules to compute pooled point estimates, total variance ($V_T = V_W + (1 + 1/M) \cdot V_B$), pooled standard errors, Fraction of Missing Information (FMI), and Barnard-Rubin adjusted degrees of freedom. Each fit drops 34 rows with missing covariate data, leaving N = 16,258 observations per imputed dataset.

## Key result

The pooled regression produces three coefficient estimates that are extraordinarily consistent across the three languages. The Holes coefficient is approximately $\beta_1 \approx 0.05$ in all three (0.047 Python, 0.053 R, 0.048 Julia), implying that each additional hole increases log opportunity cost by about 5%. The urban indicator coefficient is approximately $\beta_2 \approx 4.0\text{--}4.2$ in all three (4.172 Python, 4.001 R, 4.158 Julia), implying that an urban course's opportunity cost is roughly $\exp(4.1) \approx 60$ times that of a comparable rural course on a per-acre basis. All coefficients are statistically significant at $p < 0.001$ in every language. The model $R^2$ ranges from 0.70 (R) to 0.77 (Python), with the variation attributable to differences in the underlying MICE imputation backends across the three stacks.

The 60× urban-rural ratio is partially mechanical: the hybrid valuation algorithm in Phase 1 assigns urban courses the FHFA residential price and rural courses the USDA agricultural price, and the FHFA-USDA per-acre ratio is itself approximately 60× in many counties. The regression is therefore best read as a *decomposition* of the bifurcated baseline rather than a causal estimate of how a course's value would change if it were relocated across the rural-urban boundary. I treat this interpretive caveat as important and carry it forward into the thesis prose in Section 5.3.

<br>
<br>
<br>
<br>

## What was solved

The Julia HC1 implementation required hand-rolling the sandwich estimator because `GLM.jl` did not expose a direct robust-covariance API at the version pinned for this project. My fix computes `(n/(n-k)) · (X'X)⁻¹ · X' · diag(ê²) · X · (X'X)⁻¹` directly from the model matrix and residuals returned by `GLM.lm`, matching the HC1 formula used by `statsmodels` in Python and `sandwich::vcovHC` in R. The resulting Julia standard errors agree with R and Python to within rounding error across all three coefficients.

Outputs flow forward into Phase 5 (Hawaii micro-study), which uses Phase 4's per-course pooled estimates to compare model HBU values against parcel-level tax assessments, and into Phase 6, which generates the forest plot, marginal-effects chart, and other visualizations from the pooled regression results.

<div style="page-break-after: always;"></div>

# Phase 5 - Hawaii Micro-Study & Empirical Validation

Phase 5 is the empirical anchor of the thesis. The earlier phases produce a national-scale opportunity cost figure derived from federal land-valuation datasets, but the figure has no parcel-level reality check until Phase 5 runs. The Hawaii micro-study integrates the national pipeline outputs with parcel-level cadastral, tax-roll, and zoning data published by the City and County of Honolulu, then asks two questions: how closely does the model's HBU estimate align with what municipal assessors actually report on the tax rolls, and how much of the modeled opportunity cost is bounded by current zoning law?

The phase is organized as two complementary tracks. **Phase 5a** is a manual pilot validation: six high-profile Hawaii golf courses spanning all four counties (Honolulu, Maui, Hawaii, Kauai) are individually compared against their 2022 tax assessment values, which I computed by hand to allow careful per-course interpretation. **Phase 5b** is a six-step automated pipeline implemented in all three languages: it processes every golf course on Oahu at parcel resolution, intersecting OSM golf polygons with the Honolulu cadastre to identify the Tax Map Keys (TMKs) that constitute each course, pooling economic estimates across $M = 100$ MICE imputations per language via Rubin's Rules, and intersecting each parcel with the Honolulu zoning layer to determine its dominant land-use classification.

The data integration is non-trivial. Honolulu's cadastral and zoning GeoPackages are distributed in EPSG:3760 (NAD83(HARN) Hawaii Zone 3, US survey feet), which must be reprojected to EPSG:5070 to align with the national pipeline. The cadastre contains parent parcels and CPR (Condominium Property Regime) sub-parcels; I designed the pipeline to filter to parent parcels only, since CPRs are unit-level subdivisions of a single physical parcel and would inflate the count. The OSM-derived golf polygons cover only 31.4% of the Phase 1 course points via direct point-in-polygon match, with the remainder requiring spatial intersection against the cadastre to recover the parcels each course occupies.

## Key result

The Phase 5a pilot produces an average model-to-assessed ratio of **1.33×** across the six courses, indicating that the national HBU model systematically exceeds going-concern tax assessments by roughly one-third. The ratio is narrowest in urban Honolulu (Waialae Country Club at 1.16×, Turtle Bay Resort at 1.23×) and widest in rural Big Island courses (Kohala Country Club at 1.49×, Hualalai Golf Club at 1.69×). This pattern is consistent with the FHFA urban residential proxy more closely tracking municipal assessment practice than the USDA rural agricultural proxy does, and provides a defensible empirical anchor for the gap between gross HBU and going-concern current-use value.

Phase 5b produces an aggregate Oahu opportunity cost of **$25.4B** under Rubin's Rules pooling (95% CI: $22.7B–$28.1B), distributed across **1,072 unique TMK parcels** comprising 33 deduplicated golf courses. The geographic distribution is striking: **63.2% of the parcels (677 of 1,072) sit in the Ewa District (Zone 9)**, the suburban housing development corridor running through Kapolei, Pearl City, and Ewa Beach. This concentration directly co-locates Oahu's golf footprint with the island's primary vector for new residential development, sharpening the policy stakes of the unrealized opportunity cost.

The most consequential finding emerges from the Step 6 zoning intersection. **81.7% of all Oahu golf land sits within Preservation (P-1, P-2) or Federal/Military (F-1) zones** - areas where residential redevelopment is, under current zoning, statutorily prohibited. Only roughly 4.5% of the footprint sits in Resort, Residential, or Country zones where redevelopment to housing would be legally compatible with existing zoning. A complementary penetration finding shows that golf occupies **25.4% of all Resort-zoned land on Oahu** - the highest penetration rate of any zone class on the island - indicating that golf is not an incidental amenity within resort zoning but is the dominant land use in that classification.

Together these findings produce what I call the **Preservation Paradox**: the unrestricted gross HBU framework computes large opportunity costs precisely on land that current zoning cannot release, while the small share of golf land in zones permitting redevelopment carries a correspondingly small share of the realizable economic potential.

## What was solved

Two integration challenges were load-bearing for the result. First, the OSM golf polygons and the Honolulu cadastre use different coordinate reference systems, different polygon edge conventions, and different feature granularities - OSM treats a golf course as a single multipolygon while the cadastre breaks the same physical course into dozens of TMK parcels. My fix is the cookie-cutter intersection in Step 2, which assigns each parcel its OSM golf overlap acreage and produces a clean parcel-to-course mapping. Second, R's `sf::st_intersection` reports the P-1 (Restricted Preservation) overlap acreage as 523.5 acres, while Python and Julia report 744.6 acres. The discrepancy reflects edge-case polygon-boundary handling in `sf` versus GDAL/Shapely; I use the Python/Julia results as canonical for the headline figures while retaining R as a cross-check. All other zone classes agree across the three languages to within 0.1 acres.

Outputs flow forward into Phase 6, which generates the Hawaii Gap dumbbell chart, the TMK concentration map, the zoning composition waffle chart, and the other Hawaii-specific visualizations that anchor the thesis's Section 5.4. The Phase 5 findings are also the empirical foundation for the legally-permissible HBU framework introduced in Section 3.3 of the thesis: $V_{OC}^{\text{legal}} \leq V_{OC}^{\text{gross}}$, with the gap between the two bounded by the share of acreage in zones that legally permit the unrestricted use.

<div style="page-break-after: always;"></div>

# Phase 6 - Visualization and Viewable Ready Output

Phase 6 turns the numerical results from Phases 1 through 5 into the figures, maps, and LaTeX table fragments that appear in the thesis. The phase produces approximately 30 publication-ready outputs across two computational stacks: **R** handles all spatial and cartographic output (national choropleths, county-level opportunity cost maps, Oahu micro-maps, bivariate cost-versus-density maps, and the zoning intersection map), and **Julia** handles all non-spatial output (forest plots, MICE density convergence diagnostics, marginal effects charts, raincloud diagnostics, the Hawaii Gap dumbbell, the Lorenz curve, the Preservation Paradox waffle chart, the counterfactual area comparison, and the LaTeX table fragments for direct `\input{}` into the thesis source).

I deliberately do not use Python in Phase 6. After comparison runs across all three candidate languages, R's `sf` + `ggplot2` + `tigris` stack produced consistently better cartographic output than `geopandas` + `matplotlib`, and Julia's `CairoMakie` produced cleaner statistical plots than Python's `matplotlib` or `seaborn` for the chart types this thesis requires. I therefore break the strict tri-language parity rule that governs Phases 1 through 5, in favor of producing better-looking output. The numerical inputs to Phase 6 are still tri-language: each chart that displays per-language results does so by reading the Python, R, and Julia outputs from earlier phases independently, with the Grand Mean computed as the arithmetic mean across the three Rubin-pooled estimates.

The phase is organized as two master scripts (`Phase_6.R` and `Phase_6.jl`) that orchestrate seven R modules and seven Julia modules respectively. Each module is self-contained and produces its own labeled output set under `Final_Thesis_Figures/`. The figure naming convention encodes both the chart number and the version (`5_141_Forest_Plot_Combined.png` for Forest Plot version 1.41, `12_141_Zoning_Waffle_Chart_TriLanguage.png` for Zoning Waffle Chart version 1.41), which lets the thesis prose reference figures stably even as visualization choices iterate.

## Key result

The headline figures generated by Phase 6 are the load-bearing visual evidence of the thesis:

- **National opportunity cost maps** (county-level, both Grand Mean and observed-only, plus state-level versions of each) make the spatial concentration in California, Florida, New York, Texas, and Hawaii immediately legible.
- **Forest plot of regression coefficients** displays Python, R, and Julia coefficients side by side with 95% confidence intervals, demonstrating tri-language convergence to within visual indistinguishability for the Holes coefficient and the urban indicator.
- **MICE density convergence sequence** (n=20 → 40 → 60 → 80 → 100) shows the imputed acreage distribution converging on the observed parcel distribution as $M$ increases, justifying the choice of $M = 100$ visually rather than just computationally.
- **Hawaii Gap dumbbell chart** displays each Oahu course as a horizontal segment from its agricultural-floor value (USDA × acreage) to its HBU model value (FHFA × acreage, Rubin-pooled), making the per-course zoning tax visible as a length on the chart.
- **Preservation Paradox waffle chart** decomposes the $28.6B Oahu opportunity cost by zoning class, showing visually that the bulk of the modeled value sits in zones where redevelopment is statutorily prohibited.
- **Lorenz curve** of per-course opportunity cost shows the high inequality of the distribution: a small share of urban courses dominates the national aggregate.

Three LaTeX table fragments (`Table1_Acreage`, `Table2_Regression`, `Table3_Hawaii_Geo`) are also generated by Julia in this phase and are dropped directly into the thesis source via `\input{}`, eliminating any manual transcription step between the analytical outputs and the published document.

## What was solved

The most consequential standardization decision I made in Phase 6 was that the Grand Mean across the three languages is computed as the arithmetic mean of three independently Rubin-pooled estimates, not as a Rubin pool over the combined 300 imputed datasets. The two procedures are not equivalent: pooling Rubin's Rules across all 300 imputations would treat the three languages as drawing from the same underlying imputation distribution, which they are not. Each language uses a different MICE backend (LightGBM in Python, Random Forest in R, `Mice.jl` in Julia), and the Grand Mean is intentionally an *across-implementation* average that demonstrates robustness to backend choice. I propagate this methodological clarification through all charts and tables that display the Grand Mean alongside per-language Rubin pools.

A persistent Map 15.1 issue (log-residual choropleth rendering all-gray due to NaN log-residual range) is documented but not blocking - the dollar-residual map is unaffected and is the version used in the thesis. The bug is a pre-existing computation issue rather than a Phase 6 regression.

Outputs from Phase 6 feed directly into the thesis manuscript, bypassing Phase 7's traditional role as a separate "documentation" stage. The thesis figures and tables in Section 5 are not reproductions of Phase 6 output; they are exactly the files Phase 6 generates.

<div style="page-break-after: always;"></div>

# Phase 7 - Cross-Phase Synthesis

Phase 7 is the meta-phase: it does not run new analyses or produce new outputs. Instead, it captures the arc that ties Phases 1 through 6 into a single coherent research project, and frames the work for readers landing on this repository for the first time.

The thesis answers two coupled questions. The first is **macroeconomic**: what is the aggregate financial opportunity cost of U.S. golf courses when each course is valued at its Highest and Best Use (HBU) counterfactual instead of its current recreational use? The second is **methodological**: when that national-scale HBU model is validated against parcel-level municipal records in a single high-value coastal county, does the model's estimate hold up, and what share of the modeled opportunity cost is actually unlockable under current zoning law? The answer to the first is approximately **$944 billion**, with an observed-only floor of **$788 billion**. The answer to the second is that the model exceeds municipal tax assessments by a factor of approximately **1.33×** in the Hawaii pilot, and that **81.7% of Oahu's golf footprint sits in Preservation or Federal/Military zones** where redevelopment is currently statutorily prohibited.

These two answers are the load-bearing findings of the thesis. Everything between them is a pipeline that produces them defensibly.

## The arc across the six computational phases

**Phase 1** ingests a raw CSV of 16,297 U.S. golf courses with GPS coordinates and produces a per-course `Baseline_Value_Per_Acre` by spatially joining each course to its U.S. county and merging in two economic proxies - the FHFA Residential Land Price index for urban counties (RUCC 1–3) and the USDA Agricultural Land Value for rural counties (RUCC 4–9). This dual-proxy approach is the methodological foundation of the entire project: it is what allows the same HBU framework to apply to a Manhattan urban course and a rural Iowa course without nationally over- or under-stating opportunity cost.

**Phase 2** measures each course's physical footprint by extracting golf course boundary polygons from an 11 GB OpenStreetMap PBF file and spatially matching them to the Phase 1 course list. A two-pass spatial join (direct intersect, then nearest-neighbor with a 500-meter cap) recovers acreage for 71.2% of the courses, leaving 28.8% flagged as imputation targets.

**Phase 3** closes the missing-data gap. Multiple Imputation by Chained Equations (MICE) with a Random Forest backend, run independently in three languages with $M = 100$ imputations per language and pooled via Rubin's Rules, produces the headline national aggregate of approximately $944 billion. The cross-language spread of 1.6% on a $940B base, with overlapping 95% confidence intervals across all three implementations, is the robustness check that justifies trusting the figure.

**Phase 4** decomposes the per-course opportunity cost into its structural and geographic determinants via a logarithmic OLS regression with HC1 robust standard errors, fit on each of the 100 imputed datasets per language and pooled via Rubin's Rules. The two-covariate model (Holes + Urban indicator) produces coefficients that are extraordinarily consistent across the three languages: the urban coefficient is approximately $\beta_2 \approx 4.0$–$4.2$ in all three, implying that urban courses are valued at approximately 60× rural courses on a per-acre basis.

**Phase 5** is the empirical anchor. The Honolulu County micro-study integrates the national pipeline outputs with parcel-level cadastral, tax-roll, and zoning data published by the City and County of Honolulu, producing the 1.33× model-to-assessed ratio (the gross-vs-current-use anchor) and the 81.7% Preservation/Federal share (the legally-permissible HBU bound). The Phase 5b automated pipeline operates at parcel resolution across 1,072 unique TMK parcels and 33 deduplicated Oahu courses, producing an aggregate Oahu opportunity cost that aligns closely with what the national pipeline predicts for Honolulu County independently.

**Phase 6** transforms the numerical outputs into publication-ready figures, maps, and LaTeX table fragments. R produces the cartographic output (national choropleths, Oahu maps, bivariate maps); Julia produces the statistical charts (forest plot, density diagnostics, Hawaii Gap dumbbell, Preservation Paradox waffle, Lorenz curve) and the LaTeX table fragments that drop directly into the thesis source.

## Why the design is shaped this way

Three structural choices distinguish this project from a more typical single-language land-use econometric study, and each is deliberate.

**Tri-language implementation across Phases 1 through 5.** Every step from data ingestion through the Hawaii micro-study is implemented independently in Python, R, and Julia. The point is robustness rather than redundancy: any divergence in aggregate estimates across the three languages signals a pipeline defect rather than a substantive empirical finding, and the cross-language convergence on $943B / $936B / $951B (with overlapping 95% CIs) is what gives the headline figure its defensibility against backend-specific implementation choices in MICE, OLS, or spatial join routines.

**Explicit two-scale design.** The national pipeline establishes breadth across 16,297 courses and 50 states; the Hawaii micro-study establishes depth at parcel resolution within a single county. Neither alone would carry the thesis: a national figure with no parcel-level anchoring would be a theoretical exercise, and a Hawaii-only study would be too small to support a national policy conclusion. The two scales are complementary, with the national pipeline's geographic resolution validated by the Hawaii pipeline's parcel-level checks.

**Honest treatment of what the model does and does not measure.** The national-scale figure is the *gross HBU counterfactual*, not the net opportunity cost. The current-use value $V_{Current}$ is not directly observable in federal land valuation datasets, so the headline figure is an upper bound until empirically anchored against the Hawaii tax-assessment data. Similarly, the unrestricted HBU is bounded by the legally-permissible HBU once zoning is taken into account, and the Preservation Paradox finding establishes that the unrestricted figure substantially overstates the realizable opportunity cost in at least one high-value market. The thesis carries both figures and is explicit about the gap between them.

## What follows from these findings

Three directions for follow-on research are explicit in the thesis. First, the Phase 5b zoning intersection methodology should be replicated in other high-value coastal markets - the Bay Area, Los Angeles, southern Florida, the New York metro - to test whether the Preservation Paradox documented on Oahu generalizes. Second, $V_{Current}$ should be measured directly using transaction data from the National Golf Foundation or income-capitalization methods, refining the 1.33× Hawaii anchor into a market-specific net opportunity cost. Third, a renewable energy counterfactual ($V_{Renewable}$) should be integrated formally into the HBU framework as a third candidate use, particularly relevant in arid urban environments where the ecological cost of maintaining turf is high.

The dataset, the pipeline, and the validation logic are all structured to support these extensions without re-architecting the project.

## Disclosure of generative AI tool use

For academic transparency, the following large language models contributed to this project at various points in its development. The models are organized into web-hosted agents (where queries traverse a third-party cloud provider) and locally-hosted agents (where inference runs on my own hardware), reflecting the different confidentiality and reproducibility implications of each.

### Web-hosted agents

- **Claude Opus 4.7** - Anthropic - accessed via the Claude web app on a Windows 11 PC. Used as a writing aid, redundancy checker, and structural reviewer; ideas and draft passages were exchanged with the model to surface critical flaws or productive next directions.
- **Claude Sonnet 4.6** - Anthropic - accessed via the Claude web app on a Windows 11 PC. Used for code verification and bug-fixing across the Python, R, and Julia pipelines.
- **Gemini 2.5 Pro** - Google - accessed via Google AI Studio web app on a Windows 11 PC. Used as a research-management assistant, primarily to track sources, document why each was used, and maintain a working index of the project's reference material.
- **Gemini 3.1 Pro** - Google - accessed via Google AI Studio web app on a Windows 11 PC. Used as a writing aid, redundancy checker, and structural reviewer; complementary to Claude Opus 4.7 to provide a second model's perspective on draft passages and analytical decisions.

### Locally-hosted agents

All locally-hosted models run on the FishTex Nimo PC system specified below, with inference handled by `llama.cpp` (Vulkan, ROCm, and CUDA backends) under Fedora 43 Server.

- [**Kimi-Dev-72B (Q8_K_XL)**](https://huggingface.co/unsloth/Kimi-Dev-72B-gguf) - Moonshot AI, with quantization by unsloth. Used for code writing, scaffolding new functions, validation, and error correction.
- [**Qwen3-Coder-Next (UD Q8_K_XL)**](https://huggingface.co/unsloth/Qwen3-Coder-Next-gguf) - Alibaba, with quantization by unsloth. Used for code writing, scaffolding, validation, and error correction; complementary to Kimi-Dev-72B as a second-opinion code generator.
- [**GPT-OSS-120B Heretic (Q8_0)**](https://huggingface.co/bartowski/kldzj_gpt-oss-120b-heretic-GGUF) - OpenAI base **weights** with kldzj fine-tune, distributed via Bartowski. Used as a fully private personal assistant for thought processing and information tracking - the locally-hosted counterpart to the web-hosted Gemini 2.5 Pro role.
- [**Qwen2.5-Coder-1.5B-Instruct (Q8_0)**](https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF) - Alibaba, with quantization by Bartowski. Used for in-editor text prediction and ghost-text autocomplete as a Copilot replacement; runs on the 3060ti via the Thunderbolt 4 eGPU dock for low-latency response.
- [**Granite-4.0-H-Tiny (Q5_K_M)**](https://huggingface.co/ibm-granite/granite-4.0-h-tiny-GGUF) - IBM Research. Used for in-editor text prediction and ghost-text autocomplete as a Copilot replacement; complementary to Qwen2.5-Coder-1.5B and likewise runs on the 3060ti via the Thunderbolt 4 eGPU dock.

<br>
<br>
<br>
<br>

### Hardware

**FishTex** - [Nimo PC AMD Ryzen AI Max 395 system](https://www.nimopc.com/products/nimo-ai-mini-pc-amd-ryzen-ai-max-395-128gb-ram?variant=47848771846395); 128 GB LPDDR5 RAM at 8000 MHz; 2 × 2 TB NVMe SSDs (WD Black for OS, Crucial P3 for `.gguf` model storage); Fedora 43 Server; `llama.cpp` with Vulkan, ROCm, and CUDA backends; supporting software including Docker, OpenWebUI, and SSH; a Gigabyte 3060ti Vision 8 GB GPU connected via Thunderbolt 4 to a Razer Core X eGPU dock for the small autocomplete models.

The remaining three machines below are my general work environments; they were used for thesis writing, code editing, and analytical work but did not host any local LLM inference.

**PadTex** - Lenovo P52; Xeon E2176M; 56 GB SODIMM DDR4 (3 × 16 GB + 8 GB); 500 GB Samsung MZVLB512HAJQ + Sabrent Rocket 4.0 2 TB; Quadro P2000; Intel AX210 Wi-Fi; Windows 11 25H2 with AtlasOS modifications.

**ThinkTex** - Lenovo L15; AMD Ryzen 5 PRO 4650U; 24 GB SODIMM DDR4 (16 GB + 8 GB); 512 GB Kioxia XG6 KXG60ZNV512G; Windows 11 25H2 with AtlasOS modifications.

**MikTex** - Custom tower PC; AMD Ryzen 9 3900XT; Gigabyte B550M Aorus Elite (Rev. 1.3); DarkRock D360 liquid cooler; Lian Li A3 case; Montech Centru II 1050 W PSU; Quadro P2000 5 GB; 64 GB G.Skill Ripjaws V DDR4 (2 × 32 GB at 3600 MHz CL18); 1 TB Sabrent Rocket 4.0.

The majority of the data processing and code authorship was conducted on **MikTex**, with lighter analytical work performed on **PadTex** as a portable alternative. **ThinkTex** served primarily as a portable client to SSH into the FishTex or MikTex systems for remote work.

### Statement of authorial responsibility

Final responsibility for all analytical decisions, data interpretation, empirical claims, and prose authorship rests with me. The use of these tools is disclosed here in keeping with emerging academic norms around AI assistance. Citation formats for individual model contributions will be finalized in alignment with the requirements of the eventual publication venue.