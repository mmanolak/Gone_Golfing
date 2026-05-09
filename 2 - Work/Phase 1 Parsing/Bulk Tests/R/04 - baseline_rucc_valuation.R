# Purpose: Join 2023 RUCC codes onto valuation-joined golf courses, classify
#          counties as Urban (RUCC 1–3) or Rural (RUCC 4–9), and assign
#          Baseline_Value_Per_Acre (Urban → FHFA residential, Rural → USDA ag).
# Inputs:  Bulk Tests/R/R_Phase1_Valuation_Joined_Golf_Courses.csv
#          https://www.ers.usda.gov/media/5768/2023-rural-urban-continuum-codes.csv
# Outputs: Bulk Tests/R/R_Phase1_Baseline_Golf_Valuation.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(wooldridge)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()

GOLF_IN  <- file.path(SCRIPT_DIR, "R_Phase1_Valuation_Joined_Golf_Courses.csv")
RUCC_URL <- "https://www.ers.usda.gov/media/5768/2023-rural-urban-continuum-codes.csv?v=98246"
OUT_CSV  <- file.path(SCRIPT_DIR, "R_Phase1_Baseline_Golf_Valuation.csv")


# === 3. EXECUTION ===

cat("--- 1  Loading valuation-joined golf courses ---\n")
if (!file.exists(GOLF_IN)) stop(paste("Input file not found:", GOLF_IN))
courses_df <- read_csv(GOLF_IN, show_col_types = FALSE) |>
  mutate(FIPS = str_pad(as.character(FIPS), width = 5, pad = "0"))
cat(sprintf("    Rows: %s\n", formatC(nrow(courses_df), big.mark = ",")))

cat("--- 2  Fetching 2023 RUCC data from USDA ERS ---\n")
rucc_df <- read_csv(RUCC_URL,
  locale = locale(encoding = "latin1"),
  show_col_types = FALSE
)

# RUCC source is long-format with multiple attributes per FIPS — isolate RUCC_2023 to get one code per county
rucc_df <- rucc_df |>
  filter(Attribute == "RUCC_2023") |>
  mutate(
    FIPS = str_pad(as.character(FIPS), width = 5, pad = "0"),
    RUCC_2023 = as.integer(Value)
  ) |>
  distinct(FIPS, .keep_all = TRUE) |>
  select(FIPS, RUCC_2023)
cat(sprintf("    RUCC counties fetched: %s\n", formatC(nrow(rucc_df), big.mark = ",")))

cat("--- 3  Merging RUCC onto golf courses ---\n")
courses_df <- courses_df |>
  left_join(rucc_df, by = "FIPS")

cat("--- 4  Classifying Urban / Rural ---\n")
courses_df <- courses_df |>
  mutate(
    county_type = case_when(
      RUCC_2023 %in% 1:3 ~ "Urban",
      RUCC_2023 %in% 4:9 ~ "Rural",
      TRUE ~ NA_character_
    )
  )

cat("--- 5  Building Baseline_Value_Per_Acre ---\n")
courses_df <- courses_df |>
  mutate(
    Baseline_Value_Per_Acre = case_when(
      county_type == "Urban" ~ FHFA_Res_Value_Per_Acre,
      county_type == "Rural" ~ USDA_Ag_Value_Per_Acre,
      TRUE ~ NA_real_
    )
  )

urban        <- sum(courses_df$county_type == "Urban", na.rm = TRUE)
rural        <- sum(courses_df$county_type == "Rural", na.rm = TRUE)
unclassified <- sum(is.na(courses_df$county_type))
missing_base <- sum(is.na(courses_df$Baseline_Value_Per_Acre))
bv           <- courses_df$Baseline_Value_Per_Acre[!is.na(courses_df$Baseline_Value_Per_Acre)]

cat("\n=== OUTPUT STATISTICS ===\n")
cat(sprintf("  Urban courses:            %s\n", formatC(urban, big.mark = ",")))
cat(sprintf("  Rural courses:            %s\n", formatC(rural, big.mark = ",")))
cat(sprintf("  Unclassified (no RUCC):   %d\n", unclassified))
cat(sprintf(
  "  Missing Baseline value:   %s  (MICE imputation target)\n",
  formatC(missing_base, big.mark = ",")
))
cat("\n  Baseline_Value_Per_Acre summary:\n")
cat(sprintf("    Min:    $%14s\n", formatC(min(bv), format = "f", digits = 2, big.mark = ",")))
cat(sprintf("    Median: $%14s\n", formatC(median(bv), format = "f", digits = 2, big.mark = ",")))
cat(sprintf("    Mean:   $%14s\n", formatC(mean(bv), format = "f", digits = 2, big.mark = ",")))
cat(sprintf("    Max:    $%14s\n", formatC(max(bv), format = "f", digits = 2, big.mark = ",")))

write_csv(courses_df, OUT_CSV)
cat(sprintf("\n  [OK] Saved -> %s\n", OUT_CSV))
