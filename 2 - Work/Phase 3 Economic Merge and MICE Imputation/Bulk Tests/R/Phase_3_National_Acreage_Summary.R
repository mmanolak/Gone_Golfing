# Purpose: Calculate the total physical footprint of U.S. golf courses (acres)
#          across the 5 MICE-imputed datasets and break it down by county_type
#          (Urban / Rural).  Acreage is a fixed spatial measurement, not a
#          modelled quantity, so pooling is done by simple averaging across
#          imputations; between-imputation variance is reported for transparency.
# Inputs:  Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/R/National_Acreage_Summary.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR  <- this.path::this.dir()
IMPUTED_DIR <- normalizePath(file.path(SCRIPT_DIR, "..", "..", "Data", "R"))
OUT_CSV     <- file.path(SCRIPT_DIR, "National_Acreage_Summary.csv")

M <- 5


# === 3. FUNCTIONS ===

#' Pool a numeric vector of per-imputation totals by simple averaging.
#' Returns pooled mean, between-imputation SD, and a 99% CI based on
#' the between-imputation variance only (within-variance = 0 for acreage).
#' @param x Numeric vector of length M.
#' @return Named list: mean, sd_b, ci_lo, ci_hi.
pool_acreage <- function(x) {
  q_bar <- mean(x)
  v_b   <- var(x)
  se    <- sqrt(v_b + v_b / length(x))
  list(
    mean    = q_bar,
    sd_b    = sqrt(v_b),
    ci95_lo = q_bar - 1.960 * se,
    ci95_hi = q_bar + 1.960 * se,
    ci99_lo = q_bar - 2.576 * se,
    ci99_hi = q_bar + 2.576 * se
  )
}


# === 4. EXECUTION ===

main <- function() {
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("Phase 3 — National Acreage Summary\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  # ── Load all imputed datasets ──────────────────────────────────────────────
  national_totals   <- numeric(M)
  by_type_list      <- vector("list", M)

  cat(strrep("-", 70), "\n", sep = "")
  cat("[Step 1] Loading imputed datasets and computing acreage totals...\n\n")

  for (i in seq_len(M)) {
    path <- file.path(IMPUTED_DIR, sprintf("R_Imputed_Dataset_%d.csv", i))
    if (!file.exists(path)) stop(sprintf("[FATAL] File not found:\n  %s", path))

    df <- read_csv(path, show_col_types = FALSE)

    national_totals[i] <- sum(df$final_acreage, na.rm = TRUE)

    by_type_list[[i]] <- df |>
      group_by(county_type) |>
      summarise(acreage = sum(final_acreage, na.rm = TRUE), .groups = "drop") |>
      mutate(imputation = i)

    cat(sprintf("  Dataset %d:  %s acres  (%s Urban / %s Rural)\n",
      i,
      format(round(national_totals[i]), big.mark = ","),
      format(round(filter(by_type_list[[i]], county_type == "Urban")$acreage[1]), big.mark = ","),
      format(round(filter(by_type_list[[i]], county_type == "Rural")$acreage[1]), big.mark = ",")
    ))
  }

  # ── Pool totals ────────────────────────────────────────────────────────────
  cat("\n", strrep("-", 70), "\n", sep = "")
  cat("[Step 2] Pooling across imputations...\n\n")

  nat_pool <- pool_acreage(national_totals)

  # Pool each county_type separately
  all_by_type <- bind_rows(by_type_list)
  type_pool <- all_by_type |>
    group_by(county_type) |>
    summarise(
      pooled_acres = mean(acreage),
      sd_b         = sd(acreage),
      ci95_lo      = pool_acreage(acreage)$ci95_lo,
      ci95_hi      = pool_acreage(acreage)$ci95_hi,
      ci99_lo      = pool_acreage(acreage)$ci99_lo,
      ci99_hi      = pool_acreage(acreage)$ci99_hi,
      .groups = "drop"
    ) |>
    arrange(desc(pooled_acres))

  # ── Console output ─────────────────────────────────────────────────────────
  cat(strrep("=", 70), "\n", sep = "")
  cat("NATIONAL ACREAGE SUMMARY — POOLED RESULTS\n")
  cat(strrep("=", 70), "\n", sep = "")

  cat(sprintf("\n  %-38s %s\n", "NATIONAL TOTAL (all types)", "Pooled Acres"))
  cat(sprintf("  %-38s %s\n", strrep("-", 38), strrep("-", 20)))
  cat(sprintf("  %-38s %s\n",
    "Total U.S. Golf Acreage",
    format(round(nat_pool$mean), big.mark = ",")
  ))
  cat(sprintf("  %-38s %s\n",
    "Between-Imputation SD",
    format(round(nat_pool$sd_b, 2), big.mark = ",")
  ))
  cat(sprintf("  %-38s %s - %s\n",
    "99% CI",
    format(round(nat_pool$ci99_lo), big.mark = ","),
    format(round(nat_pool$ci99_hi), big.mark = ",")
  ))
  cat(sprintf("  %-38s %s - %s\n",
    "95% CI",
    format(round(nat_pool$ci95_lo), big.mark = ","),
    format(round(nat_pool$ci95_hi), big.mark = ",")
  ))

  cat(sprintf("\n  %-20s %15s %15s %15s\n",
    "County Type", "Pooled Acres", "SD (between)", "99% CI"))
  cat(sprintf("  %-20s %15s %15s %15s\n",
    strrep("-", 20), strrep("-", 15), strrep("-", 15), strrep("-", 15)))

  for (i in seq_len(nrow(type_pool))) {
    row <- type_pool[i, ]
    cat(sprintf("  %-20s %15s %15s %s - %s\n",
      row$county_type,
      format(round(row$pooled_acres), big.mark = ","),
      format(round(row$sd_b, 2),      big.mark = ","),
      format(round(row$ci99_lo),      big.mark = ","),
      format(round(row$ci99_hi),      big.mark = ",")
    ))
  }
  cat(strrep("=", 70), "\n\n", sep = "")

  # ── Save CSV ───────────────────────────────────────────────────────────────
  summary_df <- bind_rows(
    tibble(
      Category          = "National Total",
      County_Type       = "All",
      Pooled_Acres      = round(nat_pool$mean, 2),
      SD_Between        = round(nat_pool$sd_b, 4),
      CI_95_Lower_Acres = round(nat_pool$ci95_lo, 2),
      CI_95_Upper_Acres = round(nat_pool$ci95_hi, 2),
      CI_99_Lower_Acres = round(nat_pool$ci99_lo, 2),
      CI_99_Upper_Acres = round(nat_pool$ci99_hi, 2)
    ),
    type_pool |>
      transmute(
        Category          = "By County Type",
        County_Type       = county_type,
        Pooled_Acres      = round(pooled_acres, 2),
        SD_Between        = round(sd_b, 4),
        CI_95_Lower_Acres = round(ci95_lo, 2),
        CI_95_Upper_Acres = round(ci95_hi, 2),
        CI_99_Lower_Acres = round(ci99_lo, 2),
        CI_99_Upper_Acres = round(ci99_hi, 2)
      )
  )

  write_csv(summary_df, OUT_CSV)
  cat(sprintf("  [+] Summary saved -> %s\n\n", basename(OUT_CSV)))
  cat("[DONE] National Acreage Summary complete.\n\n")
}

main()
