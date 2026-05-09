# Purpose: Generate a high-resolution micro-map of Oahu highlighting the 1,072
#          golf course TMKs, with special emphasis on the Ewa District (Zone 9)
#          concentration. Oahu outline is derived by dissolving all parcels.
# Inputs:  Phase 5 The Hawaii Micro-Case Study/Data/R/Honolulu_Parcels_Reprojected.gpkg
#          Phase 5 The Hawaii Micro-Case Study/Data/R/Target_Golf_Parcels_List.csv
#          Phase 5 The Hawaii Micro-Case Study/Data/R/Phase5_Geographic_Breakdown.csv
# Outputs: Bulk/R/output/Oahu_TMK_Concentration_Map.png


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(tidyverse)
    library(sf)
    library(ggspatial)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR   <- this.path::this.dir()
WORK_DIR     <- normalizePath(
    file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE
)
PHASE5_DATA  <- file.path(
    WORK_DIR, "Phase 5 The Hawaii Micro-Case Study", "Data", "R"
)
PARCELS_GPKG <- file.path(PHASE5_DATA, "Honolulu_Parcels_Reprojected.gpkg")
TMK_CSV      <- file.path(PHASE5_DATA, "Target_Golf_Parcels_List.csv")
GEO_CSV      <- file.path(PHASE5_DATA, "Phase5_Geographic_Breakdown.csv")
OUTPUT_DIR   <- file.path(SCRIPT_DIR, "output")
OUT_PNG      <- file.path(OUTPUT_DIR, "3_Oahu_TMK_Concentration_Map.png")

OAHU_CRS    <- 32604L     # WGS 84 / UTM Zone 4N — correct local projection for Oahu
ZONE_EWA    <- "9"
COL_EWA     <- "#E05C14"  # bright orange-red — Ewa District (Zone 9)
COL_OTHER   <- "#3a3a3a"  # dark gray — all other districts
COL_ISLAND  <- "#e8e8e8"  # light gray — island base fill
COL_COAST   <- "#aaaaaa"  # medium gray — coastline border


# === 3. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Micro Map: Oahu Golf Course TMK Concentration\n")
cat(strrep("=", 70), "\n\n")

# -- Guard inputs
for (f in c(PARCELS_GPKG, TMK_CSV, GEO_CSV)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}

# -- Load TMK list and geographic breakdown
cat("[Step 1] Loading TMK list and geographic breakdown...\n")
tmk_list <- read_csv(TMK_CSV, show_col_types = FALSE)
geo_df   <- read_csv(GEO_CSV, show_col_types = FALSE)

ewa_row <- geo_df |> filter(Zone_Code == as.integer(ZONE_EWA))
cat(sprintf("  %d target TMKs loaded.\n", nrow(tmk_list)))
cat(sprintf(
    "  Zone 9 (Ewa): %d parcels (%.1f%% of total per breakdown CSV).\n",
    ewa_row$Parcel_Count,
    ewa_row$Pct_of_Total_Parcels
))

# -- Load GeoPackage and reproject
# [METHODOLOGY] GeoPackage is stored in EPSG 5070 (NAD83/Conus Albers). Reprojecting
#               to EPSG 32604 (WGS 84/UTM Zone 4N) gives a north-up equal-distance
#               view centred on Oahu and produces correct metric scale bar units.
cat("\n[Step 2] Loading Honolulu parcels GeoPackage and reprojecting...\n")
all_parcels_sf <- st_read(PARCELS_GPKG, quiet = TRUE) |>
    st_transform(OAHU_CRS)
cat(sprintf(
    "  %d total parcels loaded (EPSG %d).\n",
    nrow(all_parcels_sf), OAHU_CRS
))

# -- Filter to golf TMKs and flag Ewa (Zone 9)
cat("\n[Step 3] Filtering to golf TMKs and flagging Ewa District (Zone 9)...\n")
golf_sf <- all_parcels_sf |>
    filter(tmk8num %in% tmk_list$TMK) |>
    mutate(district = if_else(
        zone == ZONE_EWA,
        "Ewa District (Zone 9)",
        "Other Districts"
    )) |>
    mutate(district = factor(
        district,
        levels = c("Ewa District (Zone 9)", "Other Districts")
    ))

n_ewa   <- sum(golf_sf$zone == ZONE_EWA, na.rm = TRUE)
n_other <- nrow(golf_sf) - n_ewa
cat(sprintf(
    "  %d golf TMKs: %d Ewa (Zone 9), %d across other districts.\n",
    nrow(golf_sf), n_ewa, n_other
))

if (nrow(golf_sf) != nrow(tmk_list)) {
    cat(sprintf(
        "  [WARNING] TMK match: %d matched out of %d in list.\n",
        nrow(golf_sf), nrow(tmk_list)
    ))
}

# -- Dissolve all parcels to produce Oahu island outline
# [METHODOLOGY] st_union() merges all 177k parcel polygons into a single outline,
#               eliminating internal cadastral boundaries. Used in place of a
#               separate boundary shapefile to keep inputs self-contained.
cat("\n[Step 4] Building Oahu island outline via st_union (may take ~20 sec)...\n")
oahu_outline_sf <- st_sf(geometry = st_union(all_parcels_sf))
cat("  Island outline complete.\n")

# -- Zone district summary for console output
cat("\n  Golf parcel breakdown by zone:\n")
cat(sprintf("  %-6s  %-35s  %s\n", "Zone", "District", "Parcels"))
cat(sprintf("  %s\n", strrep("-", 55)))
zone_summary <- golf_sf |>
    st_drop_geometry() |>
    count(zone, district, name = "n") |>
    arrange(desc(n))
for (i in seq_len(nrow(zone_summary))) {
    cat(sprintf(
        "  %-6s  %-35s  %d\n",
        zone_summary$zone[i],
        as.character(zone_summary$district[i]),
        zone_summary$n[i]
    ))
}

# -- Render map
# [METHODOLOGY] Parcels are sorted so Other Districts (dark gray) render first
#               and Ewa (orange-red) renders on top, ensuring maximum visibility
#               of the highlighted zone. A single geom_sf call preserves a unified
#               legend. ggspatial::annotation_scale() computes the bar from UTM
#               metres. Legend is floated over ocean in the lower-right corner.
cat("\n[Step 5] Rendering Oahu micro-map...\n")

oahu_map <- ggplot() +
    geom_sf(
        data      = oahu_outline_sf,
        fill      = COL_ISLAND,
        colour    = COL_COAST,
        linewidth = 0.35
    ) +
    geom_sf(
        data   = arrange(golf_sf, district == "Ewa District (Zone 9)"),
        aes(fill = district),
        colour = NA
    ) +
    scale_fill_manual(
        name   = "Golf Course Parcels",
        values = c(
            "Ewa District (Zone 9)" = COL_EWA,
            "Other Districts"       = COL_OTHER
        ),
        guide = guide_legend(
            override.aes = list(colour = NA),
            keywidth     = unit(0.65, "cm"),
            keyheight    = unit(0.65, "cm")
        )
    ) +
    annotation_scale(
        location   = "br",
        width_hint = 0.22,
        style      = "ticks",
        text_cex   = 0.75,
        pad_x      = unit(0.5, "cm"),
        pad_y      = unit(0.5, "cm")
    ) +
    labs(
        title    = "Golf Course Parcel Concentration — Oahu, Hawaiʻi",
        subtitle = sprintf(
            "%d golf TMKs  |  Ewa District (Zone 9): %d parcels (%.1f%%)  |  %d zones represented",
            nrow(golf_sf),
            n_ewa,
            ewa_row$Pct_of_Total_Parcels,
            n_distinct(golf_sf$zone)
        ),
        caption  = paste0(
            "Source: City & County of Honolulu parcel data; OSM golf course polygons. ",
            "CRS: WGS 84 / UTM Zone 4N (EPSG 32604).\n",
            "TMK = Tax Map Key. Zone 9 corresponds to the Ewa District ",
            "(Kapolei / Pearl City / Ewa Beach)."
        )
    ) +
    theme_void(base_size = 12) +
    theme(
        plot.title       = element_text(
            face = "bold", size = 16, hjust = 0.5, margin = margin(b = 4)
        ),
        plot.subtitle    = element_text(
            size = 9, hjust = 0.5, colour = "grey35", margin = margin(b = 8)
        ),
        plot.caption     = element_text(
            size = 7, colour = "grey50", hjust = 0, margin = margin(t = 10)
        ),
        legend.position  = c(0.87, 0.22),
        legend.background = element_rect(
            fill = alpha("white", 0.88), colour = "grey75", linewidth = 0.3
        ),
        legend.margin    = margin(5, 9, 5, 9),
        legend.title     = element_text(size = 8, face = "bold"),
        legend.text      = element_text(size = 8),
        plot.background  = element_rect(fill = "white", colour = NA),
        plot.margin      = margin(12, 16, 8, 16)
    )

# -- Save
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
ggsave(
    filename = OUT_PNG,
    plot     = oahu_map,
    width    = 12,
    height   = 10,
    dpi      = 300,
    units    = "in"
)
cat(sprintf(
    "\n[+] Map saved (300 DPI, 12 × 10 in) -> output/%s\n",
    basename(OUT_PNG)
))
cat("\n[DONE] Phase 6 - Oahu Micro Map Complete.\n")
