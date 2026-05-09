# Purpose: Intersect Oahu OSM golf polygons with Honolulu parcel cadastre to
#          extract TMK identifiers and total legal footprint area.
# Inputs:  Bulk Tests/R/Target_Golf_Polygons.gpkg        (Step 1 output)
#          Bulk Tests/R/Honolulu_Parcels_Reprojected.gpkg (Step 1 output)
# Outputs: Bulk Tests/R/Target_Golf_Parcels_List.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(sf)
    library(tidyverse)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR       <- this.path::this.dir()
TARGET_GOLF_PATH <- file.path(SCRIPT_DIR, "Target_Golf_Polygons.gpkg")
PARCELS_PATH     <- file.path(SCRIPT_DIR, "Honolulu_Parcels_Reprojected.gpkg")
OUT_CSV          <- file.path(SCRIPT_DIR, "Target_Golf_Parcels_List.csv")


# === 3. EXECUTION ===

cat("Phase 5b - Step 2: Parcel Intersection\n")
cat(sprintf("Loading datasets from: %s\n", SCRIPT_DIR))

if (!file.exists(TARGET_GOLF_PATH)) stop("[FATAL] Target Golf Polygons not found. Run Step 1.")
if (!file.exists(PARCELS_PATH))     stop("[FATAL] Reprojected Parcels not found. Run Step 1.")

# [METHODOLOGY] st_read — spatial read of Step 1 OSM golf polygons
target_golf_sf <- st_read(TARGET_GOLF_PATH, quiet = TRUE)
# [METHODOLOGY] st_read — spatial read of Step 1 reprojected parcel cadastre
parcels_sf     <- st_read(PARCELS_PATH, quiet = TRUE)

cat(sprintf("  -> Loaded %d target golf polygons.\n", nrow(target_golf_sf)))
cat(sprintf("  -> Loaded %d parcel features.\n", nrow(parcels_sf)))

cat("\nPerforming spatial intersection (this may take a moment)...\n")
# [METHODOLOGY] st_intersection — cookie-cutter of Phase 2 OSM polygons over the
#               Phase 5 legal cadastre to isolate golf-course parcel fragments
parcel_intersection_sf <- st_intersection(target_golf_sf, parcels_sf)

cat(sprintf(
    "  -> Intersection complete: %d parcel fragments found.\n",
    nrow(parcel_intersection_sf)
))

cat("\nExtracting unique TMK identifiers...\n")

tmk_columns <- c(
    "TMK", "PARCEL_ID", "Parcel_ID", "parcel_id", "TAX_MAP_KEY",
    "Tax_Map_Key", "tax_map_key", "MAPKEY", "mapkey", "tmk"
)

found_column <- NULL
for (col in tmk_columns) {
    if (col %in% names(parcel_intersection_sf)) {
        found_column <- col
        break
    }
}

if (is.null(found_column)) {
    cat("\n[WARNING] Standard TMK column not found. Available columns:\n")
    print(names(parcel_intersection_sf))
    stop("[FATAL] No TMK column identified.")
}

unique_tmk        <- unique(as.character(parcel_intersection_sf[[found_column]]))
unique_tmk_sorted <- sort(unique_tmk[!is.na(unique_tmk)])

cat(sprintf(
    "  -> Found %d unique TMKs across the %d golf courses.\n",
    length(unique_tmk_sorted), nrow(target_golf_sf)
))

tmk_df <- data.frame(TMK = unique_tmk_sorted)
write.csv(tmk_df, OUT_CSV, row.names = FALSE)

# [METHODOLOGY] st_area — compute legal footprint area from intersection geometry
total_area_m2   <- sum(st_area(parcel_intersection_sf))
total_acres     <- as.numeric(total_area_m2) / 4046.86
formatted_acres <- formatC(total_acres, format = "f", big.mark = ",", digits = 2)

cat("\n============================================================\n")
cat("PARCEL INTERSECTION COMPLETE\n")
cat("============================================================\n")
cat(sprintf("  Total Targeted Courses : %d\n", nrow(target_golf_sf)))
cat(sprintf("  Total Unique TMKs      : %d\n", length(unique_tmk_sorted)))
cat(sprintf("  Total Legal Footprint  : %s Acres\n", formatted_acres))
cat("------------------------------------------------------------\n")
cat(sprintf(
    "[+] Exported TMK List (CSV) : %s\n",
    normalizePath(OUT_CSV, winslash = "/")
))
cat("\n[DONE] Step 2 Complete.\n")
