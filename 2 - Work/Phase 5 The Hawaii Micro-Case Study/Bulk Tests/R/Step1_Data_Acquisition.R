# Purpose: Extract all Oahu OSM golf polygons and calculate the point-to-polygon
#          match rate between Phase 1 baseline points and Phase 2 polygons.
# Inputs:  Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv
#          Phase 2 Spatial Polygons and True Acreage/Data/R/R_Phase2_OSM_Golf_Polygons.gpkg
#          00 - Data Sources/Honolulu/All_Parcels_6378200148342636690.gpkg
# Outputs: Bulk Tests/R/Target_Golf_Polygons.gpkg
#          Bulk Tests/R/Honolulu_Parcels_Reprojected.gpkg


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(sf)
    library(tidyverse)
    library(tigris)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR      <- this.path::this.dir()
WORK_DIR        <- normalizePath(
    file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE
)

PHASE1_IN       <- file.path(
    WORK_DIR, "Phase 1 Parsing", "Data", "R",
    "R_Phase1_Baseline_Golf_Valuation.csv"
)
OSM_IN          <- file.path(
    WORK_DIR, "Phase 2 Spatial Polygons and True Acreage", "Data", "R",
    "R_Phase2_OSM_Golf_Polygons.gpkg"
)
PARCELS_IN      <- file.path(
    WORK_DIR, "00 - Data Sources", "Honolulu",
    "All_Parcels_6378200148342636690.gpkg"
)
TARGET_GOLF_OUT <- file.path(SCRIPT_DIR, "Target_Golf_Polygons.gpkg")
PARCELS_OUT     <- file.path(SCRIPT_DIR, "Honolulu_Parcels_Reprojected.gpkg")


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

for (path in c(PHASE1_IN, OSM_IN, PARCELS_IN)) {
    if (!file.exists(path)) stop(sprintf("[FATAL] Input file not found:\n  %s", path))
}

cat("Loading datasets...\n")
baseline_df  <- read.csv(PHASE1_IN, stringsAsFactors = FALSE)
# [METHODOLOGY] st_read — spatial read of Phase 2 OSM golf polygons
osm_golf_sf  <- st_read(OSM_IN, quiet = TRUE)
# [METHODOLOGY] st_read — spatial read of Honolulu cadastral parcel layer
parcels_sf   <- st_read(PARCELS_IN, quiet = TRUE)

cat("Downloading Oahu boundary...\n")
suppressMessages(
    oahu_boundary_sf <- counties(
        state = "HI",
        cb = TRUE,
        class = "sf",
        progress_bar = FALSE
    ) |>
        filter(NAME == "Honolulu") |>
        # [METHODOLOGY] st_transform — reproject county boundary to match OSM CRS
        st_transform(st_crs(osm_golf_sf))
)

cat("Extracting all OSM polygons within Oahu...\n")
# [METHODOLOGY] st_filter — spatial subset of all OSM golf polygons to Honolulu county
oahu_golf_sf <- st_filter(osm_golf_sf, oahu_boundary_sf, .predicate = st_intersects)
if (nrow(oahu_golf_sf) == 0) stop("[FATAL] No OSM polygons found on Oahu.")

oahu_baseline_sf <- baseline_df |>
    filter(County_Name == "Honolulu" | FIPS == 15003) |>
    # [METHODOLOGY] st_as_sf — convert Phase 1 tabular baseline to spatial points
    st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |>
    # [METHODOLOGY] st_transform — reproject Phase 1 points to match OSM CRS
    st_transform(st_crs(oahu_golf_sf))

# [METHODOLOGY] st_intersects — check which Phase 1 points fall within an OSM polygon;
#               mismatch rate quantifies Phase 1-to-Phase 2 representational error
intersections <- st_intersects(oahu_baseline_sf, oahu_golf_sf)
hits   <- sum(lengths(intersections) > 0)
misses <- sum(lengths(intersections) == 0)

cat("\n============================================================\n")
cat("METHODOLOGICAL ERROR ANALYSIS (OAHU MICRO-CASE STUDY)\n")
cat("============================================================\n")
cat(sprintf(
    "  Phase 1 Baseline Total (Points) : %d courses\n",
    nrow(oahu_baseline_sf)
))
cat(sprintf(
    "  Phase 2 OSM Total (Polygons)    : %d courses\n",
    nrow(oahu_golf_sf)
))
cat("  --------------------------------------------------\n")
cat(sprintf("  Points hitting a polygon        : %d\n", hits))
cat(sprintf("  Points missing a polygon        : %d\n", misses))
cat(sprintf(
    "  Direct Point Match Rate         : %.1f%%\n",
    (hits / nrow(oahu_baseline_sf)) * 100
))
cat("============================================================\n\n")

if (st_crs(oahu_golf_sf) != st_crs(parcels_sf)) {
    cat("Reprojecting parcels to match OSM CRS...\n")
    # [METHODOLOGY] st_transform — align parcel CRS to OSM CRS for Step 2 overlay
    parcels_sf <- st_transform(parcels_sf, st_crs(oahu_golf_sf))
}

cat(sprintf("Exporting geometries to: %s\n", SCRIPT_DIR))
# [METHODOLOGY] st_write — persist Oahu OSM golf polygons for Step 2 parcel intersection
st_write(oahu_golf_sf, TARGET_GOLF_OUT, append = FALSE, quiet = TRUE)
# [METHODOLOGY] st_write — persist reprojected parcel cadastre for Step 2
st_write(parcels_sf, PARCELS_OUT, append = FALSE, quiet = TRUE)

cat("\n[DONE] Step 1 Complete. Ready for Step 2.\n")
