# Purpose: Unified Phase 3 pipeline — complete-case benchmark, MICE imputation
#          (m=5, rf), granular urban and Census Division aggregates, and Rubin's
#          Rules pooling (V_W=0 for sum estimands) from one authoritative source.
# Inputs:  Phase 2 Spatial Polygons and True Acreage/R_Phase2_Acreage_Matched_v2.csv
# Outputs: Data/Suite_v2/Suite_v2_Imputed_Dataset_{1..5}.csv
#          Data/Suite_v2/Suite_v2_Granular_Estimates.rds
#          Data/Suite_v2/Suite_v2_Results_Summary.csv
#
# NOTE on V_W = 0 for scalar sums
# ─────────────────────────────────────────────────────────────────────────────
# Rubin's Rules were originally derived for estimating a population parameter
# from a sample. When Q_i is a *deterministic sum* of all n rows in the
# imputed dataset (no sampling), the within-imputation variance U_i is
# conceptually zero — every observation is included, so there is no sampling
# error within a given completed dataset. All uncertainty comes from the
# imputation model itself (V_B). Setting V_W = 0 therefore gives:
#
#   V_T = V_B + V_B / m   →   SE = sqrt(V_B * (1 + 1/m))
#
# This is the theoretically correct formulation for a census-style sum,
# referenced in Rubin (1987, §3.3) and Van Buuren (2018, §2.4.3).


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(mice)
  library(future)
  library(furrr)
  library(parallelly)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
PHASE3_DIR <- file.path(SCRIPT_DIR, "..", "..")
WORK_DIR   <- file.path(PHASE3_DIR, "..")
PHASE2_DIR <- file.path(
  WORK_DIR, "Phase 2 Spatial Polygons and True Acreage"
)

SOURCE_CSV  <- file.path(
  PHASE2_DIR, "R_Phase2_Acreage_Matched_v2.csv"
)

M <- 5

SAFE_WORKERS <- min(availableCores() - 8, 20)
SAFE_WORKERS <- max(SAFE_WORKERS, 1L)
options(future.globals.maxSize = 20 * 1024^3)
plan(multisession, workers = SAFE_WORKERS)

set.seed(42)  # [METHODOLOGY] reproducibility seed for stochastic MICE

ALL_DIVISIONS <- c(
  "New England", "Middle Atlantic", "East North Central",
  "West North Central", "South Atlantic", "East South Central",
  "West South Central", "Mountain", "Pacific"
)

# [METHODOLOGY] Census Division mapping per US Census Bureau definitions
# Source: census.gov/geo/pdfs/maps-data/maps/reference/us_regdiv.pdf
DIVISION_MAP <- c(
  CT = "New England",       ME = "New England",
  MA = "New England",       NH = "New England",
  RI = "New England",       VT = "New England",
  NJ = "Middle Atlantic",   NY = "Middle Atlantic",
  PA = "Middle Atlantic",
  IL = "East North Central", IN = "East North Central",
  MI = "East North Central", OH = "East North Central",
  WI = "East North Central",
  IA = "West North Central", KS = "West North Central",
  MN = "West North Central", MO = "West North Central",
  NE = "West North Central", ND = "West North Central",
  SD = "West North Central",
  DE = "South Atlantic",    FL = "South Atlantic",
  GA = "South Atlantic",    MD = "South Atlantic",
  NC = "South Atlantic",    SC = "South Atlantic",
  VA = "South Atlantic",    WV = "South Atlantic",
  DC = "South Atlantic",
  AL = "East South Central", KY = "East South Central",
  MS = "East South Central", TN = "East South Central",
  AR = "West South Central", LA = "West South Central",
  OK = "West South Central", TX = "West South Central",
  AZ = "Mountain", CO = "Mountain", ID = "Mountain",
  MT = "Mountain", NV = "Mountain", NM = "Mountain",
  UT = "Mountain", WY = "Mountain",
  AK = "Pacific",  CA = "Pacific",  HI = "Pacific",
  OR = "Pacific",  WA = "Pacific"
)


# === 3. FUNCTIONS ===

#' Apply Rubin's Rules for scalar sum estimands (V_W forced to zero).
#' @param q_vec Numeric vector of length m (Q_i per imputed dataset).
#' @return Named list: q_bar, v_b, v_t, se, ci_lo, ci_hi, m.
rubins_sum <- function(q_vec) {
  m     <- length(q_vec)
  q_bar <- mean(q_vec)
  v_b   <- var(q_vec)
  v_t   <- v_b + v_b / m  # V_W = 0 — see header note
  se    <- sqrt(v_t)
  list(
    q_bar = q_bar, v_b = v_b, v_t = v_t, se = se,
    ci_lo = q_bar - 1.96 * se,
    ci_hi = q_bar + 1.96 * se,
    m     = m
  )
}

fmt_b <- function(x) sprintf("$%.3f B", x / 1e9)


# === 4. EXECUTION ===

cat("=== Phase 3 Analysis Suite v2 ===\n")
cat("  Source CSV :", SOURCE_CSV, "\n")
cat("  Output dir :", PHASE3_DIR, "\n\n")

if (!file.exists(SOURCE_CSV)) {
  stop(paste(
    "Source file not found:\n ", SOURCE_CSV,
    "\nPlease run Phase_2.R first."
  ))
}

cat(paste(rep("─", 60), collapse = ""), "\n")
cat("Loading authoritative source dataset...\n")

acreage_df <- read_csv(SOURCE_CSV, show_col_types = FALSE)

cat(sprintf("  Rows    : %s\n", formatC(nrow(acreage_df), big.mark = ",")))
cat(sprintf("  Columns : %s\n", ncol(acreage_df)))
cat(sprintf(
  "  final_acreage missing         : %s  (%.1f%%)\n",
  formatC(sum(is.na(acreage_df$final_acreage)), big.mark = ","),
  100 * mean(is.na(acreage_df$final_acreage))
))
cat(sprintf(
  "  Baseline_Value_Per_Acre missing: %s  (%.1f%%)\n",
  formatC(
    sum(is.na(acreage_df$Baseline_Value_Per_Acre)),
    big.mark = ","
  ),
  100 * mean(is.na(acreage_df$Baseline_Value_Per_Acre))
))

acreage_df <- acreage_df |>
  mutate(
    Census_Division = DIVISION_MAP[State_Abbr],
    Census_Division = if_else(
      is.na(Census_Division), "Unknown", Census_Division
    )
  )

n_unknown_div <- sum(
  acreage_df$Census_Division == "Unknown", na.rm = TRUE
)
if (n_unknown_div > 0) {
  warning(
    n_unknown_div,
    " rows have State_Abbr not in Census Division map ",
    "and will be excluded from division-level totals."
  )
}

# ── ANALYSIS 1: MICE-Free Complete Case Benchmark ────────────────────────────

cat("\n", paste(rep("─", 60), collapse = ""), "\n")
cat("ANALYSIS 1: MICE-Free Complete Case Benchmark\n")
cat(paste(rep("─", 60), collapse = ""), "\n")

df_complete <- acreage_df |>
  filter(!is.na(final_acreage), !is.na(Baseline_Value_Per_Acre))

n_total    <- nrow(acreage_df)
n_complete <- nrow(df_complete)
n_removed  <- n_total - n_complete

cat(sprintf(
  "  Full dataset rows    : %s\n",
  formatC(n_total, big.mark = ",")
))
cat(sprintf(
  "  Complete case rows   : %s  (%.1f%%)\n",
  formatC(n_complete, big.mark = ","),
  100 * n_complete / n_total
))
cat(sprintf(
  "  Rows dropped (NAs)   : %s  (%.1f%%)\n",
  formatC(n_removed, big.mark = ","),
  100 * n_removed / n_total
))

cat("\n  acreage_source breakdown (complete cases):\n")
src_tbl <- df_complete |>
  count(acreage_source, name = "n") |>
  mutate(pct = sprintf("%.1f%%", 100 * n / n_complete))
for (k in seq_len(nrow(src_tbl))) {
  cat(sprintf(
    "    %-14s : %s  (%s)\n",
    src_tbl$acreage_source[k],
    formatC(src_tbl$n[k], big.mark = ","),
    src_tbl$pct[k]
  ))
}

df_complete <- df_complete |>
  mutate(
    Total_Opportunity_Cost = final_acreage * Baseline_Value_Per_Acre
  )

mice_free_national <- sum(df_complete$Total_Opportunity_Cost, na.rm = TRUE)
df_urban_cc        <- df_complete |> filter(county_type == "Urban")
mice_free_urban    <- sum(
  df_urban_cc$Total_Opportunity_Cost, na.rm = TRUE
)

cat(sprintf(
  "\n  MICE-Free National Value   : %s\n",
  fmt_b(mice_free_national)
))
cat(sprintf(
  "  MICE-Free Urban-Only Value : %s\n",
  fmt_b(mice_free_urban)
))

# ── ANALYSIS 2: MICE Imputation ───────────────────────────────────────────────

cat("\n", paste(rep("─", 60), collapse = ""), "\n")
cat("ANALYSIS 2: MICE Imputation (m=5, Random Forest)\n")
cat(paste(rep("─", 60), collapse = ""), "\n")

course_col <- if ("Course_Type" %in% names(acreage_df)) {
  "Course_Type"
} else {
  "Ownership_Type"
}
predictors         <- c(
  "Holes", course_col, "county_type", "Longitude", "Latitude"
)
variables_to_impute <- c("final_acreage", "Baseline_Value_Per_Acre")

imp_df <- acreage_df[, c(predictors, variables_to_impute)]

cat(sprintf(
  "  Variables imputed  : %s\n",
  paste(variables_to_impute, collapse = ", ")
))
cat(sprintf(
  "  Predictor variables: %s\n",
  paste(predictors, collapse = ", ")
))
cat(sprintf("  Workers            : %d\n", SAFE_WORKERS))
cat("  Running futuremice (m=5, method='rf', maxit=10)...\n")

# [METHODOLOGY] futuremice — parallel Random Forest MICE; tree-based to
#               avoid negative predictions and handle mixed predictor types
imputed_list <- futuremice(
  data         = imp_df,
  m            = M,
  method       = "rf",
  parallelseed = 42,
  maxit        = 10
)

cat("  MICE imputation complete.\n")
cat("\n  Saving imputed datasets...\n")

imp_paths <- character(M)
out_suite_dir <- file.path(PHASE3_DIR, "Data", "Suite_v2")
dir.create(out_suite_dir, showWarnings = FALSE, recursive = TRUE)

for (i in seq_len(M)) {
  complete_data <- complete(imputed_list, i)
  out_path <- file.path(
    out_suite_dir,
    sprintf("Suite_v2_Imputed_Dataset_%d.csv", i)
  )
  write_csv(complete_data, out_path)
  imp_paths[i] <- out_path
  cat(sprintf("    [%d] %s\n", i, out_path))
}

# ── ANALYSIS 3: Granular aggregates per imputed dataset ──────────────────────

cat("\n", paste(rep("─", 60), collapse = ""), "\n")
cat("ANALYSIS 3: Granular Aggregates (Urban + Census Division)\n")
cat(paste(rep("─", 60), collapse = ""), "\n")

meta_cols    <- acreage_df |> select(county_type, Census_Division, State_Abbr)
granular_list <- vector("list", M)

for (i in seq_len(M)) {
  imp <- read_csv(imp_paths[i], show_col_types = FALSE)

  if (nrow(imp) != nrow(acreage_df)) {
    stop(sprintf(
      "Row count mismatch for imputed dataset %d: imputed=%d, source=%d",
      i, nrow(imp), nrow(acreage_df)
    ))
  }

  imp$county_type      <- meta_cols$county_type
  imp$Census_Division  <- meta_cols$Census_Division

  imp$Total_Opportunity_Cost <-
    imp$final_acreage * imp$Baseline_Value_Per_Acre

  nat_total  <- sum(imp$Total_Opportunity_Cost, na.rm = TRUE)
  urban_df   <- imp |> filter(county_type == "Urban")
  urban_total <- sum(urban_df$Total_Opportunity_Cost, na.rm = TRUE)
  urban_n    <- nrow(urban_df)

  division_results <- imp |>
    filter(Census_Division != "Unknown") |>
    group_by(Census_Division) |>
    summarise(
      Aggregate_Value = sum(Total_Opportunity_Cost, na.rm = TRUE),
      Course_Count    = n(),
      .groups         = "drop"
    ) |>
    right_join(
      data.frame(Census_Division = ALL_DIVISIONS),
      by = "Census_Division"
    ) |>
    mutate(
      Aggregate_Value = replace(Aggregate_Value, is.na(Aggregate_Value), 0),
      Course_Count    = replace(Course_Count, is.na(Course_Count), 0L)
    ) |>
    arrange(match(Census_Division, ALL_DIVISIONS))

  granular_list[[i]] <- list(
    dataset_number      = i,
    national_total      = nat_total,
    urban_n             = urban_n,
    urban_total         = urban_total,
    division_aggregates = division_results
  )

  cat(sprintf(
    "  Dataset %d: national=%s | urban=%s | courses=%s\n",
    i,
    fmt_b(nat_total),
    fmt_b(urban_total),
    formatC(nrow(imp), big.mark = ",")
  ))
}

rds_path <- file.path(out_suite_dir, "Suite_v2_Granular_Estimates.rds")
saveRDS(granular_list, rds_path)
cat(sprintf("\n  [OK] Granular estimates saved -> %s\n", rds_path))

# ── ANALYSIS 4: Rubin's Rules pooling ────────────────────────────────────────

cat("\n", paste(rep("─", 60), collapse = ""), "\n")
cat("ANALYSIS 4: Rubin's Rules Pooling  (V_W = 0, sum estimand)\n")
cat(paste(rep("─", 60), collapse = ""), "\n")

# [METHODOLOGY] Rubin's Rules with V_W=0 — appropriate for deterministic sums
#               where all rows are included (no sampling within each dataset)
nat_q    <- sapply(granular_list, `[[`, "national_total")
nat_pool <- rubins_sum(nat_q)

cat("\n  National Total (MICE-pooled):\n")
cat(sprintf(
  "    Individual Q_i : %s\n",
  paste(sprintf("%.3f B", nat_q / 1e9), collapse = " | ")
))
cat(sprintf("    Pooled Q_bar   : %s\n", fmt_b(nat_pool$q_bar)))
cat(sprintf("    SE             : %s\n", fmt_b(nat_pool$se)))
cat(sprintf(
  "    95%% CI        : %s — %s\n\n",
  fmt_b(nat_pool$ci_lo), fmt_b(nat_pool$ci_hi)
))

urban_q    <- sapply(granular_list, `[[`, "urban_total")
urban_pool <- rubins_sum(urban_q)

cat("  Urban-Only (MICE-pooled):\n")
cat(sprintf(
  "    Courses (dataset 1): %s\n",
  formatC(granular_list[[1]]$urban_n, big.mark = ",")
))
cat(sprintf("    Pooled Q_bar   : %s\n", fmt_b(urban_pool$q_bar)))
cat(sprintf("    SE             : %s\n", fmt_b(urban_pool$se)))
cat(sprintf(
  "    95%% CI        : %s — %s\n\n",
  fmt_b(urban_pool$ci_lo), fmt_b(urban_pool$ci_hi)
))

cat("  Census Division Pooling:\n\n")

sep_h <- paste(rep("=", 92), collapse = "")
sep_l <- paste(rep("-", 92), collapse = "")

div_summary_rows <- vector("list", length(ALL_DIVISIONS))

for (div in ALL_DIVISIONS) {
  div_q <- sapply(granular_list, function(imp) {
    row_i <- which(imp$division_aggregates$Census_Division == div)
    if (length(row_i) == 0L) NA_real_
    else imp$division_aggregates$Aggregate_Value[row_i]
  })

  div_n    <- granular_list[[1]]$division_aggregates |>
    filter(Census_Division == div) |>
    pull(Course_Count)
  div_pool <- rubins_sum(div_q)

  idx <- which(ALL_DIVISIONS == div)
  div_summary_rows[[idx]] <- data.frame(
    Census_Division = div,
    Course_Count    = if (length(div_n) > 0L) div_n else NA_integer_,
    Pooled_Value_B  = div_pool$q_bar / 1e9,
    SE_B            = div_pool$se / 1e9,
    CI_Lower_B      = div_pool$ci_lo / 1e9,
    CI_Upper_B      = div_pool$ci_hi / 1e9,
    stringsAsFactors = FALSE
  )
}

div_summary <- bind_rows(div_summary_rows)

cat("\n", sep_h, "\n")
cat("  PHASE 3 ANALYSIS SUITE v2 — FINAL RESULTS\n")
cat(sep_h, "\n\n")
cat("  Source dataset  : R_Phase2_Acreage_Matched_v2.csv\n")
cat(sprintf(
  "  Full sample     : %s courses\n",
  formatC(nrow(acreage_df), big.mark = ",")
))
cat(sprintf(
  "  Complete case   : %s courses  (%.1f%% of full sample)\n",
  formatC(n_complete, big.mark = ","),
  100 * n_complete / nrow(acreage_df)
))
cat(sprintf(
  "  Imputed (MICE)  : m = %d datasets, method = rf, maxit = 10\n\n",
  M
))
cat("  ── MICE-Free Benchmark (complete case only) ──\n")
cat(sprintf("     National value  : %s\n", fmt_b(mice_free_national)))
cat(sprintf("     Urban-only      : %s\n\n", fmt_b(mice_free_urban)))
cat("  ── MICE-Pooled National Total ──\n")
cat(sprintf("     Pooled Q_bar   : %s\n", fmt_b(nat_pool$q_bar)))
cat(sprintf("     SE             : %s\n", fmt_b(nat_pool$se)))
cat(sprintf(
  "     95%% CI        : %s  —  %s\n\n",
  fmt_b(nat_pool$ci_lo), fmt_b(nat_pool$ci_hi)
))
cat("  ── MICE-Pooled Urban-Only ──\n")
cat(sprintf("     Pooled Q_bar   : %s\n", fmt_b(urban_pool$q_bar)))
cat(sprintf("     SE             : %s\n", fmt_b(urban_pool$se)))
cat(sprintf(
  "     95%% CI        : %s  —  %s\n\n",
  fmt_b(urban_pool$ci_lo), fmt_b(urban_pool$ci_hi)
))
cat("  ── MICE-Pooled by US Census Division ──\n\n")
cat(sprintf(
  "  %-24s %8s  %12s  %10s  %12s  %12s\n",
  "Division", "Courses",
  "Pooled ($B)", "SE ($B)", "CI Low ($B)", "CI High ($B)"
))
cat("  ", sep_l, "\n")

for (k in seq_len(nrow(div_summary))) {
  r <- div_summary[k, ]
  cat(sprintf(
    "  %-24s %8s  %12.3f  %10.3f  %12.3f  %12.3f\n",
    r$Census_Division,
    formatC(r$Course_Count, big.mark = ","),
    r$Pooled_Value_B, r$SE_B, r$CI_Lower_B, r$CI_Upper_B
  ))
}

cat("  ", sep_l, "\n")
cat(sprintf(
  "  %-24s %8s  %12.3f\n",
  "TOTAL (division sum)*",
  formatC(sum(div_summary$Course_Count, na.rm = TRUE), big.mark = ","),
  sum(div_summary$Pooled_Value_B, na.rm = TRUE)
))
cat("  * Division sum ≠ national pooled estimate (see header note)\n")
cat("\n", sep_h, "\n\n")

summary_rows <- list(
  data.frame(
    Category       = "MICE-Free",
    Subcategory    = "National",
    Course_Count   = n_complete,
    Pooled_Value_B = mice_free_national / 1e9,
    SE_B           = NA_real_,
    CI_Lower_B     = NA_real_,
    CI_Upper_B     = NA_real_,
    stringsAsFactors = FALSE
  ),
  data.frame(
    Category       = "MICE-Free",
    Subcategory    = "Urban-Only",
    Course_Count   = nrow(df_urban_cc),
    Pooled_Value_B = mice_free_urban / 1e9,
    SE_B           = NA_real_,
    CI_Lower_B     = NA_real_,
    CI_Upper_B     = NA_real_,
    stringsAsFactors = FALSE
  ),
  data.frame(
    Category       = "MICE-Pooled",
    Subcategory    = "National",
    Course_Count   = nrow(acreage_df),
    Pooled_Value_B = nat_pool$q_bar / 1e9,
    SE_B           = nat_pool$se / 1e9,
    CI_Lower_B     = nat_pool$ci_lo / 1e9,
    CI_Upper_B     = nat_pool$ci_hi / 1e9,
    stringsAsFactors = FALSE
  ),
  data.frame(
    Category       = "MICE-Pooled",
    Subcategory    = "Urban-Only",
    Course_Count   = granular_list[[1]]$urban_n,
    Pooled_Value_B = urban_pool$q_bar / 1e9,
    SE_B           = urban_pool$se / 1e9,
    CI_Lower_B     = urban_pool$ci_lo / 1e9,
    CI_Upper_B     = urban_pool$ci_hi / 1e9,
    stringsAsFactors = FALSE
  ),
  div_summary |>
    mutate(Category = "MICE-Pooled", Subcategory = Census_Division) |>
    select(
      Category, Subcategory, Course_Count,
      Pooled_Value_B, SE_B, CI_Lower_B, CI_Upper_B
    )
)

pooled_df <- bind_rows(summary_rows)

summary_out <- file.path(out_suite_dir, "Suite_v2_Results_Summary.csv")
write_csv(pooled_df, summary_out)
cat(sprintf("[OK] Results summary saved -> %s\n\n", summary_out))
cat("=== PHASE 3 ANALYSIS SUITE v2 COMPLETE ===\n")
