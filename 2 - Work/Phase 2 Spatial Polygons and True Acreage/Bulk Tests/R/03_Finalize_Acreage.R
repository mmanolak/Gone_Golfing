# Purpose: Coalesce OSM and Tigris acreage into final_acreage (acres), label
#          remaining unmatched rows as MICE_Target, and save pre-imputation dataset.
# Inputs:  Bulk Tests/R/R_Acreage_Step2_Tigris.csv
# Outputs: Bulk Tests/R/R_Phase2_Acreage_Matched_v2.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(wooldridge)
  library(tidyverse)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
STEP2_CSV  <- file.path(SCRIPT_DIR, "R_Acreage_Step2_Tigris.csv")
OUT_CSV    <- file.path(SCRIPT_DIR, "R_Phase2_Acreage_Matched_v2.csv")

SQ_FT_PER_ACRE <- 43560


# === 3. FUNCTIONS ===

print_separator <- function(char = "=") {
  cat(paste(rep(char, 80), collapse = ""), "\n")
}


# === 4. EXECUTION ===

if (!file.exists(STEP2_CSV)) {
  stop(paste("Input file not found:", STEP2_CSV,
             "\nDid Step 2 finish successfully?"))
}

print_separator()
cat("Phase 2: Finalize Acreage Matching for Imputation\n")
cat("Script: 03_Finalize_Acreage.R\n")
print_separator()


cat("\n[Step 1] Loading Step 2 Tigris output\n")

courses_df <- read_csv(STEP2_CSV, show_col_types = FALSE)
cat(sprintf("  Loaded %s courses\n", formatC(nrow(courses_df), big.mark = ",")))
cat(sprintf("  Available columns: %s\n", paste(names(courses_df), collapse = ", ")))


cat("\n[Step 2] Finalizing acreage_source column\n")

initial_missing <- sum(is.na(courses_df$acreage_source))
cat(sprintf("  Initial missing values in acreage_source: %d\n", initial_missing))

courses_df$acreage_source[is.na(courses_df$acreage_source)] <- "MICE_Target"

cat(sprintf("  Missing values after assignment: %d\n",
            sum(is.na(courses_df$acreage_source))))


cat("\n[Step 3] Building final_acreage column (acres)\n")

courses_df <- courses_df |>
  mutate(
    osm_acres    = if ("OSM_Area_SqFt"  %in% names(courses_df)) OSM_Area_SqFt / SQ_FT_PER_ACRE else NA_real_,
    tigris_acres = if ("tigris_acreage" %in% names(courses_df)) tigris_acreage else NA_real_,
    final_acreage = coalesce(osm_acres, tigris_acres)
  ) |>
  select(-any_of(c("osm_acres", "tigris_acres", "OSM_Area_SqFt", "Tigris_Area_SqFt")))

cat(sprintf("  final_acreage non-NA: %s (%.1f%%)\n",
            formatC(sum(!is.na(courses_df$final_acreage)), big.mark = ","),
            100 * mean(!is.na(courses_df$final_acreage))))


cat("\n[Step 4] Final summary\n")

print_separator()
cat("FINAL SUMMARY - Acreage Source Distribution\n")
print_separator()

source_counts <- courses_df |>
  count(acreage_source) |>
  mutate(
    Percentage            = round(n / sum(n) * 100, 2),
    Cumulative_Percentage = round(cumsum(n) / sum(n) * 100, 2)
  )

cat("\nAcreage Source Counts:\n")
print(source_counts)

if ("final_acreage" %in% names(courses_df)) {
  stats_by_source <- courses_df |>
    group_by(acreage_source) |>
    summarise(
      Count          = n(),
      Mean_Acreage   = if (all(is.na(final_acreage))) NA_real_ else round(mean(final_acreage,   na.rm = TRUE), 2),
      Median_Acreage = if (all(is.na(final_acreage))) NA_real_ else round(median(final_acreage, na.rm = TRUE), 2),
      Min_Acreage    = if (all(is.na(final_acreage))) NA_real_ else round(min(final_acreage,    na.rm = TRUE), 2),
      Max_Acreage    = if (all(is.na(final_acreage))) NA_real_ else round(max(final_acreage,    na.rm = TRUE), 2),
      .groups = "drop"
    ) |>
    arrange(acreage_source)
  cat("\nAdditional Statistics by Acreage Source:\n")
  print(stats_by_source)
}


cat("\n[Step 5] Saving final output\n")

write_csv(courses_df, OUT_CSV)
cat(sprintf("    Saved to: %s\n", OUT_CSV))

print_separator()
cat("[Complete] 03_Finalize_Acreage.R finished successfully.\n")
print_separator()
