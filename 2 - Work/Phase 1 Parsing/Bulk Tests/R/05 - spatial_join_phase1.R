# Purpose: Spatial-join parsed golf course points to 2022 US county boundaries
#          using tigris, resolving state abbreviations via fips_codes lookup.
# Inputs:  Bulk Tests/R/R_Phase1_Parsed_Golf_Courses.csv
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

GOLF_IN <- file.path(SCRIPT_DIR, "R_Phase1_Parsed_Golf_Courses.csv")
OUT_CSV <- file.path(SCRIPT_DIR, "R_Phase1_Spatial_Joined_Golf_Courses.csv")


# === 3. EXECUTION ===

if (!file.exists(GOLF_IN)) stop(paste("Input file not found:", GOLF_IN))
courses_df <- read_csv(GOLF_IN, show_col_types = FALSE)

courses_sf <- st_as_sf(courses_df, coords = c("Longitude", "Latitude"), crs = 4326, remove = FALSE)

county_sf <- tigris::counties(year = 2022, cb = TRUE, resolution = "20m") |>
  st_transform(4326) # [METHODOLOGY] align CRS to WGS 84 before join — golf course coordinates are in EPSG:4326

courses_sf <- st_join(courses_sf, county_sf, join = st_intersects) # [METHODOLOGY]

# tigris counties() provides STATEFP but not abbreviation — resolve via fips_codes lookup
data("fips_codes", package = "tigris")
state_map <- unique(fips_codes[, c("state_code", "state")])

courses_sf <- left_join(courses_sf, state_map, by = c("STATEFP" = "state_code"))

courses_df <- courses_sf |>
  st_drop_geometry() |>
  mutate(
    FIPS              = GEOID,
    County_Name       = NAME,
    Tigris_State_Abbr = state # Renamed to avoid collision with original State_Abbr
  ) |>
  select(all_of(names(courses_df)), FIPS, County_Name, Tigris_State_Abbr)

write_csv(courses_df, OUT_CSV)
cat(sprintf("  [OK] Saved -> %s\n", OUT_CSV))
