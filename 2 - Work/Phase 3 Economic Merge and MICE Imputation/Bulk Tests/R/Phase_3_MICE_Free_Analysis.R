# Purpose: Complete case analysis (MICE-free) — loads the pre-imputation
#          dataset and computes aggregate national and urban-only land values
#          using only courses with no missing acreage or value data.
# Inputs:  Phase 2 Spatial Polygons and True Acreage/Bulk Tests/R/
#            R_Phase2_Acreage_Matched_v2.csv
# Outputs: Console-printed summary.


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
  "Bulk Tests", "R",
  "R_Phase2_Acreage_Matched_v2.csv"
)

COMPLETE_COLS <- c("final_acreage", "Baseline_Value_Per_Acre")


# === 3. FUNCTIONS ===

print_separator <- function(char = "=") {
  cat(paste(rep(char, 80), collapse = ""), "\n")
}


# === 4. EXECUTION ===

cat("\n")
print_separator()
cat("Phase 3: Complete Case Analysis (MICE-Free)\n")
cat("Script: Phase_3_MICE_Free_Analysis.R\n")
print_separator()

cat("\n[Step 1] Loading pre-imputation dataset...\n")

if (!file.exists(INPUT_CSV)) {
  stop(paste("ERROR: Input file not found at:", INPUT_CSV))
}

acreage_df <- read.csv(INPUT_CSV, stringsAsFactors = FALSE)
cat(sprintf("  Loaded %d courses from %s\n", nrow(acreage_df), INPUT_CSV))

cat("\n[Step 2] Creating complete case dataframe...\n")

cat(sprintf("  Before filter: %d rows\n", nrow(acreage_df)))

df_complete <- acreage_df |>
  filter(!is.na(final_acreage) & !is.na(Baseline_Value_Per_Acre))

cat(sprintf(
  "  After filtering on '%s': %d rows\n",
  paste(COMPLETE_COLS, collapse = ", "),
  nrow(df_complete)
))
cat(sprintf(
  "  Removed %d rows with missing values\n",
  nrow(acreage_df) - nrow(df_complete)
))

cat("\n[Step 3] Calculating Total_Opportunity_Cost...\n")

df_complete <- df_complete |>
  mutate(Total_Opportunity_Cost = final_acreage * Baseline_Value_Per_Acre)

cat("  Created new column: Total_Opportunity_Cost\n")
cat(sprintf(
  "  Mean opportunity cost per course: $%s\n",
  format(round(mean(df_complete$Total_Opportunity_Cost, na.rm = TRUE), 2),
    big.mark = ","
  )
))
cat(sprintf(
  "  Median opportunity cost per course: $%s\n",
  format(round(median(df_complete$Total_Opportunity_Cost, na.rm = TRUE), 2),
    big.mark = ","
  )
))

cat("\n[Step 4] Calculating Aggregate National Value...\n")

national_value <- sum(df_complete$Total_Opportunity_Cost, na.rm = TRUE)
cat(sprintf(
  "  MICE-Free National Value: $%s\n",
  format(round(national_value, 2), big.mark = ",")
))

cat("\n[Step 5] Calculating Aggregate Urban-Only Value...\n")

urban_df <- df_complete |> filter(county_type == "Urban")

if (nrow(urban_df) > 0) {
  urban_value <- sum(urban_df$Total_Opportunity_Cost, na.rm = TRUE)
  cat(sprintf("  Urban courses in complete case: %d\n", nrow(urban_df)))
  cat(sprintf(
    "  MICE-Free Urban-Only Value: $%s\n",
    format(round(urban_value, 2), big.mark = ",")
  ))
} else {
  urban_value <- NA
  warning("No Urban counties found in the dataset.")
}

cat("\n[Step 6] Printing final summary...\n")

print_separator()
cat("FINAL SUMMARY - Complete Case Analysis (MICE-Free)\n")
print_separator()

cat(sprintf(
  "\nNumber of courses in complete case analysis: %d\n",
  nrow(df_complete)
))
cat(sprintf(
  "\nMICE-Free National Value:\t$%s\n",
  format(round(national_value, 2), big.mark = ",")
))
if (!is.na(urban_value)) {
  cat(sprintf(
    "MICE-Free Urban-Only Value:\t$%s\n",
    format(round(urban_value, 2), big.mark = ",")
  ))
}

print_separator()
cat("[Complete] Script finished successfully.\n")
print_separator()
