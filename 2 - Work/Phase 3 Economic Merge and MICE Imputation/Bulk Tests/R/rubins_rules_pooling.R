# Purpose: Pool the 5 MICE-imputed aggregate estimates using Rubin's Rules
#          to produce a single national land-value point estimate with 95% CI.
# Inputs:  Bulk Tests/R/R_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/R/R_Rubins_Rules_Summary.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(future)
  library(furrr)
  library(parallelly)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR  <- this.path::this.dir()
OUT_CSV     <- file.path(SCRIPT_DIR, "R_Rubins_Rules_Summary.csv")

M            <- 5
IMPUTED_DIR  <- SCRIPT_DIR

# Reserve fewer cores than MICE.R — pooling is sequential, workers only kept
# for consistency with the parallel environment setup
SAFE_WORKERS <- min(availableCores() - 12, 20)
plan(multisession, workers = SAFE_WORKERS)


# === 3. FUNCTIONS ===

#' Apply Rubin's Rules to m point estimates and within-dataset variances.
#' @param Q_vec Numeric vector of length m (aggregate Q_i per dataset).
#' @param U_vec Numeric vector of length m (within-dataset variance U_i).
#' @return Named list with Q_bar, V_W, V_B, V_T, SE, CI_lo, CI_hi.
rubins_rules <- function(Q_vec, U_vec = NULL) {
  m     <- length(Q_vec)
  Q_bar <- mean(Q_vec)
  V_B   <- var(Q_vec)
  V_W   <- if (!is.null(U_vec) && length(U_vec) == m) mean(U_vec) else 0
  V_T   <- V_W + V_B + V_B / m
  SE    <- sqrt(V_T)
  list(
    Q_bar = Q_bar, V_W = V_W, V_B = V_B, V_T = V_T,
    SE    = SE,
    CI_lo = Q_bar - 2.576 * SE,
    CI_hi = Q_bar + 2.576 * SE,
    m     = m
  )
}


# === 4. EXECUTION ===

main <- function() {
  aggregates  <- numeric(M)
  within_vars <- numeric(M)

  cat("--- 1  Loading imputed datasets and computing aggregates ---\n\n")

  for (i in 1:M) {
    filepath <- file.path(IMPUTED_DIR, sprintf("R_Imputed_Dataset_%d.csv", i))

    if (!file.exists(filepath)) {
      stop(sprintf("File not found: %s", filepath))
    }

    df <- read_csv(filepath, show_col_types = FALSE)

    df$Total_Opportunity_Cost <- df[["osm_acreage"]] * df[["Baseline_Value_Per_Acre"]]

    Q_i   <- sum(df$Total_Opportunity_Cost, na.rm = TRUE)
    Var_i <- var(df$Total_Opportunity_Cost, na.rm = TRUE)

    aggregates[i]  <- Q_i
    within_vars[i] <- Var_i

    cat(sprintf("  Dataset %d:  $%10.3f B\n", i, Q_i / 1e9))
  }

  cat("\n--- 2  Applying Rubin's Rules ---\n")

  # [METHODOLOGY] Rubin's Rules pooling — Q_bar is the pooled national estimate;
  #               V_T combines within- and between-imputation variance (Rubin 1987)
  pool   <- rubins_rules(aggregates, within_vars)
  Q_bar  <- pool$Q_bar
  V_W    <- pool$V_W
  V_B    <- pool$V_B
  V_T    <- pool$V_T
  SE     <- pool$SE
  CI_lo  <- pool$CI_lo
  CI_hi  <- pool$CI_hi

  cat("\n=== RUBIN'S RULES RESULTS ===\n")
  cat(sprintf("  Pooled Aggregate National Value:  $%10.3f B\n", Q_bar / 1e9))
  cat(sprintf("  Within-Imputation Variance (V_W): %.4e\n", V_W))
  cat(sprintf("  Between-Imputation Variance (V_B):%.4e\n", V_B))
  cat(sprintf("  Total Variance (V_T):             %.4e\n", V_T))
  cat(sprintf("  Standard Error:                   $%10.3f B\n", SE / 1e9))
  cat(sprintf(
    "  95%% Confidence Interval:          $%10.3f B - $%10.3f B\n",
    CI_lo / 1e9, CI_hi / 1e9
  ))

  pooled_df <- data.frame(
    Metric = c(
      "Pooled Aggregate National Value ($)",
      "Pooled Aggregate National Value ($B)",
      "Within-Imputation Variance (V_W)",
      "Between-Imputation Variance (V_B)",
      "Total Variance (V_T)",
      "Standard Error ($)",
      "95% CI Lower ($B)",
      "95% CI Upper ($B)",
      paste0("Dataset ", 1:M, " Aggregate ($B)")
    ),
    Value = c(
      format(Q_bar, big.mark = ",", scientific = FALSE),
      sprintf("%.3f", Q_bar / 1e9),
      sprintf("%.4e", V_W),
      sprintf("%.4e", V_B),
      sprintf("%.4e", V_T),
      format(SE, big.mark = ",", scientific = FALSE),
      sprintf("%.3f", CI_lo / 1e9),
      sprintf("%.3f", CI_hi / 1e9),
      sprintf("%.3f", aggregates / 1e9)
    )
  )

  write_csv(pooled_df, OUT_CSV)
  cat(sprintf("\n  [OK] Saved -> %s\n", OUT_CSV))
}

main()
