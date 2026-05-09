# Purpose: Read golf-course polygons from the pyosmium GeoPackage fallback,
#          reproject to EPSG:5070 in parallel, compute true acreage, and filter
#          by plausibility bounds.
# Inputs:  Bulk Tests/python/Py_Phase2_OSM_Golf_Polygons.gpkg
# Outputs: Bulk Tests/R/R_Phase2_OSM_Golf_Polygons.gpkg


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(wooldridge)
  library(tidyverse)
  library(sf)
  library(units)
  library(future)
  library(furrr)
  library(parallelly)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR    <- this.path::this.dir()
GPKG_FALLBACK <- file.path(SCRIPT_DIR, "..", "python", "Py_Phase2_OSM_Golf_Polygons.gpkg")
OUT_GPKG      <- file.path(SCRIPT_DIR, "R_Phase2_OSM_Golf_Polygons.gpkg")

MIN_ACRES     <- 5
MAX_ACRES     <- 1500
SQ_M_PER_ACRE <- 4046.8564224

SAFE_WORKERS  <- min(availableCores() - 6, 20)
plan(multisession, workers = SAFE_WORKERS)

sf_use_s2(FALSE)


# === 3. EXECUTION ===

if (!file.exists(GPKG_FALLBACK)) stop(paste("Input file not found:", GPKG_FALLBACK))

cat("1  Loading golf-course polygons from Python GPKG fallback\n")
# GDAL's OGR driver cannot reliably parse this 11 GB PBF (corrupts at byte ~3 GB);
# pyosmium (C++ streaming handler) tolerates the corruption — read its output instead.
osm_golf_sf <- st_read(GPKG_FALLBACK, quiet = TRUE)  # [METHODOLOGY] st_read from pyosmium GPKG
cat(sprintf("    Loaded from GPKG: %s polygons\n", formatC(nrow(osm_golf_sf), big.mark = ",")))

cat("2 & 3  Reprojecting to EPSG:5070 and calculating acreage (parallel)\n")

osm_golf_chunks <- osm_golf_sf |>
  mutate(chunk_id = row_number() %% SAFE_WORKERS) |>
  group_split(chunk_id)

osm_golf_processed <- future_map(osm_golf_chunks, function(chunk) {
  chunk_proj             <- st_transform(chunk, 5070)  # [METHODOLOGY] EPSG:5070 — equal-area CRS required for accurate acreage
  chunk_proj$area_m2     <- as.numeric(st_area(chunk_proj))  # [METHODOLOGY]
  chunk_proj$osm_acreage <- chunk_proj$area_m2 / SQ_M_PER_ACRE
  chunk_proj
}, .progress = TRUE)

osm_golf_sf <- bind_rows(osm_golf_processed) |> select(-chunk_id)

raw_count      <- nrow(osm_golf_sf)
osm_golf_sf    <- osm_golf_sf |> filter(osm_acreage >= MIN_ACRES, osm_acreage <= MAX_ACRES)
filtered_count <- nrow(osm_golf_sf)
dropped        <- raw_count - filtered_count

cat("\n=== OUTPUT STATISTICS ===\n")
cat(sprintf("  Raw polygons before filter:   %s\n",   formatC(raw_count, big.mark = ",")))
cat(sprintf("  Dropped (< %d or > %d acres): %s\n", MIN_ACRES, MAX_ACRES, formatC(dropped, big.mark = ",")))
cat(sprintf("  Final polygon count:          %s\n",   formatC(filtered_count, big.mark = ",")))

ac <- osm_golf_sf$osm_acreage
cat("\n  osm_acreage summary:\n")
cat(sprintf("    Min:    %10s acres\n", formatC(min(ac),    format = "f", digits = 1, big.mark = ",")))
cat(sprintf("    Median: %10s acres\n", formatC(median(ac), format = "f", digits = 1, big.mark = ",")))
cat(sprintf("    Mean:   %10s acres\n", formatC(mean(ac),   format = "f", digits = 1, big.mark = ",")))
cat(sprintf("    Max:    %10s acres\n", formatC(max(ac),    format = "f", digits = 1, big.mark = ",")))

cat("\n  First 5 rows:\n")
print(head(osm_golf_sf |> st_drop_geometry() |>
  select(any_of(c("osm_id", "name", "id")), osm_acreage), 5))

cat(sprintf("\n4  Saving to %s\n", OUT_GPKG))
st_write(osm_golf_sf, OUT_GPKG, delete_dsn = TRUE, quiet = TRUE)  # [METHODOLOGY]
cat(sprintf("  [OK] Saved -> %s\n", OUT_GPKG))
