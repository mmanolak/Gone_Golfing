# Purpose: Parse raw USA golf course CSV, extract course type and hole count,
#          and spatially join to US county boundaries via point-in-polygon.
# Inputs:  00 - Data Sources/Original Data/Golf Courses-USA.csv
# Outputs: Bulk Tests/R/R_Phase1_Spatial_Joined_Golf_Courses.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(tidyverse)
  library(wooldridge)
  library(sf)
  library(tigris)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

options(tigris_use_cache = TRUE)

SCRIPT_DIR <- this.path::this.dir()
ROOT_DIR   <- file.path(SCRIPT_DIR, "..", "..", "..")

RAW_CSV <- file.path(ROOT_DIR, "00 - Data Sources", "Original Data", "Golf Courses-USA.csv")
OUT_CSV <- file.path(SCRIPT_DIR, "R_Phase1_Spatial_Joined_Golf_Courses.csv")


# === 3. FUNCTIONS ===

#' Extract standardized course type from raw details string.
#' @param details character vector of raw course detail strings
#' @return character vector of course type labels
extract_course_type <- function(details) {
  s <- tolower(details)
  case_when(
    str_detect(s, "public")    ~ "Public",
    str_detect(s, "private")   ~ "Private",
    str_detect(s, "municipal") ~ "Municipal",
    str_detect(s, "military")  ~ "Military",
    str_detect(s, "resort")    ~ "Resort",
    TRUE                       ~ "Unknown"
  )
}

#' Extract hole count from raw details string; defaults to 18 when absent.
#' @param details character vector of raw course detail strings
#' @return integer vector of hole counts
extract_holes <- function(details) {
  m     <- str_match(details, "\\((\\d+)\\s*Holes?\\)")
  holes <- as.integer(m[, 2])
  ifelse(is.na(holes), 18L, holes)
}


# === 4. EXECUTION ===

if (!file.exists(RAW_CSV)) stop(paste("Input file not found:", RAW_CSV))

cat("1: Loading raw Golf Courses CSV\n")
courses_df <- read_csv(RAW_CSV,
  col_names = c(
    "Longitude", "Latitude",
    "Course_Name", "Details"
  ),
  show_col_types = FALSE
)
cat(sprintf("    Rows loaded: %s\n", formatC(nrow(courses_df), big.mark = ",")))

cat("2: Extracting Course_Type & Holes via regex\n")
courses_df <- courses_df |>
  mutate(
    Course_Type = extract_course_type(Details),
    Holes       = extract_holes(Details)
  )
cat("    Course_Type distribution:\n")
print(table(courses_df$Course_Type))

cat("3: Converting to sf object (EPSG:4326)\n")
courses_df <- courses_df |> filter(!is.na(Longitude), !is.na(Latitude))
courses_sf <- st_as_sf(courses_df,
  coords = c("Longitude", "Latitude"), crs = 4326,
  remove = FALSE
)

cat("4: Downloading 2022 US County boundaries (tigris)\n")
# tigris cb=TRUE provides NAME (county) and STUSPS (state abbreviation) — renamed for cross-language consistency with Python output
county_sf <- counties(cb = TRUE, year = 2022, resolution = "20m") |>
  st_transform(4326) |> # [METHODOLOGY]
  select(GEOID, NAME, STATE_NAME = STUSPS)

cat("5: Spatial point-in-polygon join\n")
courses_sf <- st_join(courses_sf, county_sf, join = st_intersects) # [METHODOLOGY]

courses_sf <- courses_sf |>
  rename(FIPS = GEOID, County_Name = NAME, State_Abbr = STATE_NAME)

# CSV format cannot carry geometry — join attributes are retained as columns
courses_df <- st_drop_geometry(courses_sf)

total   <- nrow(courses_df)
missing <- sum(is.na(courses_df$FIPS))

cat("\nOUTPUT STATISTICS\n")
cat(sprintf("  Total rows:                %s\n", formatC(total, big.mark = ",")))
cat(sprintf("  Missing FIPS (no county):  %d\n", missing))
cat("\n  First 5 rows:\n")
print(head(courses_df |> select(
  Course_Name, FIPS, County_Name,
  State_Abbr, Course_Type, Holes
), 5))

write_csv(courses_df, OUT_CSV)
cat(sprintf("\n  [OK] Saved -> %s\n", OUT_CSV))
