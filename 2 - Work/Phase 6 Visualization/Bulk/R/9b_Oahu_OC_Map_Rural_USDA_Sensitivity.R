# Purpose: Sensitivity check - Oahu opportunity cost map with courses in
#          unambiguously rural City & County of Honolulu Development Plan areas
#          (codes 15-20: Lualualei/Makaha, Makua/Kaena, Mokuleia/Waialua/Haleiwa,
#          Kawailoa/Waialee, Kahuku/Laie, Hauula/Punaluu/Kaaawa) reclassified to
#          the 2022 USDA agricultural per-acre value instead of the FHFA proxy.
#          All Oahu courses are first normalized to FHFA $4,952,600/ac before any
#          override, correcting FIPS-NA MICE imputation draws (Hawaii Kai, Mid-Pacific).
#          For thesis defense use. Addresses FHFA-aggregation caveat in SS5.4.
# Inputs:  Phase 5 The Hawaii Micro-Case Study/Data/R/Target_Golf_Polygons.gpkg
#          Phase 5 The Hawaii Micro-Case Study/Data/R/Honolulu_Parcels_Reprojected.gpkg
#          00 - Data Sources/Honolulu/Zoning_Map_Boundary.geojson
#          Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..100}.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/python/Py_Imputed_Dataset_{1..100}.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/Julia/Jl_Imputed_Dataset_{1..100}.csv
#          00 - Data Sources/Original Data/2022 - USDA County Data - Ag Use.csv
# Outputs: Bulk/R/output/9b.141_Oahu_OC_Map_Rural_USDA_Sensitivity_GrandMean.png


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(tidyverse)
    library(sf)
    library(scales)
    library(ggspatial)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
WORK_DIR   <- normalizePath(file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE)

PHASE5_DIR    <- file.path(WORK_DIR, "Phase 5 The Hawaii Micro-Case Study", "Data", "R")
POLYGONS_GPKG <- file.path(PHASE5_DIR, "Target_Golf_Polygons.gpkg")
PARCELS_GPKG  <- file.path(PHASE5_DIR, "Honolulu_Parcels_Reprojected.gpkg")

PHASE1_DIR_R  <- file.path(WORK_DIR, "Phase 1 Parsing", "Data", "R")
PHASE1_R_PATH <- file.path(PHASE1_DIR_R, "R_Phase1_Baseline_Golf_Valuation.csv")

DEV_PLAN_GEOJSON <- file.path(
    WORK_DIR, "00 - Data Sources", "Honolulu", "Zoning_Map_Boundary.geojson"
)

PHASE3_DIR_R  <- file.path(WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "R")
PHASE3_DIR_PY <- file.path(WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "python")
PHASE3_DIR_JL <- file.path(WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "Julia")

R_IMPUTED_PATHS  <- file.path(PHASE3_DIR_R,  paste0("R_Imputed_Dataset_",  1:100, ".csv"))
PY_IMPUTED_PATHS <- file.path(PHASE3_DIR_PY, paste0("Py_Imputed_Dataset_", 1:100, ".csv"))
JL_IMPUTED_PATHS <- file.path(PHASE3_DIR_JL, paste0("Jl_Imputed_Dataset_", 1:100, ".csv"))

USDA_PATH  <- file.path(
    WORK_DIR, "00 - Data Sources", "Original Data",
    "2022 - USDA County Data - Ag Use.csv"
)
OUTPUT_DIR <- file.path(SCRIPT_DIR, "output")
OUT_PNG    <- file.path(
    OUTPUT_DIR, "9b.141_Oahu_OC_Map_Rural_USDA_Sensitivity_GrandMean.png"
)

M             <- 100L
OAHU_CRS      <- 32604L    # WGS 84 / UTM Zone 4N
OAHU_LAT_MIN  <- 21.2
OAHU_LAT_MAX  <- 21.9
OAHU_LON_MIN  <- -158.5
OAHU_LON_MAX  <- -157.6
JOIN_DIST_CAP <- 500L
RURAL_ZONES   <- c("15", "16", "17", "18", "19", "20")
HONOLULU_FIPS <- "15003"

# Development Plan zone classification (ZONMAP_NO from Zoning_Map_Boundary.geojson):
# 0  : No Coverage               — no courses present
# 1  : Hawaii Kai                — FHFA
# 2  : Kahala - Kuliouou         — FHFA
# 3  : Moiliili - Kaimuki        — FHFA
# 4  : Nuuanu - McCully          — FHFA
# 5  : Kalihi - Nuuanu           — FHFA
# 6  : Red Hill - Fort Shafter   — FHFA
# 7  : Halawa - Pearl City       — FHFA
# 8  : Waipahu                   — FHFA
# 9  : Waipio (Crestview)        — FHFA
# 10 : Waipio (Mililani)         — FHFA
# 11 : Wahiawa - Whitmore        — FHFA
# 12 : Ewa Beach - Iroquois Pt   — FHFA
# 13 : Makakilo                  — FHFA
# 14 : Barber's Pt - Kahe - Nanakuli — FHFA
# 15 : Lualualei - Makaha        — USDA (unambiguously rural)
# 16 : Makua - Kaena             — USDA (unambiguously rural)
# 17 : Mokuleia - Waialua - Haleiwa — USDA (unambiguously rural)
# 18 : Kawailoa - Waialee        — USDA (unambiguously rural)
# 19 : Kahuku - Laie             — USDA (unambiguously rural)
# 20 : Hauula - Punaluu - Kaaawa — USDA (unambiguously rural)
# 21 : Kualoa - Waiahole - Kahaluu — FHFA (Windward suburban/residential)
# 22 : Heeia - Kaneohe - Maunawili — FHFA
# 23 : Kailua - Lanikai - Keolu  — FHFA
# 24 : Waimanalo                 — FHFA


# === 3. FUNCTIONS ===

get_acreage <- function(df) {
    if ("osm_acreage" %in% names(df)) df[["osm_acreage"]] else df[["final_acreage"]]
}

label_oc <- function(x) {
    if_else(x >= 1e9,
            sprintf("$%.1fB", x / 1e9),
            sprintf("$%.0fM", x / 1e6))
}

# Read 2022 USDA agricultural land value ($/acre) for the given FIPS code.
load_usda_value <- function(usda_path, fips) {
    df <- read_csv(usda_path, show_col_types = FALSE) |>
        filter(
            `Data Item` == "AG LAND, INCL BUILDINGS - ASSET VALUE, MEASURED IN $ / ACRE"
        ) |>
        mutate(
            FIPS = paste0(
                str_pad(as.integer(`State ANSI`), 2, pad = "0"),
                str_pad(as.integer(`County ANSI`), 3, pad = "0")
            ),
            Value_Numeric = as.numeric(gsub(",", "", Value))
        ) |>
        filter(FIPS == fips)
    if (nrow(df) == 0) stop(sprintf("[FATAL] USDA value for FIPS %s not found.", fips))
    df$Value_Numeric[[1]]
}

# Read FHFA residential land value ($/acre) from Phase 1 R baseline output.
# All resolved Oahu courses carry the same FHFA county-level value; the first
# non-NA row for the given FIPS is taken. Used to normalize ALL Oahu course
# BVPA values before the rural USDA override, correcting FIPS-NA draws.
load_fhfa_oahu_value <- function(path, fips) {
    df <- read_csv(path, show_col_types = FALSE) |>
        filter(FIPS == fips, !is.na(Baseline_Value_Per_Acre))
    if (nrow(df) == 0) stop(sprintf(
        "[FATAL] FHFA value for FIPS %s not found in Phase 1 R output.", fips
    ))
    df$Baseline_Value_Per_Acre[[1]]
}

# Build a poly_id -> Zone_Code lookup from golf course polygon centroids joined
# against the City & County of Honolulu Development Plan boundary layer.
# ZONMAP_NO (integer 0-24) is the Development Plan zone code.
build_devplan_lookup <- function(golf_polygons_sf, devplan_sf) {
    golf_centroids <- golf_polygons_sf |>
        mutate(poly_id = row_number()) |>
        # [METHODOLOGY] st_centroid - representative interior point for zone assignment
        st_centroid()

    # [METHODOLOGY] st_join with st_within: each golf course centroid is assigned to
    #               the Development Plan polygon that strictly contains it. ZONMAP_NO
    #               is the City & County zone code (0-24).
    zone_sf <- st_join(
        golf_centroids,
        devplan_sf |> select(ZONMAP_NO),
        join = st_within,
        left = TRUE
    )

    poly_zones <- zone_sf |>
        st_drop_geometry() |>
        group_by(poly_id) |>
        slice_head(n = 1) |>
        ungroup() |>
        mutate(Zone_Code = as.character(ZONMAP_NO)) |>
        select(poly_id, Zone_Code)

    na_ids <- poly_zones |> filter(is.na(Zone_Code)) |> pull(poly_id)
    if (length(na_ids) > 0) {
        na_centroids <- golf_centroids |> filter(poly_id %in% na_ids)
        # [METHODOLOGY] st_nearest_feature - fallback for centroids outside all
        #               Development Plan polygons (coastal edge artifact).
        nn_idx <- st_nearest_feature(na_centroids, devplan_sf)
        fallback <- tibble(
            poly_id   = na_centroids$poly_id,
            Zone_Code = as.character(devplan_sf$ZONMAP_NO[nn_idx])
        )
        poly_zones <- poly_zones |>
            filter(!poly_id %in% na_ids) |>
            bind_rows(fallback)
    }

    poly_zones
}

# For each Oahu course coordinate, find the nearest golf polygon and inherit
# its Development Plan zone code. Returns course_coords augmented with
# Zone_Code and join_dist_m.
assign_course_zones <- function(course_coords, golf_polygons_sf, poly_zones) {
    course_pts_sf <- course_coords |>
        # [METHODOLOGY] st_as_sf - convert tabular Lon/Lat to point geometry
        st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |>
        # [METHODOLOGY] st_transform - reproject to UTM Zone 4N for distance accuracy
        st_transform(OAHU_CRS)

    # [METHODOLOGY] st_nearest_feature - assigns each Phase 1 coordinate to the nearest
    #               golf polygon; matches > JOIN_DIST_CAP m are retained but flagged.
    nn_idx  <- st_nearest_feature(course_pts_sf, golf_polygons_sf)
    nn_dist <- as.numeric(
        st_distance(course_pts_sf, golf_polygons_sf[nn_idx, ], by_element = TRUE)
    )

    course_coords |>
        mutate(
            poly_id     = if_else(nn_dist <= JOIN_DIST_CAP, nn_idx, NA_integer_),
            join_dist_m = nn_dist
        ) |>
        left_join(poly_zones, by = "poly_id") |>
        select(Longitude, Latitude, Zone_Code, join_dist_m)
}

# Pool one language group's 100 imputed datasets with the Development Plan
# zone BVPA override. All Oahu BVPA values are first normalized to fhfa_value
# (correcting FIPS-NA MICE imputation draws for Hawaii Kai and Mid-Pacific),
# then courses in RURAL_ZONES are overridden with usda_value.
# Returns Rubin's q_bar per course.
pool_oahu_oc_sensitivity <- function(paths, lang_label, zone_lookup,
                                        fhfa_value, usda_value, rural_zones) {
    total_list <- vector("list", M)
    cat(sprintf(
        "  [%s] Pooling %d imputations (FHFA normalization + Dev Plan rural override for zones %s)...\n",
        lang_label, M, paste(rural_zones, collapse = "/")
    ))
    for (i in seq_len(M)) {
        df <- read_csv(paths[i], show_col_types = FALSE) |>
            filter(
                Latitude  >= OAHU_LAT_MIN, Latitude  <= OAHU_LAT_MAX,
                Longitude >= OAHU_LON_MIN, Longitude <= OAHU_LON_MAX
            ) |>
            left_join(
                zone_lookup |> select(Longitude, Latitude, Zone_Code),
                by = c("Longitude", "Latitude")
            ) |>
            mutate(
                # Normalize ALL Oahu BVPA to the verified FHFA value first.
                # Corrects FIPS-NA courses (Hawaii Kai, Mid-Pacific) whose BVPA
                # was MICE-imputed in Py/Jl datasets rather than assigned FHFA.
                Baseline_Value_Per_Acre = fhfa_value,
                # Override Development Plan rural zones (15-20) with USDA value.
                Baseline_Value_Per_Acre = if_else(
                    !is.na(Zone_Code) & Zone_Code %in% rural_zones,
                    usda_value,
                    Baseline_Value_Per_Acre
                ),
                acreage  = get_acreage(pick(everything())),
                opp_cost = acreage * Baseline_Value_Per_Acre
            )

        total_list[[i]] <- df |>
            group_by(Longitude, Latitude) |>
            summarise(
                total_opp_cost = sum(opp_cost, na.rm = TRUE),
                .groups        = "drop"
            ) |>
            mutate(imputation = i)
        rm(df)
        gc()
    }

    # [METHODOLOGY] Rubin's Rules q_bar: mean of per-imputation course-level OC
    #               values across M = 100 imputations for this language group.
    bind_rows(total_list) |>
        group_by(Longitude, Latitude) |>
        summarise(
            pooled_opp_cost = mean(total_opp_cost, na.rm = TRUE),
            .groups         = "drop"
        )
}

# Nearest-feature spatial join: attach pooled OC values to golf polygon sf.
# Matches exceeding JOIN_DIST_CAP metres are set to NA.
join_oc_to_polygons <- function(polygons_sf, pts_sf, oc_vals) {
    # [METHODOLOGY] st_nearest_feature - assigns each golf polygon to its nearest
    #               OC point; cap at 500 m prevents spurious long-range assignments.
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
            data   = golf_oc_sf,
            aes(fill = pooled_opp_cost),
            colour = NA
        ) +
        scale_fill_viridis_c(
            option   = "magma",
            na.value = "#cccccc",
            name     = "Opportunity Cost",
            labels   = label_oc,
            guide    = guide_colorbar(
                barwidth       = unit(21, "cm"),
                barheight      = unit(0.45, "cm"),
                title.position = "top",
                title.hjust    = 0.5,
                ticks.colour   = "white"
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
        annotation_north_arrow(
            location    = "tr",
            which_north = "true",
            pad_x       = unit(0.5, "cm"),
            pad_y       = unit(0.5, "cm"),
            style       = north_arrow_fancy_orienteering(
                fill      = c("white", "#444444"),
                line_col  = "#444444",
                text_col  = "#444444",
                text_size = 8
            )
        ) +
        labs(
            title    = "Golf Course Opportunity Cost - Oahu, Hawaiʻi (Rural-USDA Sensitivity)",
            subtitle = subtitle,
            caption  = stringr::str_wrap(caption_text, width = 185)
        ) +
        theme_void(base_size = 12) +
        theme(
            plot.title = element_text(
                face = "bold", size = 16, hjust = 0.5, margin = margin(b = 4)
            ),
            plot.subtitle = element_text(
                size = 11, hjust = 0.5, colour = "#024731", margin = margin(b = 8)
            ),
            plot.caption = element_text(
                size = 9, colour = "#024731", hjust = 0, margin = margin(t = 10)
            ),
            plot.caption.position = "plot",
            legend.position       = "bottom",
            legend.title          = element_text(size = 14, face = "bold"),
            legend.text           = element_text(size = 12),
            plot.background       = element_rect(fill = "white", colour = NA),
            plot.margin           = margin(12, 16, 8, 16)
        )
}


# === 4. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Micro Map 9b: Oahu OC Map (Rural-USDA Sensitivity)\n")
cat(strrep("=", 70), "\n\n")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

for (f in c(POLYGONS_GPKG, PARCELS_GPKG, DEV_PLAN_GEOJSON, PHASE1_R_PATH, USDA_PATH,
            R_IMPUTED_PATHS, PY_IMPUTED_PATHS, JL_IMPUTED_PATHS)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}


# Step 1: Load economic baseline values

cat("[Step 1] Loading USDA agricultural value for FIPS", HONOLULU_FIPS, "...\n")
USDA_RURAL_VALUE <- load_usda_value(USDA_PATH, HONOLULU_FIPS)
cat(sprintf(
    "  USDA agricultural value (FIPS %s, 2022): $%s/acre\n",
    HONOLULU_FIPS,
    format(as.integer(USDA_RURAL_VALUE), big.mark = ",")
))

cat("[Step 1b] Loading FHFA residential value for FIPS", HONOLULU_FIPS, "...\n")
FHFA_OAHU_VALUE <- load_fhfa_oahu_value(PHASE1_R_PATH, HONOLULU_FIPS)
cat(sprintf(
    "  FHFA residential value (FIPS %s, 2022): $%s/acre\n",
    HONOLULU_FIPS,
    format(as.integer(FHFA_OAHU_VALUE), big.mark = ",")
))


# Step 2: Load spatial layers

cat("\n[Step 2] Loading spatial layers...\n")

# [METHODOLOGY] Spatial read of Target_Golf_Polygons.gpkg (OSM-derived golf course
#               footprints); st_transform to EPSG 32604 (WGS 84 / UTM Zone 4N).
golf_polygons_sf <- st_read(POLYGONS_GPKG, quiet = TRUE) |>
    st_transform(OAHU_CRS)
cat(sprintf("  %d golf course polygons loaded (EPSG %d).\n",
            nrow(golf_polygons_sf), OAHU_CRS))

# [METHODOLOGY] Spatial read of Zoning_Map_Boundary.geojson: City and County of
#               Honolulu Development Plan boundary layer. ZONMAP_NO (integer 0-24)
#               is the zone code used to classify courses as FHFA or USDA.
devplan_sf <- st_read(DEV_PLAN_GEOJSON, quiet = TRUE) |>
    st_transform(OAHU_CRS)
cat(sprintf("  %d Development Plan polygons loaded (ZONMAP_NO range: %d-%d).\n",
            nrow(devplan_sf),
            min(devplan_sf$ZONMAP_NO, na.rm = TRUE),
            max(devplan_sf$ZONMAP_NO, na.rm = TRUE)))

# [METHODOLOGY] Spatial read of Honolulu_Parcels_Reprojected.gpkg; used only for
#               island outline construction in Step 6 (st_union dissolve).
cat("  Loading Honolulu parcels for island outline (may take ~20 sec)...\n")
parcels_sf <- st_read(PARCELS_GPKG, quiet = TRUE) |>
    st_transform(OAHU_CRS)
cat(sprintf("  %d parcel polygons loaded.\n", nrow(parcels_sf)))


# Step 3: Build Development Plan zone lookup for Oahu course coordinates

cat("\n[Step 3] Building Development Plan zone lookup for golf course coordinates...\n")

poly_zones <- build_devplan_lookup(golf_polygons_sf, devplan_sf)

cat(sprintf(
    "  Zone assignment: %d/%d polygons assigned a zone.\n",
    sum(!is.na(poly_zones$Zone_Code)),
    nrow(golf_polygons_sf)
))

zone_summary <- poly_zones |>
    count(Zone_Code, name = "n_polygons") |>
    mutate(override = if_else(Zone_Code %in% RURAL_ZONES, "USDA", "FHFA")) |>
    arrange(as.integer(Zone_Code))

cat("\n  Zone distribution of Oahu golf course polygons:\n")
cat(sprintf("  %-6s  %-10s  %s\n", "Zone", "n_polygons", "BVPA"))
for (i in seq_len(nrow(zone_summary))) {
    cat(sprintf("  %-6s  %-10d  %s\n",
        zone_summary$Zone_Code[i],
        zone_summary$n_polygons[i],
        zone_summary$override[i]
    ))
}

# Get unique Oahu course coordinates from the first R imputed dataset
coords_df <- read_csv(R_IMPUTED_PATHS[1], show_col_types = FALSE) |>
    filter(
        Latitude  >= OAHU_LAT_MIN, Latitude  <= OAHU_LAT_MAX,
        Longitude >= OAHU_LON_MIN, Longitude <= OAHU_LON_MAX
    ) |>
    select(Longitude, Latitude) |>
    distinct()

cat(sprintf("\n  %d unique Oahu course coordinates (from R imputation 1).\n",
            nrow(coords_df)))

zone_lookup <- assign_course_zones(coords_df, golf_polygons_sf, poly_zones)

n_rural    <- sum(!is.na(zone_lookup$Zone_Code) & zone_lookup$Zone_Code %in% RURAL_ZONES,
                    na.rm = TRUE)
n_nonrural <- nrow(zone_lookup) - n_rural

cat(sprintf(
    "  Rural BVPA override applies to: %d courses (Dev Plan zones %s, USDA $%s/ac)\n",
    n_rural,
    paste(RURAL_ZONES, collapse = "/"),
    format(as.integer(USDA_RURAL_VALUE), big.mark = ",")
))
cat(sprintf("  FHFA residential proxy retained for: %d courses\n", n_nonrural))

cat("\n  Per-course zone assignments:\n")
cat(sprintf("  %-12s  %-12s  %-6s  %s\n", "Longitude", "Latitude", "Zone", "BVPA"))
for (i in seq_len(nrow(zone_lookup))) {
    zc  <- ifelse(is.na(zone_lookup$Zone_Code[i]), "NA", zone_lookup$Zone_Code[i])
    bvp <- if (!is.na(zone_lookup$Zone_Code[i]) &&
                zone_lookup$Zone_Code[i] %in% RURAL_ZONES) "USDA" else "FHFA"
    cat(sprintf("  %-12.4f  %-12.4f  %-6s  %s\n",
        zone_lookup$Longitude[i], zone_lookup$Latitude[i], zc, bvp))
}


# Step 4: Pool tri-language MICE with FHFA normalization + Dev Plan rural override; Grand Mean

cat("\n[Step 4] Pooling tri-language MICE (FHFA normalization + Dev Plan rural override)...\n")

pooled_r  <- pool_oahu_oc_sensitivity(
    R_IMPUTED_PATHS,  "R",  zone_lookup, FHFA_OAHU_VALUE, USDA_RURAL_VALUE, RURAL_ZONES
)
pooled_py <- pool_oahu_oc_sensitivity(
    PY_IMPUTED_PATHS, "Py", zone_lookup, FHFA_OAHU_VALUE, USDA_RURAL_VALUE, RURAL_ZONES
)
pooled_jl <- pool_oahu_oc_sensitivity(
    JL_IMPUTED_PATHS, "Jl", zone_lookup, FHFA_OAHU_VALUE, USDA_RURAL_VALUE, RURAL_ZONES
)

# [METHODOLOGY] Grand Mean = arithmetic mean of three independently Rubin-pooled
#               OC vectors (M=100 each). full_join on coordinate key preserves all
#               courses regardless of which language-dataset covers them.
pooled_oahu <- pooled_r |>
    rename(oc_r = pooled_opp_cost) |>
    full_join(
        pooled_py |> rename(oc_py = pooled_opp_cost),
        by = c("Longitude", "Latitude")
    ) |>
    full_join(
        pooled_jl |> rename(oc_jl = pooled_opp_cost),
        by = c("Longitude", "Latitude")
    ) |>
    mutate(
        pooled_opp_cost = rowMeans(cbind(oc_r, oc_py, oc_jl), na.rm = TRUE)
    ) |>
    select(Longitude, Latitude, pooled_opp_cost)

cat(sprintf(
    "\n  Grand Mean Oahu total (Rural-USDA Sensitivity): $%.3fB across %d courses\n",
    sum(pooled_oahu$pooled_opp_cost, na.rm = TRUE) / 1e9,
    nrow(pooled_oahu)
))
cat(sprintf(
    "  OC range: $%.1fM - $%.1fM\n",
    min(pooled_oahu$pooled_opp_cost, na.rm = TRUE) / 1e6,
    max(pooled_oahu$pooled_opp_cost, na.rm = TRUE) / 1e6
))


# Step 5: Spatial join Grand Mean sensitivity points to golf polygons

cat("\n[Step 5] Spatial join (Grand Mean sensitivity points -> polygons)...\n")

# [METHODOLOGY] st_as_sf converts Longitude/Latitude coordinate key to point
#               geometry; st_transform reprojects to EPSG 32604 to match polygon CRS.
oahu_pts_sensitivity <- pooled_oahu |>
    st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |>
    st_transform(OAHU_CRS)

golf_oc_sens <- join_oc_to_polygons(
    golf_polygons_sf, oahu_pts_sensitivity, pooled_oahu$pooled_opp_cost
)

n_matched   <- sum(!is.na(golf_oc_sens$pooled_opp_cost))
n_unmatched <- sum( is.na(golf_oc_sens$pooled_opp_cost))
cat(sprintf(
    "  %d matched within %d m  |  %d exceeded cap (gray).\n",
    n_matched, JOIN_DIST_CAP, n_unmatched
))
cat(sprintf(
    "  Median join distance: %.1f m  |  Max: %.1f m\n",
    median(golf_oc_sens$join_dist_m),
    max(golf_oc_sens$join_dist_m)
))


# Step 6: Build Oahu island outline from parcels

cat("\n[Step 6] Dissolving parcels to island outline...\n")
# [METHODOLOGY] st_union() dissolves all Honolulu parcels into a single island
#               outline, removing internal cadastral boundaries. Consistent with
#               Script 9 (run_9_Oahu_Opportunity_Cost_Map).
oahu_outline_sf <- parcels_sf |>
    st_geometry() |>
    st_union() |>
    st_sf()
rm(parcels_sf)
gc()
cat("  Island outline complete.\n")


# Step 7: Render + save sensitivity map

cat("\n[Step 7] Rendering Rural-USDA Sensitivity map...\n")

caption_text <- paste0(
    "Sensitivity visualization: Honolulu County courses are reclassified by the City ",
    "and County of Honolulu's Development Plan boundary layer. Courses in unambiguously ",
    "rural Development Plan areas (codes 15-20: Lualualei/Makaha, Makua/Kaena, ",
    "Mokuleia/Waialua/Haleiwa, Kawailoa/Waialee, Kahuku/Laie, Hauula/Punaluu/Kaaawa) ",
    "have been reclassified to use the 2022 USDA agricultural per-acre value ($",
    format(as.integer(USDA_RURAL_VALUE), big.mark = ","),
    "/ac) rather than the FHFA residential value ($",
    format(as.integer(FHFA_OAHU_VALUE), big.mark = ","),
    "/ac). Code 0 (No Coverage) has no golf courses. ",
    "All other Oahu courses (Development Plan codes 1-14, 21-24) retain the ",
    "FHFA urban proxy used in the thesis. ",
    "All Oahu courses are first normalized to FHFA $",
    format(as.integer(FHFA_OAHU_VALUE), big.mark = ","),
    "/ac before rural zones are overridden; this corrects FIPS-NA courses ",
    "(Hawaii Kai, Mid-Pacific) whose baseline was MICE-imputed in Python/Julia datasets. ",
    "Opportunity Cost = Grand Mean of three independently Rubin-pooled OC estimates ",
    "(100 Python, 100 R, 100 Julia MICE imputations). ",
    "This sensitivity check addresses the FHFA-aggregation limitation documented in ",
    "§5.4 of the thesis, where Honolulu County's countywide FHFA index does not ",
    "distinguish rural submarkets from the urban core. ",
    "Polygon-to-point assignment via nearest-feature spatial join (cap: 500 m). ",
    "Sources: OpenStreetMap; FHFA residential land price index (2022, Honolulu County); ",
    "USDA 2022 Agricultural Census (Honolulu County); ",
    "City & County of Honolulu Development Plan boundaries. ",
    "CRS: WGS 84 / UTM Zone 4N (EPSG 32604)."
)

map_sens <- build_oahu_oc_map(
    golf_oc_sf      = golf_oc_sens,
    oahu_outline_sf = oahu_outline_sf,
    n_matched       = n_matched,
    subtitle        = sprintf(
        paste0(
            "%d courses  │  Grand Mean Py/R/Jl (M = 300: 100 each)  │  ",
            "Dev Plan Zones 15-20 → USDA $%s/ac  │  FHFA normalized"
        ),
        n_matched,
        format(as.integer(USDA_RURAL_VALUE), big.mark = ",")
    ),
    caption_text = caption_text
)

ggsave(OUT_PNG, map_sens, width = 12, height = 10, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG)))

cat("\n")
cat(strrep("=", 70), "\n")
cat("[DONE] Phase 6 - Script 9b: Rural-USDA Sensitivity Map complete.\n\n")
