# Purpose: Parse raw USA golf course CSV via regex into structured fields,
#          deduplicate by coordinate and name, and assign stable course IDs.
# Inputs:  00 - Data Sources/Original Data/Golf Courses-USA.csv
# Outputs: Bulk Tests/R/R_Phase1_Parsed_Golf_Courses.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(wooldridge)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
ROOT_DIR   <- file.path(SCRIPT_DIR, "..", "..", "..")

RAW_CSV <- file.path(ROOT_DIR, "00 - Data Sources", "Original Data", "Golf Courses-USA.csv")
OUT_CSV <- file.path(SCRIPT_DIR, "R_Phase1_Parsed_Golf_Courses.csv")


# === 3. EXECUTION ===

if (!file.exists(RAW_CSV)) stop(paste("Input file not found:", RAW_CSV))

courses_df <- read_csv(RAW_CSV,
  col_names = c("Longitude", "Latitude", "Name_State", "Details"),
  show_col_types = FALSE
)
original_n <- nrow(courses_df)

courses_df <- courses_df |>
  mutate(
    Course_Name = str_remove(Name_State, "-.*$"),
    State_Abbr  = str_extract(Name_State, "[A-Z]{2}$"),

    # ownership type is encoded in the first parenthetical of the Details field
    Ownership_Type = str_extract(Details, "^\\([^)]+\\)"),
    Ownership_Type = str_remove_all(Ownership_Type, "[()]"),

    # hole count is the second parenthetical integer in Details
    Holes = as.numeric(str_extract(Details, "(?<=\\()\\d+(?= Holes\\))")),

    # zip code follows the state abbreviation in the Details string
    Zip_Code = str_extract(Details, paste0("(?<=", State_Abbr, " )\\d{5}")),

    # city is the comma-delimited token immediately before the state abbreviation
    City = str_extract(Details, paste0(",([^,]+),", State_Abbr)),
    City = str_remove(City, "^,\\s*"),
    City = str_remove(City, paste0(",", State_Abbr)),

    # address is the token between the closing parenthesis and the city/state pair
    Address = str_extract(Details, "\\), (.*?),(?=\\s*[^,]+,[A-Z]{2})"),
    Address = str_remove(Address, "^\\), "),
    Address = str_remove(Address, ",$")
  ) |>
  select(Longitude, Latitude, Course_Name, State_Abbr, Ownership_Type, Holes, Address, City, Zip_Code)

courses_df <- courses_df |>
  mutate(
    Lat_Round = round(Latitude, 4),
    Lon_Round = round(Longitude, 4)
  ) |>
  group_by(Lat_Round, Lon_Round, Course_Name) |>
  arrange(desc(Holes)) |>
  slice(1) |>
  ungroup() |>
  mutate(course_id = row_number()) |> # stable sequential ID for cross-script row-level merging
  select(course_id, Course_Name, Ownership_Type, Holes, Address, City, State_Abbr, Zip_Code, Longitude, Latitude)

final_n   <- nrow(courses_df)
removed_n <- original_n - final_n

cat("\n### Deduplication Summary\n")
cat("| Metric | Count |\n")
cat("|---|---|\n")
cat(sprintf("| Original N | %d |\n", original_n))
cat(sprintf("| Duplicates Removed | %d |\n", removed_n))
cat(sprintf("| Final Cleaned N | %d |\n", final_n))

preview_df <- head(courses_df, 5) |>
  select(course_id, Course_Name, Ownership_Type, Holes, City, State_Abbr, Longitude, Latitude)

cat("\n### Parsed Data Sample (First 5 Rows)\n")
cat("| course_id | Course_Name | Ownership_Type | Holes | City | State_Abbr | Longitude | Latitude |\n")
cat("|---|---|---|---|---|---|---|---|\n")
for (i in 1:nrow(preview_df)) {
  row <- preview_df[i, ]
  cat(sprintf(
    "| %d | %s | %s | %s | %s | %s | %f | %f |\n",
    row$course_id,
    row$Course_Name,
    ifelse(is.na(row$Ownership_Type), "NA", row$Ownership_Type),
    ifelse(is.na(row$Holes), "NA", as.character(row$Holes)),
    ifelse(is.na(row$City), "NA", row$City),
    ifelse(is.na(row$State_Abbr), "NA", row$State_Abbr),
    row$Longitude,
    row$Latitude
  ))
}

write_csv(courses_df, OUT_CSV)
cat(sprintf("\nSuccess: Cleaned dataset saved to '%s'\n", OUT_CSV))
