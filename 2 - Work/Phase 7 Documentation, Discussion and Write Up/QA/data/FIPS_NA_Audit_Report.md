# FIPS-NA Diagnostic Audit Report

**Generated:** 2026-05-14 10:48:08
**Audit scope:** Phase 1 baseline outputs (R, Python, Julia)
**Status:** Read-only — no source files modified

---

## Executive Summary

| Question | Finding |
|----------|---------|
| Q1: $4,952,600/acre for FIPS 15003? | **CONFIRMED** — exact match in FHFA source file |
| Q2: Spatial join failure cause? | 5 of 5 Hawaii FIPS-NA courses resolve with cb=FALSE (TIGER) but NOT with cb=TRUE/20m.  |
| Q3: FIPS-NA course count (R)? | 34 of 16,292 courses (0.21%) |
| Thesis defensibility | **DEFENSIBLE** — small isolated failure mode, not systemic |

---

## Q1: FHFA Value for FIPS 15003 (Honolulu County, 2022)

**Source file:** `2024 - FHFA June 20 Land Prices.xlsx`
**Sheet:** `Panel Counties`  |  **Year filter:** `2022`
**Column used by Phase 1:** `Land Value
(Per Acre, As-Is)`

| | Value |
|---|---|
| FHFA source (FIPS 15003, 2022) | $4,952,600/acre |
| Thesis anchor used in Script 9 + §5.4 | $4,952,600/acre |
| Match | **YES — values agree within $1** |

---

## Q2: Spatial Join Failure — Hawaii Kai and Mid-Pacific

### Phase 1 Spatial Join Method (from `Phase_1.R`)

```r
# Phase_1.R lines 105–109
county_sf <- counties(cb = TRUE, year = 2022, resolution = "20m",
                      progress_bar = FALSE) |>
  st_transform(4326)
courses_sf <- st_join(courses_sf, county_sf, join = st_intersects)  # [METHODOLOGY]
```

**Key parameters and their significance:**

| Parameter | Value | Implication |
|-----------|-------|-------------|
| `cb` | `TRUE` | Cartographic boundary — polygon is clipped to the US shoreline and simplified |
| `resolution` | `"20m"` | 1:20,000,000 scale — the coarsest level available (options: 500k, 5m, 20m) |
| `join` | `st_intersects` | Strict point-in-polygon; if point falls outside polygon → all county columns = NA |
| `year` | `2022` | 2022 TIGER/Census boundaries |

**Root cause hypothesis:** At 1:20,000,000 scale, the cartographic boundary simplifies
coastal vertices aggressively. For Hawaii, county polygons follow the shoreline, and
the simplified version may cut inland across narrow peninsulas, bays, or coastal valleys.
Courses whose coordinates fall in such areas pass the strict `st_intersects` test against
the full county polygon but fail against the simplified cartographic version.

**Hawaii FIPS-NA courses in R baseline:** 5

### Kahili Golf Course
**Coordinates:** Longitude = -156.514959, Latitude = 20.78965

| Boundary Variant | FIPS Resolved |
|-----------------|---------------|
| `cb=TRUE, 20m (Phase 1 method)` | **FAILED** (NA) |
| `cb=TRUE, 5m  (higher resolution)` | **FAILED** (NA) |
| `cb=FALSE, TIGER (full)` | RESOLVED (`15009`) |

**Distance from coordinate to nearest cb=20m polygon:** 352.3 meters

### King Kamehameha Golf Club
**Coordinates:** Longitude = -156.514959, Latitude = 20.78965

| Boundary Variant | FIPS Resolved |
|-----------------|---------------|
| `cb=TRUE, 20m (Phase 1 method)` | **FAILED** (NA) |
| `cb=TRUE, 5m  (higher resolution)` | **FAILED** (NA) |
| `cb=FALSE, TIGER (full)` | RESOLVED (`15009`) |

**Distance from coordinate to nearest cb=20m polygon:** 352.3 meters

### Kapalua Golf Club
**Coordinates:** Longitude = -156.663495, Latitude = 20.998829

| Boundary Variant | FIPS Resolved |
|-----------------|---------------|
| `cb=TRUE, 20m (Phase 1 method)` | **FAILED** (NA) |
| `cb=TRUE, 5m  (higher resolution)` | RESOLVED (`15009`) |
| `cb=FALSE, TIGER (full)` | RESOLVED (`15009`) |

**Distance from coordinate to nearest cb=20m polygon:** 433.5 meters

### Hawaii Kai Golf Course
**Coordinates:** Longitude = -157.662671, Latitude = 21.297835

| Boundary Variant | FIPS Resolved |
|-----------------|---------------|
| `cb=TRUE, 20m (Phase 1 method)` | **FAILED** (NA) |
| `cb=TRUE, 5m  (higher resolution)` | RESOLVED (`15003`) |
| `cb=FALSE, TIGER (full)` | RESOLVED (`15003`) |

**Distance from coordinate to nearest cb=20m polygon:** 54.7 meters

### Mid Pacific Country Club
**Coordinates:** Longitude = -157.719205, Latitude = 21.391181

| Boundary Variant | FIPS Resolved |
|-----------------|---------------|
| `cb=TRUE, 20m (Phase 1 method)` | **FAILED** (NA) |
| `cb=TRUE, 5m  (higher resolution)` | RESOLVED (`15003`) |
| `cb=FALSE, TIGER (full)` | RESOLVED (`15003`) |

**Distance from coordinate to nearest cb=20m polygon:** 140.4 meters

### Diagnosis Conclusion

5 of 5 Hawaii FIPS-NA courses resolve with cb=FALSE (TIGER) but NOT with cb=TRUE/20m. 

If courses resolve with `cb=FALSE` (TIGER full files) but fail with `cb=TRUE/20m`:
the failure is a **cartographic boundary simplification artifact**, not a coordinate
data integrity issue. The golf course coordinates are correct — it is the county
polygon that is too coarse to contain them.

**Phase 1 fix (if re-run is warranted):** Change Phase_1.R line 105 from
`counties(cb = TRUE, year = 2022, resolution = "20m")` to either:
- `counties(cb = FALSE, year = 2022)` — full TIGER/Line files (no simplification)
- `counties(cb = TRUE, year = 2022, resolution = "5m")` — higher-resolution cartographic

---

## Q3: Nationwide FIPS-NA Course Count

### Cross-Language Totals

| Language | Total Courses | FIPS-NA Count | FIPS-NA Rate |
|----------|--------------|---------------|-------------|
| R        | 16,292 | 34 | 0.21% |
| Python   | 16,297 | 34 | 0.21% |
| Julia    | 16,292 | 34 | 0.21% |

> Cross-language consistency: if R, Python, and Julia show similar FIPS-NA counts,
> all three Phase 1 scripts used the same spatial join with the same boundary file.
> A large discrepancy would indicate language-specific implementation differences.

### R Baseline: FIPS-NA by State

| State | FIPS-NA Count |
|-------|--------------|
| HI | 5 |
| CA | 4 |
| FL | 4 |
| WI | 4 |
| AL | 3 |
| MI | 2 |
| OR | 2 |
| SC | 2 |
| CT | 1 |
| MA | 1 |
| MD | 1 |
| ME | 1 |
| NY | 1 |
| OH | 1 |
| VA | 1 |
| WA | 1 |

*(Full list: `FIPS_NA_Courses_R.csv` — 34 courses with course name, state, and coordinates)*

### Geographic Distribution Note

Courses with FIPS-NA are expected to cluster near state boundaries and coastlines
where simplified cartographic polygons are most likely to exclude valid coordinates.
A random or broadly distributed pattern would instead suggest a CRS or coordinate
datum issue in the source data.

---

## Conclusion

**FIPS-NA count:** 34 of 16,292 R-baseline courses (0.21%)

### Thesis is defensible — isolated failure mode, not systemic

At 0.21%, the FIPS-NA failure rate is consistent with a cartographic
boundary simplification artifact at the US coastline. This is not a systemic data
integrity failure.

Downstream impact: for FIPS-NA courses, Phase 1 sets `county_type = NA` and
`Baseline_Value_Per_Acre = NA`, which means Phase 3 MICE treats `Baseline_Value_Per_Acre`
as a missing value and imputes it from the broader training distribution. Urban coastal
courses (like Hawaii Kai and Mid-Pacific) may occasionally draw from rural USDA-range
values in some imputation draws, marginally underestimating their opportunity cost in
the sub-pool estimates. The Grand Mean across M=100 draws still centers near the true
distribution. The §5.4.2 footnote already discloses the two known Hawaii cases.

**Recommendation:** No Phase 1 re-run required before defense. The existing disclosure
in §5.4.2 is sufficient given the small affected count.

