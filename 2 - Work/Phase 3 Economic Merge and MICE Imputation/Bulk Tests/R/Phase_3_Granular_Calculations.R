# Purpose: For each of the 5 R-imputed datasets, compute Total_Opportunity_Cost,
#          urban-only aggregate, and per-Census-Division aggregates.
# Inputs:  Bulk Tests/R/R_Imputed_Dataset_{1..5}.csv
#          Phase 2 Spatial Polygons and True Acreage/R_Phase2_Acreage_Matched.csv
# Outputs: Bulk Tests/R/R_Granular_Estimates.rds
#
# Strategy: MICE imputed datasets contain only the imputed columns; state and
#   county_type are re-attached from the Phase 2 source file, which shares the
#   same row order as the imputed output.


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR   <- this.path::this.dir()
PHASE2_SOURCE <- file.path(
  SCRIPT_DIR, "..", "..",
  "Phase 2 Spatial Polygons and True Acreage",
  "R_Phase2_Acreage_Matched.csv"
)
OUT_RDS <- file.path(SCRIPT_DIR, "R_Granular_Estimates.rds")

M <- 5

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

ALL_DIVISIONS <- c(
  "New England", "Middle Atlantic", "East North Central",
  "West North Central", "South Atlantic", "East South Central",
  "West South Central", "Mountain", "Pacific"
)


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

cat("=== Phase 3 Granular Calculations ===\n")
cat("Script directory :", SCRIPT_DIR, "\n")
cat("Phase 2 source   :", PHASE2_SOURCE, "\n\n")

if (!file.exists(PHASE2_SOURCE)) {
  stop(paste(
    "Phase 2 source file not found:\n ", PHASE2_SOURCE,
    "\nPlease verify the path and re-run."
  ))
}

meta_df <- read_csv(PHASE2_SOURCE, show_col_types = FALSE)
cat(
  "Phase 2 metadata loaded:",
  nrow(meta_df), "rows,", ncol(meta_df), "columns.\n"
)

needed_meta <- c("State_Abbr", "county_type")
missing_cols <- setdiff(needed_meta, names(meta_df))
if (length(missing_cols) > 0) {
  stop(paste(
    "Required columns missing from Phase 2 file:",
    paste(missing_cols, collapse = ", ")
  ))
}

meta_df <- meta_df |>
  mutate(
    Census_Division = DIVISION_MAP[State_Abbr],
    Census_Division = if_else(
      is.na(Census_Division), "Unknown", Census_Division
    )
  )

n_unknown <- sum(meta_df$Census_Division == "Unknown")
if (n_unknown > 0) {
  warning(
    n_unknown,
    " rows could not be assigned to a Census Division ",
    "(State_Abbr not in mapping). Excluded from division totals."
  )
}

granular_list <- vector("list", M)

cat("\n--- Processing imputed datasets ---\n\n")

for (i in seq_len(M)) {
  imp_file <- file.path(SCRIPT_DIR, sprintf("R_Imputed_Dataset_%d.csv", i))

  if (!file.exists(imp_file)) {
    stop(paste("Imputed dataset not found:", imp_file))
  }

  imp_df <- read_csv(imp_file, show_col_types = FALSE)

  if (nrow(imp_df) != nrow(meta_df)) {
    stop(sprintf(
      "Row count mismatch for dataset %d: imputed=%d, metadata=%d",
      i, nrow(imp_df), nrow(meta_df)
    ))
  }

  imp_df$Total_Opportunity_Cost <-
    imp_df$osm_acreage * imp_df$Baseline_Value_Per_Acre

  imp_df$county_type     <- meta_df$county_type
  imp_df$Census_Division <- meta_df$Census_Division

  urban_df    <- imp_df |> filter(county_type == "Urban")
  urban_total <- sum(urban_df$Total_Opportunity_Cost, na.rm = TRUE)
  urban_var   <- var(urban_df$Total_Opportunity_Cost, na.rm = TRUE)
  urban_n     <- nrow(urban_df)

  division_results <- imp_df |>
    filter(Census_Division != "Unknown") |>
    group_by(Census_Division) |>
    summarise(
      Aggregate_Value = sum(Total_Opportunity_Cost, na.rm = TRUE),
      Within_Variance = var(Total_Opportunity_Cost, na.rm = TRUE),
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

  all_divisions_list <- setNames(
    division_results$Aggregate_Value,
    division_results$Census_Division
  )

  granular_list[[i]] <- list(
    dataset_number      = i,
    total_courses       = nrow(imp_df),
    urban_n             = urban_n,
    urban_total         = urban_total,
    urban_var           = urban_var,
    division_aggregates = division_results,
    all_divisions_list  = all_divisions_list
  )

  cat(sprintf(
    "  Dataset %d: national=$%.3f B | urban=$%.3f B | courses=%d\n",
    i,
    sum(imp_df$Total_Opportunity_Cost, na.rm = TRUE) / 1e9,
    urban_total / 1e9,
    nrow(imp_df)
  ))
}

saveRDS(granular_list, file = OUT_RDS)

cat("\n=== Intermediate calculations complete ===\n")
cat(sprintf("Saved R_Granular_Estimates.rds -> %s\n", OUT_RDS))
cat("Structure: list of", M, "lists, one per imputed dataset.\n")
cat("Each sub-list contains:\n")
cat("  $dataset_number      : imputation index (1-5)\n")
cat("  $total_courses       : total row count\n")
cat("  $urban_n             : number of Urban courses\n")
cat("  $urban_total         : sum(Total_Opportunity_Cost) for Urban\n")
cat("  $urban_var           : within-dataset variance for Urban\n")
cat("  $division_aggregates : data.frame with Aggregate_Value per division\n")
cat("  $all_divisions_list  : named numeric vector for pooling step\n")
cat("\nReady for Phase_3_Granular_Pooling.R\n")
