# Purpose: Match OSM golf-course polygons to Phase 1 baseline points via
#          two-pass spatial join (intersects then 500 m nearest-neighbour).
# Inputs:  Phase 1 Parsing/Bulk Tests/R/R_Phase1_Baseline_Golf_Valuation.csv
#          Bulk Tests/R/R_Phase2_OSM_Golf_Polygons.gpkg
# Outputs: Bulk Tests/R/R_Acreage_Step1_OSM.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(wooldridge)
  library(tidyverse)
  library(sf)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
ROOT_DIR   <- file.path(SCRIPT_DIR, "..", "..", "..")

PHASE1_CSV <- file.path(ROOT_DIR, "Phase 1 Parsing", "Bulk Tests", "R",
                        "R_Phase1_Baseline_Golf_Valuation.csv")
OSM_IN     <- file.path(SCRIPT_DIR, "R_Phase2_OSM_Golf_Polygons.gpkg")
OUT_CSV    <- file.path(SCRIPT_DIR, "R_Acreage_Step1_OSM.csv")

TARGET_CRS    <- 5070
MAX_NEAREST_M <- 500
SQ_M_PER_ACRE <- 4046.8564224
SQ_FT_PER_ACRE <- 43560


# === 3. FUNCTIONS ===

print_separator <- function(char = "=") {
  cat(paste(rep(char, 80), collapse = ""), "\n")
}


# === 4. EXECUTION ===

for (path in c(PHASE1_CSV, OSM_IN)) {
  if (!file.exists(path)) stop(paste("Input file not found:", path))
}

print_separator()
cat("Phase 2: OSM Polygon Matching for Golf Course Acreage\n")
cat("Script: 01_Match_OSM.R\n")
print_separator()


cat("\n[Step 1] Loading Phase 1 baseline dataset\n")

baseline_df <- read_csv(PHASE1_CSV, show_col_types = FALSE)
cat(sprintf("  Loaded %s courses\n", formatC(nrow(baseline_df), big.mark = ",")))

required_cols <- c("Course_Name", "County_Name", "State_Abbr", "Latitude", "Longitude")
missing_cols  <- setdiff(required_cols, names(baseline_df))
if (length(missing_cols) > 0) {
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "),
       "\n  Available: ", paste(names(baseline_df), collapse = ", "))
}

# row_idx for deduplication — Phase 1 has no course_id column
baseline_df <- baseline_df |> mutate(row_idx = row_number())


cat("\n[Step 2] Loading OSM golf course polygons\n")

osm_golf_sf <- st_read(OSM_IN, quiet = TRUE) |>  # [METHODOLOGY] st_read from OSM GeoPackage
  st_make_valid()

cat(sprintf("  Loaded %s OSM polygon features\n", formatC(nrow(osm_golf_sf), big.mark = ",")))
cat(sprintf("  CRS: %s\n", st_crs(osm_golf_sf)$input))


cat("\n[Step 3] Converting baseline to sf POINT object\n")

courses_sf <- st_as_sf(  # [METHODOLOGY]
  baseline_df,
  coords = c("Longitude", "Latitude"),
  crs    = 4326,
  remove = FALSE
)
cat(sprintf("  Converted %s courses to POINT objects (EPSG:4326)\n",
            formatC(nrow(courses_sf), big.mark = ",")))

cat(sprintf("\n[Step 4] Reprojecting to EPSG:%d\n", TARGET_CRS))

courses_sf  <- st_transform(courses_sf,  TARGET_CRS)  # [METHODOLOGY] EPSG:5070 — equal-area CRS for distance/area accuracy
osm_golf_sf <- st_transform(osm_golf_sf, TARGET_CRS)  # [METHODOLOGY]

osm_golf_sf$area_sqft <- as.numeric(st_area(osm_golf_sf)) * (SQ_FT_PER_ACRE / SQ_M_PER_ACRE)  # [METHODOLOGY]


cat("\n[Step 5] Two-pass spatial join\n")
cat("  Pass 1: st_intersects (point-in-polygon)\n")

intersects_result <- st_join(  # [METHODOLOGY] point-in-polygon primary match
  courses_sf,
  osm_golf_sf |> select(area_sqft),
  join = st_intersects,
  left = TRUE
)

# One course may intersect multiple OSM polygons — keep the largest
intersects_df <- as.data.frame(intersects_result) |>
  arrange(row_idx, desc(area_sqft)) |>
  filter(!duplicated(row_idx))

baseline_df <- baseline_df |>
  left_join(
    intersects_df |> select(row_idx, OSM_Area_SqFt = area_sqft),
    by = "row_idx"
  )

pass1_matches <- sum(!is.na(baseline_df$OSM_Area_SqFt))
cat(sprintf("    Pass 1 matches (exact intersection): %s\n",
            formatC(pass1_matches, big.mark = ",")))


cat(sprintf("  Pass 2: nearest-neighbour fallback (<= %d m)\n", MAX_NEAREST_M))

miss_mask <- is.na(baseline_df$OSM_Area_SqFt)
cat(sprintf("    Courses still missing after Pass 1: %s\n",
            formatC(sum(miss_mask), big.mark = ",")))

if (any(miss_mask)) {
  miss_sf      <- courses_sf[miss_mask, ]
  nearest_idx  <- st_nearest_feature(miss_sf, osm_golf_sf)
  nearest_dist <- as.numeric(
    st_distance(miss_sf, osm_golf_sf[nearest_idx, ], by_element = TRUE)
  )
  within_range <- nearest_dist <= MAX_NEAREST_M

  if (any(within_range)) {
    baseline_df$OSM_Area_SqFt[miss_mask][within_range] <-
      osm_golf_sf$area_sqft[nearest_idx[within_range]]
  }

  cat(sprintf("    Pass 2 recoveries (NN <= %d m): %s\n",
              MAX_NEAREST_M, formatC(sum(within_range), big.mark = ",")))
}

total_matches <- sum(!is.na(baseline_df$OSM_Area_SqFt))
cat(sprintf("  Total OSM matches (Pass 1 + Pass 2): %s\n",
            formatC(total_matches, big.mark = ",")))


cat("\n[Step 6] Creating acreage_source column\n")

baseline_df$acreage_source <- ifelse(!is.na(baseline_df$OSM_Area_SqFt), "OSM", NA_character_)

cat(sprintf("  OSM-sourced:   %s\n", formatC(total_matches, big.mark = ",")))
cat(sprintf("  Still missing: %s  (Tigris fallback in Step 2)\n",
            formatC(sum(is.na(baseline_df$OSM_Area_SqFt)), big.mark = ",")))


cat(sprintf("\n[Step 7] Saving intermediate file: %s\n", OUT_CSV))

write_csv(baseline_df |> select(-row_idx), OUT_CSV)
cat(sprintf("  Saved: %s\n", OUT_CSV))
cat(sprintf("  Rows: %s  |  Columns: %d\n",
            formatC(nrow(baseline_df), big.mark = ","), ncol(baseline_df) - 1L))


print_separator()
cat("SUMMARY - OSM Polygon Matching Results\n")
print_separator()

total_courses <- nrow(baseline_df)
non_matched   <- total_courses - total_matches

cat(sprintf("\n  Total courses in baseline:    %s\n",   formatC(total_courses, big.mark = ",")))
cat(sprintf("  Matched with OSM acreage:     %s (%.1f%%)\n",
            formatC(total_matches, big.mark = ","), 100 * total_matches / total_courses))
cat(sprintf("  Still need Tigris/MICE:       %s (%.1f%%)\n",
            formatC(non_matched, big.mark = ","), 100 * non_matched / total_courses))

if (total_matches > 0) {
  osm_acres <- baseline_df$OSM_Area_SqFt[!is.na(baseline_df$OSM_Area_SqFt)] / SQ_FT_PER_ACRE
  cat("\n  OSM Acreage (matched only):\n")
  cat(sprintf("    Min:    %.2f acres\n", min(osm_acres)))
  cat(sprintf("    Median: %.2f acres\n", median(osm_acres)))
  cat(sprintf("    Mean:   %.2f acres\n", mean(osm_acres)))
  cat(sprintf("    Max:    %.2f acres\n", max(osm_acres)))
}

cat(sprintf("\n  Output: %s\n", OUT_CSV))
print_separator()
cat("\n[Complete] 01_Match_OSM.R finished successfully.\n")
