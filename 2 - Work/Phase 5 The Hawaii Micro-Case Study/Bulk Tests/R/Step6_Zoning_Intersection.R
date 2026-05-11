# Purpose: Intersect Oahu OSM golf course polygons with the Honolulu County
#          Zoning layer to quantify the percentage of golf course land occupying
#          each zoning designation (e.g., Preservation, Agriculture, Residential).
# Inputs:  Phase 5 The Hawaii Micro-Case Study/Data/R/Target_Golf_Polygons.gpkg
#          00 - Data Sources/Honolulu/Zoning_-2205419429161838665.gpkg
# Outputs: Bulk Tests/R/Phase5_Step6_Zoning_Percentages.csv
#          Bulk Tests/R/Phase5_Step6_Zone_Golf_Penetration.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(sf)
    library(tidyverse)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR  <- this.path::this.dir()
WORK_DIR    <- normalizePath(file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE)
GOLF_GPKG   <- normalizePath(
    file.path(SCRIPT_DIR, "..", "..", "Data", "R", "Target_Golf_Polygons.gpkg"),
    mustWork = FALSE
)
ZONING_GPKG <- file.path(
    WORK_DIR, "00 - Data Sources", "Honolulu",
    "Zoning_-2205419429161838665.gpkg"
)
OUT_CSV             <- file.path(SCRIPT_DIR, "Phase5_Step6_Zoning_Percentages.csv")
OUT_PENETRATION_CSV <- file.path(SCRIPT_DIR, "Phase5_Step6_Zone_Golf_Penetration.csv")

M2_PER_ACRE <- 4046.856422

# === 3. EXECUTION ===

sf_use_s2(FALSE)

cat("\n======================================================================\n")
cat("Phase 5b - Step 6: Zoning Intersection Analysis\n")
cat("======================================================================\n\n")

# -- Guard input files
if (!file.exists(GOLF_GPKG)) {
    stop(sprintf("[FATAL] Golf polygons not found:\n  %s", GOLF_GPKG))
}
if (!file.exists(ZONING_GPKG)) {
    stop(sprintf("[FATAL] Zoning layer not found:\n  %s", ZONING_GPKG))
}

# -- Load
cat("[Step 1] Loading spatial datasets...\n")

golf_sf   <- st_read(GOLF_GPKG,   quiet = TRUE)
zoning_sf <- st_read(ZONING_GPKG, quiet = TRUE)

cat(sprintf("  Golf polygons:  %d features  (CRS: EPSG %d)\n",
    nrow(golf_sf),   st_crs(golf_sf)$epsg))
cat(sprintf("  Zoning layer:   %d features  (CRS: EPSG %d)\n",
    nrow(zoning_sf), st_crs(zoning_sf)$epsg))

# [METHODOLOGY] Both layers must share the same CRS before intersection.
#               Golf polygons are in EPSG 5070 (NAD83 / Conus Albers, metres);
#               the Honolulu zoning layer is in EPSG 3760 (NAD83(HARN) / Hawaii
#               zone 3, ftUS). Zoning is reprojected to match the golf layer so
#               st_area() returns m², which convert to acres via 4,046.856422 m²/ac.
target_crs <- st_crs(golf_sf)

if (!isTRUE(st_crs(zoning_sf) == target_crs)) {
    cat(sprintf(
        "\n[Step 2] Reprojecting zoning from EPSG %d -> EPSG %d...\n",
        st_crs(zoning_sf)$epsg, target_crs$epsg
    ))
    zoning_sf <- st_transform(zoning_sf, target_crs)
    cat("  Reprojection complete.\n")
}

# -- County-wide acreage per zone class (denominator for penetration rate)
county_zone_acres <- zoning_sf |>
    mutate(zone_total_acres = as.numeric(st_area(SHAPE)) / M2_PER_ACRE) |>
    st_drop_geometry() |>
    group_by(zone_class) |>
    summarise(county_total_acres = sum(zone_total_acres, na.rm = TRUE), .groups = "drop")

# [METHODOLOGY] st_intersection() clips the zoning polygons to the exact
#               boundary of each golf course polygon, producing fragment
#               geometries whose combined area quantifies which zoning classes
#               overlap the golf course footprint (Pebesma 2018).
cat("\n[Step 3] Performing spatial intersection (golf courses ∩ zoning)...\n")

intersection_sf <- st_intersection(
    golf_sf["geom"],
    zoning_sf[c("zone_class", "zoning_description", "SHAPE")]
)

cat(sprintf("  Intersection produced %d fragments.\n", nrow(intersection_sf)))

# -- Area calculation (m² -> acres)
cat("\n[Step 4] Calculating fragment areas in acres...\n")

intersection_sf <- intersection_sf |>
    mutate(area_acres = as.numeric(st_area(geom)) / M2_PER_ACRE)

total_golf_acres <- sum(intersection_sf$area_acres, na.rm = TRUE)

cat(sprintf("  Total intersected golf footprint: %.1f acres\n", total_golf_acres))

# -- Summarise by zoning class
zone_summary <- intersection_sf |>
    st_drop_geometry() |>
    group_by(zone_class, zoning_description) |>
    summarise(
        acres     = sum(area_acres, na.rm = TRUE),
        fragments = n(),
        .groups   = "drop"
    ) |>
    mutate(pct_of_total = acres / total_golf_acres * 100) |>
    arrange(desc(acres))

# -- Zone penetration: what % of each Honolulu zone class is occupied by golf
zone_penetration <- zone_summary |>
    select(zone_class, zoning_description, golf_acres = acres) |>
    left_join(county_zone_acres, by = "zone_class") |>
    mutate(pct_zone_as_golf = golf_acres / county_total_acres * 100) |>
    arrange(desc(pct_zone_as_golf))

# -- Console output: golf share of total zoning footprint
cat("\n======================================================================\n")
cat("ZONING BREAKDOWN — OAHU GOLF COURSES\n")
cat("======================================================================\n")
cat(sprintf("%-12s %-40s %12s %10s\n",
    "Zone Class", "Description", "Acres", "% of Total"))
cat(strrep("-", 78), "\n")

for (i in seq_len(nrow(zone_summary))) {
    cat(sprintf("%-12s %-40s %12.1f %9.1f%%\n",
        zone_summary$zone_class[i],
        substr(zone_summary$zoning_description[i], 1, 40),
        zone_summary$acres[i],
        zone_summary$pct_of_total[i]
    ))
}

cat(strrep("-", 78), "\n")
cat(sprintf("%-12s %-40s %12.1f %9.1f%%\n",
    "", "TOTAL", total_golf_acres, 100.0))
cat(strrep("=", 78), "\n")

# -- Console output: zone penetration (zone-centric denominator)
cat("\n======================================================================\n")
cat("ZONE PENETRATION — % OF EACH HONOLULU ZONE CLASS THAT IS GOLF COURSE\n")
cat("======================================================================\n")
cat(sprintf("%-12s %-35s %16s %12s %10s\n",
    "Zone Class", "Description", "Zone Total (ac)", "Golf (ac)", "% Golf"))
cat(strrep("-", 88), "\n")

for (i in seq_len(nrow(zone_penetration))) {
    cat(sprintf("%-12s %-35s %16.1f %12.1f %9.3f%%\n",
        zone_penetration$zone_class[i],
        substr(zone_penetration$zoning_description[i], 1, 35),
        zone_penetration$county_total_acres[i],
        zone_penetration$golf_acres[i],
        zone_penetration$pct_zone_as_golf[i]
    ))
}

cat(strrep("=", 88), "\n")

# -- Save
write_csv(zone_summary, OUT_CSV)
cat(sprintf("\n[+] Zoning percentages saved  -> %s\n", basename(OUT_CSV)))

write_csv(zone_penetration, OUT_PENETRATION_CSV)
cat(sprintf("[+] Zone penetration saved    -> %s\n", basename(OUT_PENETRATION_CSV)))
cat("\n[DONE] Step 6 Complete.\n")
