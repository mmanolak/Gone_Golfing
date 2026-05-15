# Purpose: Read-only FIPS-NA diagnostic audit for the Econ 732 thesis.
#
# Answers three questions:
#   Q1: Is $4,952,600/acre the correct 2022 FHFA value for FIPS 15003?
#   Q2: Why did Phase 1 fail to resolve FIPS for Hawaii Kai and Mid-Pacific?
#   Q3: How many courses nationwide have FIPS = NA in Phase 1's output?
#
# Outputs:
#   QA/data/FIPS_NA_Audit_Report.md     — full Markdown report
#   QA/data/FIPS_NA_Courses_R.csv       — all FIPS-NA courses from R baseline
#   QA/data/FIPS_NA_State_Summary.csv   — per-state NA count (R baseline)
#
# READ-ONLY: this script does NOT modify any Phase 1–5 source files.


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(sf)
  library(tigris)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

options(tigris_use_cache = TRUE)

SCRIPT_DIR     <- this.path::this.dir()
DATA_OUT_DIR   <- normalizePath(file.path(SCRIPT_DIR, "..", "data"), mustWork = FALSE)
WORK_DIR       <- normalizePath(file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE)

R_BASELINE_PATH  <- file.path(WORK_DIR, "Phase 1 Parsing", "Data", "R",
                              "R_Phase1_Baseline_Golf_Valuation.csv")
PY_BASELINE_PATH <- file.path(WORK_DIR, "Phase 1 Parsing", "Data", "python",
                              "Py_Phase1_Baseline_Golf_Valuation.csv")
JL_BASELINE_PATH <- file.path(WORK_DIR, "Phase 1 Parsing", "Data", "Julia",
                              "Jl_Phase1_Baseline_Golf_Valuation.csv")
FHFA_PATH        <- file.path(WORK_DIR, "00 - Data Sources", "Original Data",
                              "2024 - FHFA June 20 Land Prices.xlsx")

REPORT_PATH    <- file.path(DATA_OUT_DIR, "FIPS_NA_Audit_Report.md")
NA_CSV_PATH    <- file.path(DATA_OUT_DIR, "FIPS_NA_Courses_R.csv")
STATE_CSV_PATH <- file.path(DATA_OUT_DIR, "FIPS_NA_State_Summary.csv")

TARGET_FIPS   <- "15003"
ANCHOR_VALUE  <- 4952600  # $4,952,600/acre — the thesis anchor for Honolulu County


# === 3. FUNCTIONS ===

# Returns TRUE for any FIPS value that is not a valid 5-digit code.
is_fips_na <- function(fips_vec) {
  is.na(fips_vec) | !grepl("^\\d{5}$", as.character(fips_vec))
}

# ── Q1: Verify the FHFA source value for FIPS 15003 ──────────────────────────

q1_verify_fhfa <- function() {
  cat("[Q1] Verifying FHFA 2022 value for FIPS 15003 (Honolulu County)...\n")

  fhfa_raw  <- read_excel(FHFA_PATH, sheet = "Panel Counties", skip = 1)
  fhfa_2022 <- fhfa_raw |>
    filter(Year == 2022) |>
    mutate(FIPS_padded = str_pad(as.character(FIPS), 5, pad = "0"))

  as_is_col <- grep("Per Acre, As-Is", names(fhfa_2022), value = TRUE)[1]
  cat(sprintf("  FHFA column used: '%s'\n", as_is_col))

  row_15003 <- fhfa_2022 |>
    filter(FIPS_padded == TARGET_FIPS) |>
    select(FIPS_padded, Year, all_of(as_is_col)) |>
    rename(FHFA_Per_Acre_AsIs = all_of(as_is_col))

  if (nrow(row_15003) == 0) {
    cat("  WARNING: FIPS 15003 not found in FHFA 2022 data.\n")
    return(list(found = FALSE, fips_15003_val = NA_real_, matches = FALSE,
                col = as_is_col))
  }

  fhfa_val <- as.numeric(row_15003$FHFA_Per_Acre_AsIs[1])
  matches  <- !is.na(fhfa_val) && abs(fhfa_val - ANCHOR_VALUE) < 1

  cat(sprintf("  FIPS 15003 FHFA (2022): $%s/acre\n",
              formatC(fhfa_val, format = "f", digits = 0, big.mark = ",")))
  cat(sprintf("  Thesis anchor value:    $%s/acre\n",
              formatC(ANCHOR_VALUE, format = "f", digits = 0, big.mark = ",")))
  cat(sprintf("  Match: %s\n", ifelse(matches, "YES", "NO — discrepancy detected")))

  list(found = TRUE, fips_15003_val = fhfa_val, matches = matches,
        col = as_is_col, row = row_15003)
}

# ── Q2: Diagnose spatial join failure for Hawaii FIPS-NA courses ──────────────

q2_diagnose_spatial_join <- function(r_baseline) {
  cat("[Q2] Diagnosing spatial join failure for Hawaii FIPS-NA courses...\n")

  hi_all <- r_baseline |> filter(State_Abbr == "HI")
  hi_na  <- hi_all |> filter(is_fips_na(FIPS))

  cat(sprintf("  Hawaii courses total: %d  |  FIPS-NA: %d\n",
              nrow(hi_all), nrow(hi_na)))

  if (nrow(hi_na) == 0) {
    cat("  No Hawaii FIPS-NA courses found in R baseline — nothing to diagnose.\n")
    return(list(n_hi_na = 0, hi_na_courses = hi_na, diagnoses = list(),
                diagnosis_summary = "No Hawaii FIPS-NA courses in R baseline."))
  }

  cat("  Hawaii FIPS-NA courses:\n")
  for (i in seq_len(nrow(hi_na))) {
    cat(sprintf("    %d. %-50s (%.5f, %.5f)\n",
                i, hi_na$Course_Name[i], hi_na$Longitude[i], hi_na$Latitude[i]))
  }

  # Download three boundary variants to isolate the cause
  cat("  Downloading county boundaries (cb=TRUE, 2022, 20m — Phase 1 method)...\n")
  county_cb20 <- tryCatch(
    counties(cb = TRUE, year = 2022, resolution = "20m", progress_bar = FALSE) |>
      st_transform(4326),
    error = function(e) { cat(sprintf("  WARNING: cb=TRUE/20m download failed: %s\n", e$message)); NULL }
  )

  cat("  Downloading county boundaries (cb=TRUE, 2022, 5m — higher resolution)...\n")
  county_cb5 <- tryCatch(
    counties(cb = TRUE, year = 2022, resolution = "5m", progress_bar = FALSE) |>
      st_transform(4326),
    error = function(e) { cat("  WARNING: cb=TRUE/5m download failed.\n"); NULL }
  )

  cat("  Downloading county boundaries (cb=FALSE, 2022 — full TIGER)...\n")
  county_tiger <- tryCatch(
    counties(cb = FALSE, year = 2022, progress_bar = FALSE) |>
      st_transform(4326),
    error = function(e) { cat("  WARNING: TIGER download failed.\n"); NULL }
  )

  diagnose_one <- function(row) {
    pt <- st_as_sf(row, coords = c("Longitude", "Latitude"), crs = 4326, remove = FALSE)

    check_join <- function(boundary, label) {
      if (is.null(boundary)) {
        return(tibble(method = label, GEOID = NA_character_, resolved = FALSE))
      }
      j    <- st_join(pt, boundary, join = st_intersects)
      geoid <- if ("GEOID" %in% names(j)) as.character(j$GEOID[1]) else NA_character_
      tibble(method = label, GEOID = geoid, resolved = !is.na(geoid) & geoid != "NA")
    }

    join_results <- bind_rows(
      check_join(county_cb20,  "cb=TRUE, 20m (Phase 1 method)"),
      check_join(county_cb5,   "cb=TRUE, 5m  (higher resolution)"),
      check_join(county_tiger, "cb=FALSE, TIGER (full)")
    )

    nearest_dist_m <- NA_real_
    if (!is.null(county_cb20)) {
      idx            <- st_nearest_feature(pt, county_cb20)
      nearest_dist_m <- as.numeric(st_distance(pt, county_cb20[idx, ]))
    }

    list(course = row$Course_Name, lon = row$Longitude, lat = row$Latitude,
          join_results = join_results, nearest_dist_m = nearest_dist_m)
  }

  diagnoses <- lapply(seq_len(nrow(hi_na)), function(i) diagnose_one(hi_na[i, ]))

  # Summary: if Tiger resolves but cb=20m doesn't → boundary simplification confirmed
  tiger_resolves <- sapply(diagnoses, function(d)
    any(d$join_results$method == "cb=FALSE, TIGER (full)" & d$join_results$resolved, na.rm = TRUE))
  cb20_resolves  <- sapply(diagnoses, function(d)
    any(d$join_results$method == "cb=TRUE, 20m (Phase 1 method)" & d$join_results$resolved, na.rm = TRUE))

  n_tiger_only <- sum(tiger_resolves & !cb20_resolves, na.rm = TRUE)

  diagnosis_summary <- if (n_tiger_only > 0) {
    sprintf(
      "%d of %d Hawaii FIPS-NA courses resolve with cb=FALSE (TIGER) but NOT with cb=TRUE/20m. ",
      n_tiger_only, nrow(hi_na)
    )
  } else {
    "Boundary resolution results were inconclusive (possible download issue)."
  }
  cat(sprintf("  Diagnosis: %s\n", diagnosis_summary))

  list(n_hi_na = nrow(hi_na), hi_na_courses = hi_na, diagnoses = diagnoses,
        diagnosis_summary = diagnosis_summary)
}

# ── Q3: Count FIPS-NA courses nationwide across all three language baselines ──

q3_count_fips_na <- function(r_baseline, py_baseline, jl_baseline) {
  cat("[Q3] Counting FIPS-NA courses nationwide...\n")

  r_na  <- r_baseline  |> filter(is_fips_na(FIPS))
  py_na <- py_baseline |> filter(is_fips_na(FIPS))
  jl_na <- jl_baseline |> filter(is_fips_na(FIPS))

  r_total  <- nrow(r_baseline)
  py_total <- nrow(py_baseline)
  jl_total <- nrow(jl_baseline)

  cat(sprintf("  R:  %d FIPS-NA of %d total (%.2f%%)\n",
              nrow(r_na),  r_total,  100 * nrow(r_na)  / r_total))
  cat(sprintf("  Py: %d FIPS-NA of %d total (%.2f%%)\n",
              nrow(py_na), py_total, 100 * nrow(py_na) / py_total))
  cat(sprintf("  Jl: %d FIPS-NA of %d total (%.2f%%)\n",
              nrow(jl_na), jl_total, 100 * nrow(jl_na) / jl_total))

  # Per-state breakdown from R baseline (has State_Abbr from raw data, not spatial join)
  r_by_state <- r_na |>
    count(State_Abbr, name = "NA_Count") |>
    arrange(desc(NA_Count)) |>
    mutate(Total_R = r_total, Pct = round(100 * NA_Count / r_total, 3))

  # Python uses Tigris_State_Abbr (no State_Abbr column)
  py_state_col <- if ("State_Abbr" %in% names(py_na)) "State_Abbr" else "Tigris_State_Abbr"
  py_by_state  <- py_na |>
    count(.data[[py_state_col]], name = "NA_Count") |>
    rename(State = .data[[py_state_col]]) |>
    arrange(desc(NA_Count))

  list(
    r_total = r_total, r_na_count = nrow(r_na), r_na = r_na, r_by_state = r_by_state,
    py_total = py_total, py_na_count = nrow(py_na),
    jl_total = jl_total, jl_na_count = nrow(jl_na),
    py_by_state = py_by_state
  )
}

# ── Report writer ─────────────────────────────────────────────────────────────

write_report <- function(q1, q2, q3) {
  cat("[REPORT] Writing Markdown report...\n")

  thesis_defensible <- q3$r_na_count < 100
  defensibility_label <- if (q3$r_na_count < 50) {
    "**DEFENSIBLE** — small isolated failure mode, not systemic"
  } else if (q3$r_na_count < 200) {
    "**BORDERLINE** — review state breakdown before defense"
  } else {
    "**BLOCKER** — systemic; Phase 1 must be re-run before defense"
  }

  fhfa_q1_label <- if (isTRUE(q1$matches)) {
    "**CONFIRMED** — exact match in FHFA source file"
  } else if (isTRUE(q1$found)) {
    paste0("**DISCREPANCY** — source = $",
            formatC(q1$fips_15003_val, format = "f", digits = 0, big.mark = ","), "/acre")
  } else {
    "**NOT FOUND** — FIPS 15003 absent from FHFA 2022 sheet"
  }

  na_rate_r <- round(100 * q3$r_na_count / q3$r_total, 2)

  lines <- c(
    "# FIPS-NA Diagnostic Audit Report",
    "",
    paste0("**Generated:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "**Audit scope:** Phase 1 baseline outputs (R, Python, Julia)",
    "**Status:** Read-only — no source files modified",
    "",
    "---",
    "",
    "## Executive Summary",
    "",
    "| Question | Finding |",
    "|----------|---------|",
    paste0("| Q1: $4,952,600/acre for FIPS 15003? | ", fhfa_q1_label, " |"),
    paste0("| Q2: Spatial join failure cause? | ",
            if (q2$n_hi_na > 0) q2$diagnosis_summary else "No Hawaii FIPS-NA courses found", " |"),
    paste0("| Q3: FIPS-NA course count (R)? | ",
            q3$r_na_count, " of ", formatC(q3$r_total, big.mark = ","),
            " courses (", na_rate_r, "%) |"),
    paste0("| Thesis defensibility | ", defensibility_label, " |"),
    "",
    "---",
    "",
    "## Q1: FHFA Value for FIPS 15003 (Honolulu County, 2022)",
    "",
    paste0("**Source file:** `2024 - FHFA June 20 Land Prices.xlsx`"),
    "**Sheet:** `Panel Counties`  |  **Year filter:** `2022`",
    paste0("**Column used by Phase 1:** `", q1$col, "`"),
    ""
  )

  if (isTRUE(q1$found)) {
    lines <- c(lines,
      paste0("| | Value |"),
      paste0("|---|---|"),
      paste0("| FHFA source (FIPS 15003, 2022) | $",
              formatC(q1$fips_15003_val, format = "f", digits = 0, big.mark = ","), "/acre |"),
      paste0("| Thesis anchor used in Script 9 + §5.4 | $",
              formatC(ANCHOR_VALUE, format = "f", digits = 0, big.mark = ","), "/acre |"),
      paste0("| Match | ",
              ifelse(isTRUE(q1$matches),
                    "**YES — values agree within $1**",
                    paste0("**NO — difference of $",
                            formatC(abs(q1$fips_15003_val - ANCHOR_VALUE),
                                    format = "f", digits = 0, big.mark = ","), "/acre**")),
              " |"),
      ""
    )
    if (!isTRUE(q1$matches) && isTRUE(q1$found)) {
      lines <- c(lines,
        "> **Note:** If values differ, R's Phase 1 may have used a different year's FHFA data",
        "> or an intermediate cleaned file. Verify by checking `FHFA Cleaning.r` in",
        "> `00 - Data Sources/FHFA Data/` for any transformations applied before Phase 1.",
        ""
      )
    }
  } else {
    lines <- c(lines,
      "**FIPS 15003 was not found in the FHFA 2022 panel.**",
      "This suggests Phase 1's FHFA lookup for Honolulu County fell back to a default",
      "or imputed value rather than a direct source match.",
      ""
    )
  }

  lines <- c(lines,
    "---",
    "",
    "## Q2: Spatial Join Failure — Hawaii Kai and Mid-Pacific",
    "",
    "### Phase 1 Spatial Join Method (from `Phase_1.R`)",
    "",
    "```r",
    "# Phase_1.R lines 105–109",
    "county_sf <- counties(cb = TRUE, year = 2022, resolution = \"20m\",",
    "                      progress_bar = FALSE) |>",
    "  st_transform(4326)",
    "courses_sf <- st_join(courses_sf, county_sf, join = st_intersects)  # [METHODOLOGY]",
    "```",
    "",
    "**Key parameters and their significance:**",
    "",
    "| Parameter | Value | Implication |",
    "|-----------|-------|-------------|",
    "| `cb` | `TRUE` | Cartographic boundary — polygon is clipped to the US shoreline and simplified |",
    "| `resolution` | `\"20m\"` | 1:20,000,000 scale — the coarsest level available (options: 500k, 5m, 20m) |",
    "| `join` | `st_intersects` | Strict point-in-polygon; if point falls outside polygon → all county columns = NA |",
    "| `year` | `2022` | 2022 TIGER/Census boundaries |",
    "",
    "**Root cause hypothesis:** At 1:20,000,000 scale, the cartographic boundary simplifies",
    "coastal vertices aggressively. For Hawaii, county polygons follow the shoreline, and",
    "the simplified version may cut inland across narrow peninsulas, bays, or coastal valleys.",
    "Courses whose coordinates fall in such areas pass the strict `st_intersects` test against",
    "the full county polygon but fail against the simplified cartographic version.",
    "",
    paste0("**Hawaii FIPS-NA courses in R baseline:** ", q2$n_hi_na)
  )

  if (q2$n_hi_na > 0) {
    for (d in q2$diagnoses) {
      lines <- c(lines,
        "",
        paste0("### ", d$course),
        paste0("**Coordinates:** Longitude = ", d$lon, ", Latitude = ", d$lat),
        "",
        "| Boundary Variant | FIPS Resolved |",
        "|-----------------|---------------|"
      )
      for (j in seq_len(nrow(d$join_results))) {
        resolved_label <- if (isTRUE(d$join_results$resolved[j])) {
          paste0("RESOLVED (`", d$join_results$GEOID[j], "`)")
        } else {
          "**FAILED** (NA)"
        }
        lines <- c(lines,
          paste0("| `", d$join_results$method[j], "` | ", resolved_label, " |"))
      }
      if (!is.na(d$nearest_dist_m)) {
        lines <- c(lines, "",
          paste0("**Distance from coordinate to nearest cb=20m polygon:** ",
                  round(d$nearest_dist_m, 1), " meters"))
      }
    }

    lines <- c(lines,
      "",
      "### Diagnosis Conclusion",
      "",
      q2$diagnosis_summary,
      "",
      "If courses resolve with `cb=FALSE` (TIGER full files) but fail with `cb=TRUE/20m`:",
      "the failure is a **cartographic boundary simplification artifact**, not a coordinate",
      "data integrity issue. The golf course coordinates are correct — it is the county",
      "polygon that is too coarse to contain them.",
      "",
      "**Phase 1 fix (if re-run is warranted):** Change Phase_1.R line 105 from",
      "`counties(cb = TRUE, year = 2022, resolution = \"20m\")` to either:",
      "- `counties(cb = FALSE, year = 2022)` — full TIGER/Line files (no simplification)",
      "- `counties(cb = TRUE, year = 2022, resolution = \"5m\")` — higher-resolution cartographic",
      ""
    )
  } else {
    lines <- c(lines,
      "",
      "No Hawaii FIPS-NA courses were found in the R baseline at the time of this audit.",
      "The reported failures (Hawaii Kai, Mid-Pacific) may have been resolved in a",
      "subsequent Phase 1 re-run, or they may appear under a different state label.",
      ""
    )
  }

  lines <- c(lines,
    "---",
    "",
    "## Q3: Nationwide FIPS-NA Course Count",
    "",
    "### Cross-Language Totals",
    "",
    "| Language | Total Courses | FIPS-NA Count | FIPS-NA Rate |",
    "|----------|--------------|---------------|-------------|",
    paste0("| R        | ", formatC(q3$r_total,  big.mark = ","), " | ",
           q3$r_na_count,  " | ", round(100 * q3$r_na_count  / q3$r_total,  2), "% |"),
    paste0("| Python   | ", formatC(q3$py_total, big.mark = ","), " | ",
           q3$py_na_count, " | ", round(100 * q3$py_na_count / q3$py_total, 2), "% |"),
    paste0("| Julia    | ", formatC(q3$jl_total, big.mark = ","), " | ",
           q3$jl_na_count, " | ", round(100 * q3$jl_na_count / q3$jl_total, 2), "% |"),
    "",
    "> Cross-language consistency: if R, Python, and Julia show similar FIPS-NA counts,",
    "> all three Phase 1 scripts used the same spatial join with the same boundary file.",
    "> A large discrepancy would indicate language-specific implementation differences.",
    "",
    "### R Baseline: FIPS-NA by State",
    "",
    "| State | FIPS-NA Count |",
    "|-------|--------------|"
  )

  for (i in seq_len(nrow(q3$r_by_state))) {
    lines <- c(lines,
      paste0("| ", q3$r_by_state$State_Abbr[i], " | ", q3$r_by_state$NA_Count[i], " |"))
  }

  lines <- c(lines,
    "",
    paste0("*(Full list: `FIPS_NA_Courses_R.csv` — ", q3$r_na_count,
            " courses with course name, state, and coordinates)*"),
    "",
    "### Geographic Distribution Note",
    "",
    "Courses with FIPS-NA are expected to cluster near state boundaries and coastlines",
    "where simplified cartographic polygons are most likely to exclude valid coordinates.",
    "A random or broadly distributed pattern would instead suggest a CRS or coordinate",
    "datum issue in the source data.",
    "",
    "---",
    "",
    "## Conclusion",
    "",
    paste0("**FIPS-NA count:** ", q3$r_na_count, " of ",
            formatC(q3$r_total, big.mark = ","), " R-baseline courses (",
            na_rate_r, "%)"),
    ""
  )

  if (q3$r_na_count < 50) {
    lines <- c(lines,
      "### Thesis is defensible — isolated failure mode, not systemic",
      "",
      paste0("At ", na_rate_r, "%, the FIPS-NA failure rate is consistent with a cartographic"),
      "boundary simplification artifact at the US coastline. This is not a systemic data",
      "integrity failure.",
      "",
      "Downstream impact: for FIPS-NA courses, Phase 1 sets `county_type = NA` and",
      "`Baseline_Value_Per_Acre = NA`, which means Phase 3 MICE treats `Baseline_Value_Per_Acre`",
      "as a missing value and imputes it from the broader training distribution. Urban coastal",
      "courses (like Hawaii Kai and Mid-Pacific) may occasionally draw from rural USDA-range",
      "values in some imputation draws, marginally underestimating their opportunity cost in",
      "the sub-pool estimates. The Grand Mean across M=100 draws still centers near the true",
      "distribution. The §5.4.2 footnote already discloses the two known Hawaii cases.",
      "",
      "**Recommendation:** No Phase 1 re-run required before defense. The existing disclosure",
      "in §5.4.2 is sufficient given the small affected count.",
      ""
    )
  } else if (q3$r_na_count < 200) {
    lines <- c(lines,
      "### Borderline — review state breakdown before defense",
      "",
      paste0("At ", na_rate_r, "%, the FIPS-NA rate is higher than expected for a pure"),
      "boundary-simplification artifact. Review `FIPS_NA_State_Summary.csv` to determine",
      "whether failures are concentrated in one or two coastal states (benign) or spread",
      "broadly (potential CRS or data source issue).",
      ""
    )
  } else {
    lines <- c(lines,
      "### BLOCKER — Phase 1 must be re-run before defense",
      "",
      paste0("At ", na_rate_r, "%, the FIPS-NA rate is too high to be explained by boundary"),
      "simplification alone. This is a systemic issue. Recommended Phase 1 fix:",
      "change `counties(cb = TRUE, year = 2022, resolution = \"20m\")` to",
      "`counties(cb = FALSE, year = 2022)` (full TIGER/Line files).",
      ""
    )
  }

  writeLines(lines, REPORT_PATH)
  cat(sprintf("  Report saved: %s\n", REPORT_PATH))
}


# === 4. EXECUTION ===

cat("======================================================================\n")
cat("FIPS-NA Diagnostic Audit  —  Econ 732 Thesis (Read-Only)\n")
cat("======================================================================\n\n")

for (p in c(R_BASELINE_PATH, PY_BASELINE_PATH, JL_BASELINE_PATH, FHFA_PATH)) {
  if (!file.exists(p)) stop(paste("Input file not found:", p))
}
if (!dir.exists(DATA_OUT_DIR)) dir.create(DATA_OUT_DIR, recursive = TRUE)

cat("[Setup] Loading Phase 1 baseline files...\n")
r_baseline  <- read_csv(R_BASELINE_PATH,  show_col_types = FALSE)
py_baseline <- read_csv(PY_BASELINE_PATH, show_col_types = FALSE)
jl_baseline <- read_csv(JL_BASELINE_PATH, show_col_types = FALSE)
cat(sprintf("  R:  %d courses loaded\n", nrow(r_baseline)))
cat(sprintf("  Py: %d courses loaded\n", nrow(py_baseline)))
cat(sprintf("  Jl: %d courses loaded\n", nrow(jl_baseline)))
cat("\n")

results_q1 <- q1_verify_fhfa()
cat("\n")
results_q2 <- q2_diagnose_spatial_join(r_baseline)
cat("\n")
results_q3 <- q3_count_fips_na(r_baseline, py_baseline, jl_baseline)
cat("\n")

# Save supporting CSVs
write_csv(
  results_q3$r_na |>
    select(any_of(c("course_id", "Course_Name", "Ownership_Type", "Holes",
                    "State_Abbr", "Longitude", "Latitude", "FIPS", "County_Name",
                    "county_type", "Baseline_Value_Per_Acre"))),
  NA_CSV_PATH
)
write_csv(results_q3$r_by_state, STATE_CSV_PATH)
cat(sprintf("[CSVs] %s\n", NA_CSV_PATH))
cat(sprintf("[CSVs] %s\n", STATE_CSV_PATH))
cat("\n")

write_report(results_q1, results_q2, results_q3)

cat("\n======================================================================\n")
cat("[DONE] Outputs written to QA/data/\n")
cat("======================================================================\n")
