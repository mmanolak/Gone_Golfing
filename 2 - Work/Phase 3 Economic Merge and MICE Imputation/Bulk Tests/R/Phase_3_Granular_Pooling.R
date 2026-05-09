# Purpose: Pool the Urban-only and per-Census-Division aggregate estimates
#          across the 5 imputed datasets using Rubin's Rules.
# Inputs:  Bulk Tests/R/R_Granular_Estimates.rds
# Outputs: Console-printed formatted summary table.
#
# Note on mice::pool():
#   mice::pool() is designed for regression model objects (lm, glm, etc.),
#   not raw scalar aggregates.  For scalar sums, Rubin's Rules formulas are
#   applied directly — standard econometric practice per Rubin (1987) and
#   Van Buuren (2018, "Flexible Imputation of Missing Data").
#
#   Formula summary (m = 5 imputations):
#     q_bar = mean(Q_i)           -- pooled point estimate
#     v_w   = mean(U_i)           -- within-imputation variance
#     v_b   = var(Q_i)            -- between-imputation variance (ddof=1)
#     v_t   = v_w + v_b + v_b/m  -- total variance
#     se    = sqrt(v_t)
#     95%CI = q_bar +/- 1.96 * se


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
RDS_PATH   <- file.path(SCRIPT_DIR, "R_Granular_Estimates.rds")

M <- 5


# === 3. FUNCTIONS ===

#' Apply Rubin's Rules to m point estimates and within-dataset variances.
#' @param q_vec Numeric vector of length m (aggregate Q_i per dataset).
#' @param u_vec Numeric vector of length m (within-dataset variance U_i).
#' @return Named list: q_bar, v_w, v_b, v_t, se, ci_lo, ci_hi, m.
rubins_rules <- function(q_vec, u_vec = NULL) {
  m     <- length(q_vec)
  q_bar <- mean(q_vec)
  v_b   <- var(q_vec)
  v_w   <- if (!is.null(u_vec) && length(u_vec) == m) mean(u_vec) else 0
  v_t   <- v_w + v_b + v_b / m
  se    <- sqrt(v_t)
  list(
    q_bar = q_bar,
    v_w   = v_w,
    v_b   = v_b,
    v_t   = v_t,
    se    = se,
    ci_lo = q_bar - 1.96 * se,
    ci_hi = q_bar + 1.96 * se,
    m     = m
  )
}


# === 4. EXECUTION ===

cat("=== Phase 3 Granular Pooling (Rubin's Rules) ===\n")
cat("Loading:", RDS_PATH, "\n\n")

if (!file.exists(RDS_PATH)) {
  stop(
    "R_Granular_Estimates.rds not found at:\n  ", RDS_PATH,
    "\nPlease run Phase_3_Granular_Calculations.R first."
  )
}

granular_list <- readRDS(RDS_PATH)
cat(sprintf(
  "Loaded granular estimates for %d imputed datasets.\n\n",
  length(granular_list)
))

# --- Urban-Only pooling ---

urban_q <- sapply(granular_list, `[[`, "urban_total")
urban_u <- sapply(granular_list, `[[`, "urban_var")

# [METHODOLOGY] Rubin's Rules pooling — q_bar is the pooled urban estimate;
#               v_t combines within- and between-imputation variance (Rubin 1987)
urban_pool <- rubins_rules(urban_q, urban_u)

cat("--- Urban-Only Pooling ---\n")
cat(sprintf(
  "  Individual estimates : %s B\n",
  paste(sprintf("$%.3f", urban_q / 1e9), collapse = ", ")
))
cat(sprintf("  Pooled q_bar : $%.3f B\n", urban_pool$q_bar / 1e9))
cat(sprintf("  v_w          : %.4e\n",    urban_pool$v_w))
cat(sprintf("  v_b          : %.4e\n",    urban_pool$v_b))
cat(sprintf("  v_t          : %.4e\n",    urban_pool$v_t))
cat(sprintf("  se           : $%.3f B\n", urban_pool$se / 1e9))
cat(sprintf(
  "  95%% CI       : $%.3f B -- $%.3f B\n\n",
  urban_pool$ci_lo / 1e9, urban_pool$ci_hi / 1e9
))

# --- Census Division pooling ---

all_divisions <- granular_list[[1]]$division_aggregates$Census_Division

cat("--- Census Division Pooling (9 divisions) ---\n\n")

division_summary_rows <- vector("list", length(all_divisions))

for (div in all_divisions) {
  div_q <- sapply(granular_list, function(imp) {
    row_idx <- which(imp$division_aggregates$Census_Division == div)
    if (length(row_idx) == 0L) return(NA_real_)
    imp$division_aggregates$Aggregate_Value[row_idx]
  })

  div_u <- sapply(granular_list, function(imp) {
    row_idx <- which(imp$division_aggregates$Census_Division == div)
    if (length(row_idx) == 0L) return(NA_real_)
    imp$division_aggregates$Within_Variance[row_idx]
  })

  div_n <- granular_list[[1]]$division_aggregates |>
    filter(Census_Division == div) |>
    pull(Course_Count)

  # [METHODOLOGY] Rubin's Rules pooling — per-division scalar sums (Rubin 1987)
  div_pool <- rubins_rules(div_q, div_u)

  idx <- which(all_divisions == div)
  division_summary_rows[[idx]] <- data.frame(
    Census_Division  = div,
    Course_Count     = if (length(div_n) > 0L) div_n else NA_integer_,
    Pooled_Value_B   = div_pool$q_bar / 1e9,
    SE_B             = div_pool$se / 1e9,
    CI_Lower_B       = div_pool$ci_lo / 1e9,
    CI_Upper_B       = div_pool$ci_hi / 1e9,
    stringsAsFactors = FALSE
  )
}

division_summary <- bind_rows(division_summary_rows)

# --- Formatted summary table ---

sep_line  <- paste(rep("-", 90), collapse = "")
sep_heavy <- paste(rep("=", 90), collapse = "")

cat(sep_heavy, "\n")
cat("  GRANULAR POOLED ESTIMATES -- Rubin's Rules (m = 5 imputations)\n")
cat(sep_heavy, "\n\n")

cat("  URBAN-ONLY AGGREGATE\n")
cat(
  "    Courses     :",
  format(granular_list[[1]]$urban_n, big.mark = ","), "\n"
)
cat(sprintf("    q_bar (pooled): $%.3f B\n", urban_pool$q_bar / 1e9))
cat(sprintf("    se            : $%.3f B\n", urban_pool$se / 1e9))
cat(sprintf(
  "    95%% CI        : $%.3f B  --  $%.3f B\n",
  urban_pool$ci_lo / 1e9, urban_pool$ci_hi / 1e9
))
cat("\n", sep_line, "\n\n")

cat("  BY US CENSUS DIVISION\n\n")
cat(sprintf(
  "  %-24s %8s  %12s  %10s  %12s  %12s\n",
  "Division", "Courses",
  "Pooled ($B)", "SE ($B)",
  "CI Low ($B)", "CI High ($B)"
))
cat("  ", paste(rep("-", 86), collapse = ""), "\n")

for (k in seq_len(nrow(division_summary))) {
  row <- division_summary[k, ]
  cat(sprintf(
    "  %-24s %8s  %12.3f  %10.3f  %12.3f  %12.3f\n",
    row$Census_Division,
    format(row$Course_Count, big.mark = ","),
    row$Pooled_Value_B,
    row$SE_B,
    row$CI_Lower_B,
    row$CI_Upper_B
  ))
}

cat("  ", paste(rep("-", 86), collapse = ""), "\n")
cat(sprintf(
  "  %-24s %8s  %12.3f\n",
  "TOTAL (division sum)",
  format(
    sum(division_summary$Course_Count, na.rm = TRUE),
    big.mark = ","
  ),
  sum(division_summary$Pooled_Value_B, na.rm = TRUE)
))
cat("\n", sep_heavy, "\n\n")

# --- Assemble clean summary data.frame ---

urban_row <- data.frame(
  Category        = "Urban (all divisions)",
  Census_Division = NA_character_,
  Course_Count    = granular_list[[1]]$urban_n,
  Pooled_Value_B  = urban_pool$q_bar / 1e9,
  SE_B            = urban_pool$se / 1e9,
  CI_Lower_B      = urban_pool$ci_lo / 1e9,
  CI_Upper_B      = urban_pool$ci_hi / 1e9,
  stringsAsFactors = FALSE
)

division_rows <- division_summary |>
  mutate(Category = "Census Division") |>
  select(
    Category, Census_Division, Course_Count,
    Pooled_Value_B, SE_B, CI_Lower_B, CI_Upper_B
  )

pooled_df <- bind_rows(urban_row, division_rows)

cat("Clean summary data.frame assembled (", nrow(pooled_df), "rows).\n")
cat("Columns:", paste(names(pooled_df), collapse = ", "), "\n\n")
cat("=== Granular Pooling Complete ===\n")
