# Purpose: Generate a high-resolution micro-map of Oahu coloring the 1,072 golf
#          course TMK parcels by their dominant zoning classification. Each parcel
#          is assigned the zone_class of the Honolulu zoning polygon with the
#          largest overlap area (st_join largest = TRUE).
# Inputs:  Phase 5 The Hawaii Micro-Case Study/Data/R/Honolulu_Parcels_Reprojected.gpkg
#          Phase 5 The Hawaii Micro-Case Study/Data/R/Target_Golf_Parcels_List.csv
#          00 - Data Sources/Honolulu/Zoning_-2205419429161838665.gpkg
# Outputs: Bulk/R/output/Oahu_Golf_Zoning_Map.png


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
ZONING_GPKG  <- file.path(
    WORK_DIR, "00 - Data Sources", "Honolulu",
    "Zoning_-2205419429161838665.gpkg"
)
OUTPUT_DIR   <- file.path(SCRIPT_DIR, "output")
OUT_PNG      <- file.path(OUTPUT_DIR, "4_Oahu_Golf_Zoning_Map.png")

OAHU_CRS    <- 32604L   # WGS 84 / UTM Zone 4N
COL_ISLAND  <- "#e8e8e8"
COL_COAST   <- "#aaaaaa"

# [METHODOLOGY] Colors are assigned semantically by zone type so that related
#               land-use categories share a hue family, aiding interpretation.
#               Preservation = greens, Federal = navy, Agriculture = browns,
#               Resort = amber, Country = teal, Residential = purples
#               (darkest = most dense), Apartments = oranges, Commercial = reds,
#               Industrial = blue-grays.
ZONE_COLORS <- c(
    "P-2"    = "#2e7d32",
    "P-1"    = "#81c784",
    "F-1"    = "#1565c0",
    "AG-2"   = "#6d4c41",
    "AG-1"   = "#a1887f",
    "Resort" = "#f9a825",
    "C"      = "#00897b",
    "R-3.5"  = "#4a148c",
    "R-5"    = "#7b1fa2",
    "R-7.5"  = "#ab47bc",
    "R-10"   = "#ce93d8",
    "R-20"   = "#e1bee7",
    "A-1"    = "#e65100",
    "A-2"    = "#ff8f00",
    "B-1"    = "#b71c1c",
    "B-2"    = "#e53935",
    "BMX-3"  = "#ff7043",
    "I-2"    = "#37474f",
    "IMX-1"  = "#90a4ae"
)


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Micro Map: Oahu Golf Parcels by Zoning Classification\n")
cat(strrep("=", 70), "\n\n")

# -- Guard inputs
for (f in c(PARCELS_GPKG, TMK_CSV, ZONING_GPKG)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}

# -- Load TMK list
cat("[Step 1] Loading TMK list...\n")
tmk_list <- read_csv(TMK_CSV, show_col_types = FALSE)
cat(sprintf("  %d target TMKs loaded.\n", nrow(tmk_list)))

# -- Load and filter golf parcels
cat("\n[Step 2] Loading Honolulu parcels and filtering to golf TMKs...\n")
golf_sf <- st_read(PARCELS_GPKG, quiet = TRUE) |>
    filter(tmk8num %in% tmk_list$TMK) |>
    st_transform(OAHU_CRS)
cat(sprintf("  %d golf TMK parcels loaded (EPSG %d).\n", nrow(golf_sf), OAHU_CRS))

# -- Load Honolulu zoning layer
# [METHODOLOGY] The Honolulu zoning GeoPackage uses ArcGIS convention: geometry
#               column is named SHAPE and CRS is EPSG 3760 (NAD83 HARN / Hawaii).
#               Only zone_class and zoning_description are retained for the join.
cat("\n[Step 3] Loading Honolulu zoning layer...\n")
zoning_sf <- st_read(ZONING_GPKG, quiet = TRUE) |>
    select(zone_class, zoning_description) |>
    st_transform(OAHU_CRS)
cat(sprintf(
    "  %d zoning polygons loaded (%d unique classes).\n",
    nrow(zoning_sf),
    n_distinct(zoning_sf$zone_class)
))

# -- Assign dominant zone to each golf parcel via largest-overlap spatial join
# [METHODOLOGY] st_join(largest = TRUE) selects the zoning polygon whose intersection
#               area with each golf parcel is greatest. This avoids assigning edge-
#               clipping zones to parcels that are overwhelmingly within one class.
cat("\n[Step 4] Assigning dominant zoning to each golf parcel (st_join, largest = TRUE)...\n")
golf_zoned_sf <- st_join(golf_sf, zoning_sf, largest = TRUE)

n_unzoned <- sum(is.na(golf_zoned_sf$zone_class))
if (n_unzoned > 0) {
    cat(sprintf(
        "  [WARNING] %d parcels with no zoning match (rendered gray).\n",
        n_unzoned
    ))
}
golf_zoned_sf <- golf_zoned_sf |>
    mutate(zone_class = replace_na(zone_class, "Unzoned"))

cat(sprintf(
    "  %d parcels zoned; %d unique zone classes present.\n",
    nrow(golf_zoned_sf) - n_unzoned,
    n_distinct(golf_zoned_sf$zone_class)
))

# -- Console breakdown
cat("\n  Parcel breakdown by dominant zone class:\n")
cat(sprintf("  %-10s  %-40s  %s\n", "Zone", "Description", "Parcels"))
cat(sprintf("  %s\n", strrep("-", 60)))
zone_counts <- golf_zoned_sf |>
    st_drop_geometry() |>
    count(zone_class, zoning_description, name = "n") |>
    arrange(desc(n))
for (i in seq_len(nrow(zone_counts))) {
    cat(sprintf(
        "  %-10s  %-40s  %d\n",
        zone_counts$zone_class[i],
        coalesce(zone_counts$zoning_description[i], "—"),
        zone_counts$n[i]
    ))
}

# -- Build Oahu island outline
cat("\n[Step 5] Building Oahu island outline (dissolving all parcels)...\n")
cat("  [This may take ~20 seconds...]\n")
all_parcels_sf   <- st_read(PARCELS_GPKG, quiet = TRUE) |> st_transform(OAHU_CRS)
oahu_outline_sf  <- st_sf(geometry = st_union(all_parcels_sf))
cat("  Island outline complete.\n")

# -- Build color vector for observed zone classes only
observed_zones <- sort(unique(golf_zoned_sf$zone_class))
zone_colors_used <- ZONE_COLORS[names(ZONE_COLORS) %in% observed_zones]
if ("Unzoned" %in% observed_zones) {
    zone_colors_used <- c(zone_colors_used, Unzoned = "#d4d4d4")
}

# -- Build legend labels that append acreage context
zone_label_df <- golf_zoned_sf |>
    st_drop_geometry() |>
    count(zone_class, zoning_description, name = "n") |>
    mutate(label = sprintf(
        "%s — %s (%d parcels)",
        zone_class,
        coalesce(str_remove(zoning_description, "^[A-Z0-9-]+ "), zone_class),
        n
    ))
zone_labels <- setNames(zone_label_df$label, zone_label_df$zone_class)

# -- Render map
cat("\n[Step 6] Rendering Oahu zoning map...\n")

oahu_zoning_map <- ggplot() +
    geom_sf(
        data      = oahu_outline_sf,
        fill      = COL_ISLAND,
        colour    = COL_COAST,
        linewidth = 0.3
    ) +
    geom_sf(
        data   = golf_zoned_sf,
        aes(fill = zone_class),
        colour = NA
    ) +
    scale_fill_manual(
        name   = "Dominant Zoning Classification",
        values = zone_colors_used,
        labels = zone_labels,
        guide  = guide_legend(
            ncol         = 1,
            override.aes = list(colour = NA),
            keywidth     = unit(0.55, "cm"),
            keyheight    = unit(0.55, "cm")
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
        title    = "Golf Course Parcels by Dominant Zoning Class — Oahu, Hawaiʻi",
        subtitle = sprintf(
            "%d golf TMKs  |  %d unique zone classes  |  Each parcel colored by largest-overlap zoning assignment",
            nrow(golf_zoned_sf),
            n_distinct(golf_zoned_sf$zone_class)
        ),
        caption  = paste0(
            "Source: City & County of Honolulu parcel & zoning data; OSM golf course polygons. ",
            "CRS: WGS 84 / UTM Zone 4N (EPSG 32604).\n",
            "Dominant zone assigned via largest intersection area (st_join, largest = TRUE). ",
            "Color families: green = Preservation, navy = Federal,\n",
            "brown = Agriculture, amber = Resort, teal = Country, ",
            "purple = Residential, orange = Apartment, red = Commercial, gray = Industrial."
        )
    ) +
    theme_void(base_size = 11) +
    theme(
        plot.title      = element_text(
            face = "bold", size = 15, hjust = 0.5, margin = margin(b = 4)
        ),
        plot.subtitle   = element_text(
            size = 8.5, hjust = 0.5, colour = "grey35", margin = margin(b = 6)
        ),
        plot.caption    = element_text(
            size = 6.5, colour = "grey50", hjust = 0, margin = margin(t = 8)
        ),
        legend.position  = "right",
        legend.title     = element_text(size = 8, face = "bold", margin = margin(b = 4)),
        legend.text      = element_text(size = 7.5),
        legend.margin    = margin(0, 6, 0, 6),
        legend.key.spacing.y = unit(1, "pt"),
        plot.background  = element_rect(fill = "white", colour = NA),
        plot.margin      = margin(12, 4, 8, 12)
    )

# -- Save
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
ggsave(
    filename = OUT_PNG,
    plot     = oahu_zoning_map,
    width    = 14,
    height   = 10,
    dpi      = 300,
    units    = "in"
)
cat(sprintf(
    "\n[+] Map saved (300 DPI, 14 × 10 in) -> output/%s\n",
    basename(OUT_PNG)
))
cat("\n[DONE] Phase 6 - Oahu Golf Zoning Map Complete.\n")
