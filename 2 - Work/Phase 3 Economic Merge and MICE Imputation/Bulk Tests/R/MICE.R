# Purpose: Run MICE imputation (m=5, Random Forest) on the Phase 2
#          acreage-matched dataset to fill missing osm_acreage and
#          Baseline_Value_Per_Acre values.
# Inputs:  Phase 2 Spatial Polygons and True Acreage/R_Phase2_Acreage_Matched.csv
# Outputs: Bulk Tests/R/R_Imputed_Dataset_{1..5}.csv


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
INPUT_CSV  <- file.path(
  SCRIPT_DIR, "..", "..", "..",
  "Phase 2 Spatial Polygons and True Acreage",
  "R_Phase2_Acreage_Matched.csv"
)
OUT_DIR <- SCRIPT_DIR

M              <- 5
IMPUTE_COLS    <- c("osm_acreage", "Baseline_Value_Per_Acre")
PREDICTOR_COLS <- c("Holes", "Ownership_Type", "county_type", "Longitude", "Latitude")

SAFE_WORKERS <- min(availableCores() - 8, 20)
SAFE_WORKERS <- max(SAFE_WORKERS, 1L)
options(future.globals.maxSize = 20 * 1024^3)
plan(multisession, workers = SAFE_WORKERS)

set.seed(42)  # [METHODOLOGY] reproducibility seed for stochastic MICE imputation


# === 3. EXECUTION ===

if (!file.exists(INPUT_CSV)) {
  stop(paste("Input file not found:", INPUT_CSV))
}

cat("Loading data from:", INPUT_CSV, "\n")
acreage_df <- read.csv(INPUT_CSV, stringsAsFactors = FALSE)
cat("Data loaded. Dimensions:", nrow(acreage_df), "rows,", ncol(acreage_df), "columns\n")

cat("\nColumn names in dataset:\n")
print(names(acreage_df))

cat("\nMissing values check:\n")
cat("osm_acreage - Missing:", sum(is.na(acreage_df$osm_acreage)), "\n")
cat("Baseline_Value_Per_Acre - Missing:", sum(is.na(acreage_df$Baseline_Value_Per_Acre)), "\n")

course_col <- if ("Course_Type" %in% names(acreage_df)) "Course_Type" else "Ownership_Type"
predictors <- c("Holes", course_col, "county_type", "Longitude", "Latitude")

imp_df <- acreage_df[, c(predictors, IMPUTE_COLS)]

cat("\nVariables to be imputed:", paste(IMPUTE_COLS, collapse = ", "), "\n")
cat("Predictor variables:", paste(predictors, collapse = ", "), "\n")
cat("\nRunning MICE imputation in PARALLEL...\n")
cat(sprintf(
  "Parameters: m=%d (datasets), method='rf' (Random Forests), seed=42, workers=%d\n",
  M, SAFE_WORKERS
))

# [METHODOLOGY] futuremice — parallel MICE with Random Forest; tree-based to avoid
#               negative predictions and handle mixed predictor types natively
imputed_list <- futuremice(
  data         = imp_df,
  m            = M,
  method       = "rf",
  parallelseed = 42,
  maxit        = 10
)

cat("\nMICE imputation completed successfully!\n")
cat("\nSaving imputed datasets...\n")

for (i in 1:M) {
  complete_data <- complete(imputed_list, i)
  output_file   <- file.path(OUT_DIR, sprintf("R_Imputed_Dataset_%d.csv", i))
  write.csv(complete_data, output_file, row.names = FALSE)
  cat("Saved:", output_file, "\n")
}

cat("\n=== MICE Imputation Complete ===\n")
cat("All", M, "imputed datasets saved to:", OUT_DIR, "\n")
