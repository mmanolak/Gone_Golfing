# Purpose: Left-join USDA county ag-land values and FHFA residential land prices
#          onto spatially-joined golf course records by FIPS code.
# Inputs:  Bulk Tests/R/R_Phase1_Spatial_Joined_Golf_Courses.csv
#          00 - Data Sources/Original Data/2022 - USDA County Data - Ag Use.csv
#          00 - Data Sources/Original Data/2024 - FHFA June 20 Land Prices.xlsx
# Outputs: Bulk Tests/R/R_Phase1_Valuation_Joined_Golf_Courses.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(wooldridge)
  library(readxl)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
ROOT_DIR   <- file.path(SCRIPT_DIR, "..", "..", "..")
DATA_DIR   <- file.path(ROOT_DIR, "00 - Data Sources", "Original Data")

GOLF_IN <- file.path(SCRIPT_DIR, "R_Phase1_Spatial_Joined_Golf_Courses.csv")
USDA_IN <- file.path(DATA_DIR, "2022 - USDA County Data - Ag Use.csv")
FHFA_IN <- file.path(DATA_DIR, "2024 - FHFA June 20 Land Prices.xlsx")
OUT_CSV <- file.path(SCRIPT_DIR, "R_Phase1_Valuation_Joined_Golf_Courses.csv")


# === 3. EXECUTION ===

cat("--- 1  Loading spatially-joined golf courses ---\n")
if (!file.exists(GOLF_IN)) stop(paste("Input file not found:", GOLF_IN))
courses_df <- read_csv(GOLF_IN, show_col_types = FALSE) |>
  mutate(FIPS = str_pad(as.character(FIPS), width = 5, pad = "0"))
cat(sprintf("    Rows: %s\n", formatC(nrow(courses_df), big.mark = ",")))

cat("--- 2  Processing USDA County Ag-Use data ---\n")
if (!file.exists(USDA_IN)) stop(paste("Input file not found:", USDA_IN))
usda_df <- read_csv(USDA_IN, show_col_types = FALSE) |>
  filter(`Data Item` == "AG LAND, INCL BUILDINGS - ASSET VALUE, MEASURED IN $ / ACRE") |>
  mutate(
    state_fips  = str_pad(as.character(as.integer(`State ANSI`)), 2, pad = "0"),
    county_fips = str_pad(as.character(as.integer(`County ANSI`)), 3, pad = "0"),
    FIPS = paste0(state_fips, county_fips),
    USDA_Ag_Value_Per_Acre = as.numeric(gsub(",", "", Value))
  ) |>
  filter(!is.na(USDA_Ag_Value_Per_Acre)) |>
  distinct(FIPS, .keep_all = TRUE) |>
  select(FIPS, USDA_Ag_Value_Per_Acre)
cat(sprintf("    USDA counties loaded: %s\n", formatC(nrow(usda_df), big.mark = ",")))

cat("--- 3  Processing FHFA Panel Counties data ---\n")
if (!file.exists(FHFA_IN)) stop(paste("Input file not found:", FHFA_IN))
fhfa_df <- read_excel(FHFA_IN, sheet = "Panel Counties", skip = 1) |>
  filter(Year == 2022) |>
  mutate(FIPS = str_pad(as.character(FIPS), width = 5, pad = "0"))

# The column name contains a literal newline; find it by pattern
as_is_col <- grep("Per Acre, As-Is", names(fhfa_df), value = TRUE)
fhfa_df <- fhfa_df |>
  mutate(FHFA_Res_Value_Per_Acre = as.numeric(.data[[as_is_col]])) |>
  distinct(FIPS, .keep_all = TRUE) |>
  select(FIPS, FHFA_Res_Value_Per_Acre)
cat(sprintf("    FHFA counties loaded: %s\n", formatC(nrow(fhfa_df), big.mark = ",")))

cat("--- 4  Left-joining proxies onto golf courses ---\n")
courses_df <- courses_df |>
  left_join(usda_df, by = "FIPS") |>
  left_join(fhfa_df, by = "FIPS")

n        <- nrow(courses_df)
usda_hit <- sum(!is.na(courses_df$USDA_Ag_Value_Per_Acre))
fhfa_hit <- sum(!is.na(courses_df$FHFA_Res_Value_Per_Acre))

cat("\n=== OUTPUT STATISTICS ===\n")
cat(sprintf("  Total golf courses:   %s\n", formatC(n, big.mark = ",")))
cat(sprintf(
  "  USDA match rate:      %s / %s  (%.2f%%)\n",
  formatC(usda_hit, big.mark = ","), formatC(n, big.mark = ","),
  100 * usda_hit / n
))
cat(sprintf(
  "  FHFA match rate:      %s / %s  (%.2f%%)\n",
  formatC(fhfa_hit, big.mark = ","), formatC(n, big.mark = ","),
  100 * fhfa_hit / n
))
cat("\n  First 5 rows:\n")
print(head(courses_df |> select(
  Course_Name, FIPS, County_Name,
  USDA_Ag_Value_Per_Acre, FHFA_Res_Value_Per_Acre
), 5))

write_csv(courses_df, OUT_CSV)
cat(sprintf("\n  [OK] Saved -> %s\n", OUT_CSV))
