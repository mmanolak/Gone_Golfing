# Purpose: Generate two high-resolution micro-maps of Oahu coloring individual
#          OSM golf course polygons by their Opportunity Cost:
#            9.1 - MICE-pooled estimate (M = 100 imputations, Rubin's Rules q_bar)
#            9.2 - Observed-acreage-only estimate (no imputation)
# Inputs:  Phase 5 The Hawaii Micro-Case Study/Data/R/Target_Golf_Polygons.gpkg
#          Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..5}.csv
#          Phase 5 The Hawaii Micro-Case Study/Data/R/Honolulu_Parcels_Reprojected.gpkg
#          Phase 2 Spatial Polygons and True Acreage/Data/R/R_Phase2_Acreage_Matched_v2.csv
# Outputs: Bulk/R/output/9.1_Oahu_Opportunity_Cost_Map.png
#          Bulk/R/output/9.2_Oahu_Opportunity_Cost_Map_ObservedOnly.png


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(tidyverse)
    library(sf)
    library(scales)
    library(ggspatial)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR    <- this.path::this.dir()
WORK_DIR      <- normalizePath(
    file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE
)
PHASE5_DATA   <- file.path(
    WORK_DIR, "Phase 5 The Hawaii Micro-Case Study", "Data", "R"
)
POLYGONS_GPKG <- file.path(PHASE5_DATA, "Target_Golf_Polygons.gpkg")
PARCELS_GPKG  <- file.path(PHASE5_DATA, "Honolulu_Parcels_Reprojected.gpkg")
PHASE2_CSV    <- file.path(
    WORK_DIR, "Phase 2 Spatial Polygons and True Acreage", "Data", "R",
    "R_Phase2_Acreage_Matched_v2.csv"
)
PHASE3_DIR    <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "R"
)
IMPUTED_PATHS <- file.path(PHASE3_DIR, paste0("R_Imputed_Dataset_", 1:100, ".csv"))
OUTPUT_DIR    <- file.path(SCRIPT_DIR, "output")
OUT_PNG1      <- file.path(OUTPUT_DIR, "9.1_Oahu_Opportunity_Cost_Map.png")
OUT_PNG2      <- file.path(OUTPUT_DIR, "9.2_Oahu_Opportunity_Cost_Map_ObservedOnly.png")

M             <- 100L
OAHU_CRS      <- 32604L  # WGS 84 / UTM Zone 4N

OAHU_LAT_MIN  <- 21.2
OAHU_LAT_MAX  <- 21.9
OAHU_LON_MIN  <- -158.5
OAHU_LON_MAX  <- -157.6

JOIN_DIST_CAP <- 500L


# === 3. FUNCTIONS ===

# Auto-scale dollar labels: $B if >= 1B, else $M.
label_oc <- function(x) {
    if_else(x >= 1e9,
            sprintf("$%.1fB", x / 1e9),
            sprintf("$%.0fM", x / 1e6))
}

# Nearest-feature spatial join: attach pooled_opp_cost from a point sf object
# to a polygon sf object, discarding matches beyond JOIN_DIST_CAP metres.
# Returns the polygon sf with added columns pooled_opp_cost and join_dist_m.
join_oc_to_polygons <- function(polygons_sf, pts_sf, oc_vals) {
    nn_idx    <- st_nearest_feature(polygons_sf, pts_sf)
    join_dist <- as.numeric(
        st_distance(polygons_sf, pts_sf[nn_idx, ], by_element = TRUE)
    )
    polygons_sf |>
        mutate(
            pooled_opp_cost = oc_vals[nn_idx],
            join_dist_m     = join_dist,
            pooled_opp_cost = if_else(
                join_dist_m > JOIN_DIST_CAP, NA_real_, pooled_opp_cost
            )
        )
}

# Render Oahu OC micro-map and return the ggplot object.
build_oahu_oc_map <- function(golf_oc_sf, oahu_outline_sf,
                            n_matched, subtitle, caption_text) {
    ggplot() +
        geom_sf(
            data      = oahu_outline_sf,
            fill      = "#e8e8e8",
            colour    = "#aaaaaa",
            linewidth = 0.35
        ) +
        geom_sf(
            data  = golf_oc_sf,
            aes(fill = pooled_opp_cost),
            colour = NA
        ) +
        scale_fill_viridis_c(
            option   = "magma",
            na.value = "#cccccc",
            name     = "Opportunity Cost",
            labels   = label_oc,
            guide    = guide_colorbar(
                barwidth       = unit(0.5, "cm"),
                barheight      = unit(5, "cm"),
                title.position = "top",
                title.hjust    = 0.5,
                ticks.colour   = "white"
            )
        ) +
        annotation_scale(
            location   = "tl",
            width_hint = 0.22,
            style      = "ticks",
            text_cex   = 0.75,
            pad_x      = unit(0.5, "cm"),
            pad_y      = unit(0.5, "cm")
        ) +
        annotation_north_arrow(
            location    = "tl",
            which_north = "true",
            pad_x       = unit(0.5, "cm"),
            pad_y       = unit(1.5, "cm"),
            style       = north_arrow_fancy_orienteering(
                fill      = c("white", "#444444"),
                line_col  = "#444444",
                text_col  = "#444444",
                text_size = 8
            )
        ) +
        labs(
            title    = "Golf Course Opportunity Cost - Oahu, Hawaiʻi",
            subtitle = subtitle,
            caption  = stringr::str_wrap(caption_text, width = 185)
        ) +
        theme_void(base_size = 12) +
        theme(
            plot.title      = element_text(
                face = "bold", size = 18, hjust = 0.5, margin = margin(b = 4)
            ),
            plot.subtitle   = element_text(
                size = 11, hjust = 0.5, colour = "#024731", margin = margin(b = 8)
            ),
            plot.caption    = element_text(
                size = 9, colour = "#024731", hjust = 0, margin = margin(t = 10)
            ),
            plot.caption.position = "plot",
            legend.position  = "right",
            legend.direction = "vertical",
            legend.title     = element_text(size = 14, face = "bold"),
            legend.text      = element_text(size = 12),
            plot.background = element_rect(fill = "white", colour = NA),
            plot.margin     = margin(12, 16, 8, 16)
        )
}


# === 4. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Micro Map 9: Oahu Golf Course Opportunity Cost\n")
cat(strrep("=", 70), "\n\n")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# -- Guard inputs
for (f in c(POLYGONS_GPKG, PARCELS_GPKG, PHASE2_CSV, IMPUTED_PATHS)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}


# ── Step 1: Filter imputed datasets to Oahu and pool OC ───────────────────────

cat("[Step 1] Filtering imputed datasets to Oahu and pooling OC...\n")
oahu_total_list <- vector("list", M)

for (i in seq_len(M)) {
    imp_df <- read_csv(IMPUTED_PATHS[i], show_col_types = FALSE) |>
        filter(
            Latitude  >= OAHU_LAT_MIN, Latitude  <= OAHU_LAT_MAX,
            Longitude >= OAHU_LON_MIN, Longitude <= OAHU_LON_MAX
        ) |>
        mutate(opp_cost = final_acreage * Baseline_Value_Per_Acre)

    oahu_total_list[[i]] <- imp_df |>
        group_by(Longitude, Latitude) |>
        summarise(
            total_opp_cost = sum(opp_cost, na.rm = TRUE),
            .groups        = "drop"
        ) |>
        mutate(imputation = i)

    cat(sprintf(
        "  Imputation %d: %d courses, Oahu total $%.3fB\n",
        i,
        nrow(oahu_total_list[[i]]),
        sum(oahu_total_list[[i]]$total_opp_cost) / 1e9
    ))
}

pooled_oahu <- bind_rows(oahu_total_list) |>
    group_by(Longitude, Latitude) |>
    summarise(
        pooled_opp_cost = mean(total_opp_cost, na.rm = TRUE),
        .groups         = "drop"
    )

cat(sprintf(
    "\n  MICE pooled Oahu total: $%.3fB across %d courses\n",
    sum(pooled_oahu$pooled_opp_cost) / 1e9,
    nrow(pooled_oahu)
))
cat(sprintf(
    "  OC range: $%.1fM – $%.1fM\n",
    min(pooled_oahu$pooled_opp_cost) / 1e6,
    max(pooled_oahu$pooled_opp_cost) / 1e6
))


# ── Step 2: Load OSM golf course polygons ─────────────────────────────────────

cat("\n[Step 2] Loading OSM golf course polygons...\n")
golf_polygons_sf <- st_read(POLYGONS_GPKG, quiet = TRUE) |>
    st_transform(OAHU_CRS)
cat(sprintf(
    "  %d golf course polygons loaded (EPSG %d).\n",
    nrow(golf_polygons_sf), OAHU_CRS
))


# ── Step 3: Spatial join - MICE points to polygons ────────────────────────────
# [METHODOLOGY] Pooled OC values are keyed by Longitude × Latitude (legacy
#               Phase 1 coordinate key). Each polygon is matched to its nearest
#               OC point via st_nearest_feature(); matches exceeding JOIN_DIST_CAP
#               (500 m) are set to NA to prevent spurious long-range assignments.

cat("\n[Step 3] Spatial join for Map 9.1 (MICE points → polygons)...\n")

oahu_pts_mice <- pooled_oahu |>
    st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |>
    st_transform(OAHU_CRS)

golf_oc_mice <- join_oc_to_polygons(
    golf_polygons_sf, oahu_pts_mice, pooled_oahu$pooled_opp_cost
)

n_matched_mice   <- sum(!is.na(golf_oc_mice$pooled_opp_cost))
n_unmatched_mice <- sum( is.na(golf_oc_mice$pooled_opp_cost))
cat(sprintf(
    "  %d matched within %d m  |  %d exceeded cap (gray).\n",
    n_matched_mice, JOIN_DIST_CAP, n_unmatched_mice
))
cat(sprintf(
    "  Median join distance: %.1f m  |  Max: %.1f m\n",
    median(golf_oc_mice$join_dist_m),
    max(golf_oc_mice$join_dist_m)
))


# ── Step 4: Build Oahu island base (shared between both maps) ─────────────────
# [METHODOLOGY] st_union() dissolves all Honolulu parcels into a single outline,
#               removing internal cadastral boundaries. Consistent with Script 3.

cat("\n[Step 4] Dissolving Honolulu parcels to island outline (~20 sec)...\n")
oahu_outline_sf <- st_read(PARCELS_GPKG, quiet = TRUE) |>
    st_transform(OAHU_CRS) |>
    st_geometry() |>
    st_union() |>
    st_sf()
cat("  Island outline complete.\n")


# ── Step 5: Render + save Map 9.1 (MICE-pooled) ───────────────────────────────

cat("\n[Step 5] Rendering Map 9.1: MICE-pooled Oahu map...\n")

map1 <- build_oahu_oc_map(
    golf_oc_sf    = golf_oc_mice,
    oahu_outline_sf = oahu_outline_sf,
    n_matched     = n_matched_mice,
    subtitle      = sprintf(
        "%d courses  │  Pooled across M = 100 MICE imputations (Rubin's Rules)  │  OSM polygon boundaries",
        n_matched_mice
    ),
    caption_text  = paste0(
        "Opportunity Cost = MICE-pooled final acreage × baseline land value per acre. ",
        "Polygon-to-point assignment via nearest-feature spatial join (cap: 500 m).\n",
        "Sources: OpenStreetMap; FHFA residential land price index (urban); ",
        "USDA agricultural land values (rural). CRS: WGS 84 / UTM Zone 4N (EPSG 32604)."
    )
)
ggsave(OUT_PNG1, map1, width = 12, height = 10, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG1)))


# ── Step 6: Observed-only Oahu OC from Phase 2 ────────────────────────────────
# [METHODOLOGY] Phase 2 acreage_source identifies directly measured courses.
#               Filtering to acreage_source != "MICE_Target" and the Oahu
#               bounding box yields observed-only OC values with no imputation.
#               No pooling required - one observed value per course.

cat("\n[Step 6] Computing observed-only Oahu OC from Phase 2...\n")

obs_oahu <- read_csv(PHASE2_CSV, show_col_types = FALSE) |>
    filter(
        acreage_source != "MICE_Target",
        Latitude  >= OAHU_LAT_MIN, Latitude  <= OAHU_LAT_MAX,
        Longitude >= OAHU_LON_MIN, Longitude <= OAHU_LON_MAX
    ) |>
    mutate(opp_cost = final_acreage * Baseline_Value_Per_Acre) |>
    group_by(Longitude, Latitude) |>
    summarise(
        pooled_opp_cost = sum(opp_cost, na.rm = TRUE),
        .groups         = "drop"
    )

cat(sprintf(
    "  Observed-only: %d courses, Oahu total $%.3fB\n",
    nrow(obs_oahu),
    sum(obs_oahu$pooled_opp_cost) / 1e9
))
cat(sprintf(
    "  Coverage vs. MICE-pooled: %.1f%%\n",
    sum(obs_oahu$pooled_opp_cost) /
        sum(pooled_oahu$pooled_opp_cost) * 100
))


# ── Step 7: Spatial join - observed-only points to polygons ───────────────────

cat("\n[Step 7] Spatial join for Map 9.2 (observed points → polygons)...\n")

oahu_pts_obs <- obs_oahu |>
    st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |>
    st_transform(OAHU_CRS)

golf_oc_obs <- join_oc_to_polygons(
    golf_polygons_sf, oahu_pts_obs, obs_oahu$pooled_opp_cost
)

n_matched_obs   <- sum(!is.na(golf_oc_obs$pooled_opp_cost))
n_unmatched_obs <- sum( is.na(golf_oc_obs$pooled_opp_cost))
cat(sprintf(
    "  %d matched within %d m  |  %d exceeded cap or no observed data (gray).\n",
    n_matched_obs, JOIN_DIST_CAP, n_unmatched_obs
))


# ── Step 8: Render + save Map 9.2 (Observed-only) ────────────────────────────

cat("\n[Step 8] Rendering Map 9.2: Observed-only Oahu map...\n")

map2 <- build_oahu_oc_map(
    golf_oc_sf      = golf_oc_obs,
    oahu_outline_sf = oahu_outline_sf,
    n_matched       = n_matched_obs,
    subtitle        = sprintf(
        "%d courses  │  Observed acreage only - no imputation  │  OSM polygon boundaries",
        n_matched_obs
    ),
    caption_text    = paste0(
        "Opportunity Cost = directly measured OSM acreage × baseline land value per acre. ",
        "Restricted to courses with acreage_source ≠ MICE_Target. ",
        "Polygon-to-point assignment via nearest-feature spatial join (cap: 500 m).\n",
        "Sources: OpenStreetMap; FHFA residential land price index (urban); ",
        "USDA agricultural land values (rural). CRS: WGS 84 / UTM Zone 4N (EPSG 32604)."
    )
)
ggsave(OUT_PNG2, map2, width = 12, height = 10, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG2)))


cat("\n")
cat(strrep("=", 70), "\n")
cat("[DONE] Phase 6 - Micro Map 9: Both Oahu OC maps written.\n\n")
