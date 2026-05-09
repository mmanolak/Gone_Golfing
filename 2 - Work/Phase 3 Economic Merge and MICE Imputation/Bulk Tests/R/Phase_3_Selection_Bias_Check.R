# Purpose: Check for selection bias between courses included vs. excluded
#          from MICE imputation (complete cases vs. rows with missing data).
# Inputs:  Phase 2 Spatial Polygons and True Acreage/
#            R_Phase2_Acreage_Matched_v2.csv
# Outputs: Bulk Tests/R/Selection_Bias_Comparison.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
INPUT_CSV  <- file.path(
  SCRIPT_DIR, "..", "..", "..",
  "Phase 2 Spatial Polygons and True Acreage",
  "R_Phase2_Acreage_Matched_v2.csv"
)
OUT_CSV <- file.path(SCRIPT_DIR, "Selection_Bias_Comparison.csv")


# === 3. FUNCTIONS ===

#' Compute summary statistics for one group (included or excluded).
#' @param df    Data frame for the group.
#' @param label Character label for the Group column.
#' @return Single-row data.frame with means, SDs, and ownership counts.
calc_stats <- function(df, label) {
  stats <- data.frame(
    Group          = label,
    N              = nrow(df),
    Mean_Holes     = mean(df$Holes, na.rm = TRUE),
    SD_Holes       = sd(df$Holes, na.rm = TRUE),
    Min_Holes      = min(df$Holes, na.rm = TRUE),
    Max_Holes      = max(df$Holes, na.rm = TRUE),
    Mean_Longitude = mean(df$Longitude, na.rm = TRUE),
    Mean_Latitude  = mean(df$Latitude, na.rm = TRUE),
    Urban_Prop     = sum(df$RUCC_2023 <= 3, na.rm = TRUE) / nrow(df),
    stringsAsFactors = FALSE
  )

  ownership_dist <- table(df$Ownership_Type)
  for (ot in names(ownership_dist)) {
    stats[[paste0("Own_", ot)]]       <- ownership_dist[ot]
    stats[[paste0("Own_", ot, "_Prop")]] <- ownership_dist[ot] / nrow(df)
  }

  return(stats)
}


# === 4. EXECUTION ===

cat("Loading pre-imputation dataset...\n")

if (!file.exists(INPUT_CSV)) {
  stop(paste("ERROR: Input file not found at:", INPUT_CSV))
}

acreage_df <- read.csv(INPUT_CSV, stringsAsFactors = FALSE)
cat(sprintf("Loaded %d observations\n", nrow(acreage_df)))

cat("Creating selection indicator (is_missing)...\n")

acreage_df$is_missing <- is.na(acreage_df$final_acreage) |
  is.na(acreage_df$Baseline_Value_Per_Acre)
acreage_df$is_missing_label <- ifelse(
  acreage_df$is_missing,
  "Excluded (has NA)",
  "Included (complete data)"
)

cat("Calculating comparison statistics...\n")

included_df <- acreage_df[!acreage_df$is_missing, ]
excluded_df <- acreage_df[acreage_df$is_missing,  ]

cat(sprintf("\nGroup sizes:\n"))
cat(sprintf(
  "  Included (complete): %d courses (%.1f%%)\n",
  nrow(included_df), 100 * nrow(included_df) / nrow(acreage_df)
))
cat(sprintf(
  "  Excluded (has NA):   %d courses (%.1f%%)\n",
  nrow(excluded_df), 100 * nrow(excluded_df) / nrow(acreage_df)
))

included_stats <- calc_stats(included_df, "Included")
excluded_stats <- calc_stats(excluded_df, "Excluded")

comparison_table <- rbind(included_stats, excluded_stats)

cat(sprintf(
  "\n%-12s %10s %15s (%s) %15s (%s)\n",
  "Variable", "Group", "Mean (SD)", "Min-Max", "Mean (SD)", "Min-Max"
))
cat(paste(rep("=", 95), collapse = ""), "\n")

cat(sprintf(
  "%-12s %10s %15.1f (%.1f) %13d-%-d\n",
  "Holes", "Included",
  included_stats$Mean_Holes, included_stats$SD_Holes,
  included_stats$Min_Holes, included_stats$Max_Holes
))
cat(sprintf(
  "%-12s %10s %15.1f (%.1f) %13d-%-d\n",
  "", "Excluded",
  excluded_stats$Mean_Holes, excluded_stats$SD_Holes,
  excluded_stats$Min_Holes, excluded_stats$Max_Holes
))
cat(sprintf(
  "%-12s %10s %15s %27.1f difference\n",
  "", "Diff", "",
  included_stats$Mean_Holes - excluded_stats$Mean_Holes
))

cat(paste(rep("-", 95), collapse = ""), "\n")
cat(sprintf(
  "%-12s %10s %15.4f %26.4f\n",
  "Longitude", "Included",
  included_stats$Mean_Longitude, excluded_stats$Mean_Longitude
))
cat(sprintf(
  "%-12s %10s %15.4f %27.4f\n",
  "", "Excluded",
  included_stats$Mean_Latitude, excluded_stats$Mean_Latitude
))

cat(paste(rep("-", 95), collapse = ""), "\n")
cat(sprintf(
  "%-12s %10s %15.3f (%.1f%%) %24.3f (%.1f%%)\n",
  "Urban (RUCC<=3)", "Included",
  included_stats$Urban_Prop, 100 * included_stats$Urban_Prop,
  excluded_stats$Urban_Prop, 100 * excluded_stats$Urban_Prop
))
cat(sprintf(
  "%-12s %10s %15s %43.3f difference\n",
  "", "Diff", "",
  included_stats$Urban_Prop - excluded_stats$Urban_Prop
))

cat(paste(rep("-", 95), collapse = ""), "\n")

own_types <- names(included_stats)[
  grep("^Own_", names(included_stats)) &
    !grepl("_Prop", names(included_stats))
]
for (ot in gsub("Own_", "", own_types)) {
  inc_count <- included_stats[[paste0("Own_", ot)]]
  inc_prop  <- included_stats[[paste0("Own_", ot, "_Prop")]]
  exc_count <- excluded_stats[[paste0("Own_", ot)]]
  exc_prop  <- excluded_stats[[paste0("Own_", ot, "_Prop")]]
  cat(sprintf(
    "%-12s %-20s %10d (%.1f%%) %24d (%.1f%%)\n",
    "Ownership", if (ot == own_types[1]) "Included" else "",
    inc_count, 100 * inc_prop,
    exc_count, 100 * exc_prop
  ))
}

cat("\n=== Summary Statistics Table ===\n")
print(
  comparison_table[, !(names(comparison_table) %in%
    grep("_Prop", names(comparison_table), value = TRUE))],
  row.names = FALSE
)

cat("\n=== Chi-Square Test: Ownership Type Distribution ===\n")
ownership_table <- table(acreage_df$Ownership_Type, acreage_df$is_missing)
print(ownership_table)

chi_sq_test <- chisq.test(ownership_table)
cat(sprintf("\nChi-squared statistic: %.4f\n", chi_sq_test$statistic))
cat(sprintf("Degrees of freedom: %d\n",       chi_sq_test$parameter))
cat(sprintf("p-value: %.6f\n",                chi_sq_test$p.value))

cat("\n=== T-Tests: Continuous Variables ===\n")

holes_test <- t.test(Holes ~ is_missing, data = acreage_df)
cat(sprintf("\nHoles (t-test):\n"))
cat(sprintf("  t-statistic: %.4f\n", holes_test$statistic))
cat(sprintf("  p-value: %.6f\n",     holes_test$p.value))

lon_test <- t.test(Longitude ~ is_missing, data = acreage_df)
cat(sprintf("\nLongitude (t-test):\n"))
cat(sprintf("  t-statistic: %.4f\n", lon_test$statistic))
cat(sprintf("  p-value: %.6f\n",     lon_test$p.value))

lat_test <- t.test(Latitude ~ is_missing, data = acreage_df)
cat(sprintf("\nLatitude (t-test):\n"))
cat(sprintf("  t-statistic: %.4f\n", lat_test$statistic))
cat(sprintf("  p-value: %.6f\n",     lat_test$p.value))

write.csv(comparison_table, OUT_CSV, row.names = FALSE)
cat(sprintf("\nComparison table saved to %s\n", OUT_CSV))
