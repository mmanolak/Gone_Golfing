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