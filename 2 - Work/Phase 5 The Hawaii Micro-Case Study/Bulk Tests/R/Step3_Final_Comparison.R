# Purpose: Cross-reference Oahu golf TMKs against official parcel cadastre and
#          Phase 4 MICE-pooled opportunity cost estimates; apply spatial
#          deduplication and Rubin's Rules to produce the final comparison table.
# Inputs:  Bulk Tests/R/Target_Golf_Parcels_List.csv      (Step 2 output)
#          Bulk Tests/R/Honolulu_Parcels_Reprojected.gpkg  (Step 1 output)
#          Bulk Tests/R/Target_Golf_Polygons.gpkg          (Step 1 output)
#          Phase 4 Econometric Modeling/Data/R/R_Regression_Results.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/R/Phase5_Oahu_Comparison.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(sf)
    library(tidyverse)
    library(future)
    library(furrr)
    library(parallelly)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
WORK_DIR   <- normalizePath(
    file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE
)

TMK_LIST_PATH  <- file.path(SCRIPT_DIR, "Target_Golf_Parcels_List.csv")
PARCELS_GPKG   <- file.path(SCRIPT_DIR, "Honolulu_Parcels_Reprojected.gpkg")
OSM_POLYS_PATH <- file.path(SCRIPT_DIR, "Target_Golf_Polygons.gpkg")
OUT_CSV        <- file.path(SCRIPT_DIR, "Phase5_Oahu_Comparison.csv")

PHASE3_DATA_DIR <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "R"
)
IMPUTED_PATHS <- file.path(
    PHASE3_DATA_DIR, paste0("R_Imputed_Dataset_", seq_len(5), ".csv")
)
PHASE4_DATA_DIR <- file.path(
    WORK_DIR, "Phase 4 Econometric Modeling", "Data", "R"
)
MODEL_RDS      <- file.path(PHASE4_DATA_DIR, "R_model_results.rds")
REGRESSION_CSV <- file.path(PHASE4_DATA_DIR, "R_Regression_Results.csv")

# Hardcoded OSM-derived footprint from Step 2 geometry (acres)
OSM_DERIVED_ACRES <- 8342.28

M <- 5L  # number of MICE imputations

safe_workers <- max(min(availableCores() - 8L, 20L), 1L)
options(future.globals.maxSize = 20 * 1024^3)
plan(multisession, workers = safe_workers)


# === 3. FUNCTIONS ===

#' Append a single metric/value row to the comparison dataframe.
#'
#' @param df     Data frame with columns Metric and Value.
#' @param metric Character scalar — row label.
#' @param value  Value to coerce to character and insert.
#' @return Updated data frame with the new row appended.
add_row <- function(df, metric, value) {
    rbind(df, data.frame(
        Metric = metric,
        Value  = as.character(value),
        stringsAsFactors = FALSE
    ))
}


# === 4. EXECUTION ===

cat("\n")
cat(rep("=", 70), "\n", sep = "")
cat("Phase 5b - Step 3: Economic Validation\n")
cat(rep("=", 70), "\n", sep = "")

cat(sprintf("\n  Script dir    : %s\n", SCRIPT_DIR))
cat(sprintf("  Work dir      : %s\n", WORK_DIR))
cat(sprintf("  TMK list      : %s\n", TMK_LIST_PATH))
cat(sprintf("  Parcels GPKG  : %s\n", PARCELS_GPKG))
cat(sprintf("  OSM Polygons  : %s\n", OSM_POLYS_PATH))
cat(sprintf("  Phase 3 dir   : %s\n", PHASE3_DATA_DIR))
cat(sprintf("  Phase 4 dir   : %s\n", PHASE4_DATA_DIR))
cat(sprintf("  Output        : %s\n\n", OUT_CSV))

required <- list(
    "TMK list (Step 2 output)"     = TMK_LIST_PATH,
    "Parcels GPKG (Step 1 output)" = PARCELS_GPKG,
    "OSM Polygons (Step 1 output)" = OSM_POLYS_PATH,
    "Phase 4 regression CSV"       = REGRESSION_CSV
)
for (label in names(required)) {
    if (!file.exists(required[[label]])) {
        stop(sprintf("[FATAL] %s not found:\n  %s", label, required[[label]]))
    }
}

missing_imp <- IMPUTED_PATHS[!file.exists(IMPUTED_PATHS)]
if (length(missing_imp) > 0) {
    stop(sprintf(
        "[FATAL] Phase 3 imputed datasets not found:\n  %s",
        paste(missing_imp, collapse = "\n  ")
    ))
}

# ---- Step 1: Load TMK list ----
cat(rep("-", 70), "\n", sep = "")
cat("[Step 1] Loading TMK list from Step 2...\n")
cat(rep("-", 70), "\n", sep = "")

tmk_df <- read_csv(TMK_LIST_PATH, show_col_types = FALSE)
cat(sprintf("  Loaded %d TMKs.\n", nrow(tmk_df)))
names(tmk_df)[1] <- "tmk"
tmk_df$tmk <- as.character(tmk_df$tmk)

# ---- Step 2: Load parcel attributes and join ----
cat(rep("-", 70), "\n", sep = "")
cat("[Step 2] Loading parcel attributes from cadastre GPKG...\n")
cat(rep("-", 70), "\n", sep = "")

# [METHODOLOGY] st_read — spatial read of Step 1 parcel cadastre for attribute join
parcels_attr <- st_read(PARCELS_GPKG, quiet = TRUE) |> st_drop_geometry()

if ("tmk" %in% names(parcels_attr)) {
    parcels_attr$tmk <- as.character(parcels_attr$tmk)
} else {
    tmk_candidates <- c("TMK", "tmk8num", "tmk9num", "taxpin", "parcel_uid")
    found <- intersect(tmk_candidates, names(parcels_attr))[1]
    if (is.na(found)) stop("[FATAL] Cannot find a TMK join column in parcels GPKG.")
    parcels_attr <- parcels_attr |> rename(tmk = all_of(found))
    parcels_attr$tmk <- as.character(parcels_attr$tmk)
}

matched_parcels <- inner_join(tmk_df, parcels_attr, by = "tmk")
cat(sprintf("  TMKs from Step 2:      %d\n", nrow(tmk_df)))
cat(sprintf("  Matched in cadastre:   %d\n", nrow(matched_parcels)))

area_col <- NULL
for (candidate in c("dpp_approved_area_acres", "dpp_stated_area", "rpa_stated_area")) {
    if (candidate %in% names(matched_parcels) &&
        sum(!is.na(matched_parcels[[candidate]])) > 0) {
        area_col <- candidate
        break
    }
}

if (!is.null(area_col)) {
    official_area_acres <- sum(matched_parcels[[area_col]], na.rm = TRUE)
    n_area_na    <- sum(is.na(matched_parcels[[area_col]]))
    n_area_total <- nrow(matched_parcels)
    n_area_ok    <- n_area_total - n_area_na
    cat(sprintf("\n  Official area column used : %s\n", area_col))
    cat(sprintf(
        "  Total official area       : %s acres\n",
        formatC(official_area_acres, format = "f", digits = 2, big.mark = ",")
    ))
} else {
    official_area_acres <- NA_real_
}

cat(sprintf(
    "\n  OSM-derived legal footprint (Step 2 geometry): %s acres\n",
    formatC(OSM_DERIVED_ACRES, format = "f", digits = 2, big.mark = ",")
))

# ---- Step 3: Load optional tax assessment roll ----
cat(rep("-", 70), "\n", sep = "")
cat("[Step 3] Tax assessment roll (optional)...\n")
cat(rep("-", 70), "\n", sep = "")

tax_roll_df  <- NULL
assessed_val <- NA_real_

tax_roll_candidates <- c(
    file.path(WORK_DIR, "00 - Data Sources", "Honolulu", "tax_assessment.csv"),
    file.path(SCRIPT_DIR, "tax_assessment.csv"),
    file.path(SCRIPT_DIR, "Honolulu_Tax_Roll.csv")
)
tax_roll_path <- Filter(file.exists, tax_roll_candidates)

if (length(tax_roll_path) > 0) {
    tax_roll_df <- read_csv(tax_roll_path[[1]], show_col_types = FALSE)
    cat(sprintf(
        "  Loaded %s tax records.\n",
        formatC(nrow(tax_roll_df), big.mark = ",")
    ))
} else {
    cat("Skipping tax assessment; dollar comparison will use model values only.\n")
}

if (!is.null(tax_roll_df)) {
    tax_tmk_col <- intersect(
        c("tmk", "TMK", "TAX_MAP_KEY", "parcel_id"),
        names(tax_roll_df)
    )[1]
    val_col <- intersect(
        c("assessed_land_value", "ASSESSED_LAND_VALUE", "land_value",
          "total_assessed_value"),
        names(tax_roll_df)
    )[1]

    if (!is.na(tax_tmk_col) && !is.na(val_col)) {
        tax_roll_df[[tax_tmk_col]] <- as.character(tax_roll_df[[tax_tmk_col]])
        tax_matched  <- inner_join(
            tmk_df, tax_roll_df,
            by = setNames(tax_tmk_col, "tmk")
        )
        assessed_val <- sum(tax_matched[[val_col]], na.rm = TRUE)
        cat(sprintf(
            "\n  Total assessed value:   $%s\n",
            formatC(assessed_val, format = "f", digits = 2, big.mark = ",")
        ))
    }
}

# ---- Step 4: Load Phase 4 model output and filter for Oahu ----
cat(rep("-", 70), "\n", sep = "")
cat("[Step 4] Loading Phase 4 model output & Spatial Deduplication...\n")
cat(rep("-", 70), "\n", sep = "")

oahu_estimates <- vector("list", M)

for (i in seq_len(M)) {
    df_i <- read_csv(IMPUTED_PATHS[i], show_col_types = FALSE)
    # [METHODOLOGY] lat/lon bounding box — Oahu extents used to pre-filter national
    #               dataset before spatial deduplication; bounds from island geography
    oahu_mask <- !is.na(df_i$Longitude) & !is.na(df_i$Latitude) &
        df_i$Latitude  >= 21.2 & df_i$Latitude  <= 21.9 &
        df_i$Longitude >= -158.5 & df_i$Longitude <= -157.6

    oahu_estimates[[i]] <- df_i[oahu_mask, ] |>
        mutate(
            Total_Opportunity_Cost = final_acreage * Baseline_Value_Per_Acre,
            imputation = i
        )
}

oahu_all <- bind_rows(oahu_estimates)
cat(sprintf(
    "  Oahu courses before deduplication (per imputation): %s\n",
    paste(sapply(oahu_estimates, nrow), collapse = ", ")
))

cat("\n  Applying Spatial Deduplication using true OSM Polygons...\n")

# [METHODOLOGY] st_read — spatial read of Oahu golf polygons for deduplication
osm_polys_sf <- st_read(OSM_POLYS_PATH, quiet = TRUE) |>
    mutate(poly_id = row_number())

unique_courses <- oahu_all |>
    select(Longitude, Latitude, Holes) |>
    group_by(Longitude, Latitude) |>
    summarise(Holes = max(Holes, na.rm = TRUE), .groups = "drop")

# [METHODOLOGY] st_as_sf — convert deduplicated course coordinates to spatial points
courses_sf <- st_as_sf(
    unique_courses,
    coords = c("Longitude", "Latitude"),
    crs = 4326,
    remove = FALSE
)
# [METHODOLOGY] st_transform — reproject course points to match OSM CRS
courses_sf <- st_transform(courses_sf, st_crs(osm_polys_sf))

# [METHODOLOGY] st_nearest_feature — nearest-neighbor match to OSM polygons;
#               mirrors Phase 2's fallback matching logic
nearest_idx  <- st_nearest_feature(courses_sf, osm_polys_sf)
# [METHODOLOGY] st_distance — per-element distance from point to nearest polygon
nearest_dist <- as.numeric(st_distance(
    courses_sf, osm_polys_sf[nearest_idx, ], by_element = TRUE
))

# [METHODOLOGY] 500 m cap — only assign a polygon if within 500 m of the point;
#               threshold mirrors Phase 2 spatial tolerance for point-to-polygon matching
courses_sf$poly_id <- ifelse(
    nearest_dist <= 500, osm_polys_sf$poly_id[nearest_idx], NA
)

master_keep_list <- courses_sf |>
    mutate(group_id = ifelse(
        is.na(poly_id),
        paste0("orphan_", row_number()),
        as.character(poly_id)
    )) |>
    arrange(group_id, desc(Holes)) |>
    filter(!duplicated(group_id)) |>
    st_drop_geometry() |>
    select(Longitude, Latitude, Holes)

cat(sprintf(
    "  Unique Oahu courses after spatial deduplication: %d\n",
    nrow(master_keep_list)
))

oahu_deduped_list <- lapply(seq_len(M), function(i) {
    oahu_all |>
        filter(imputation == i) |>
        inner_join(master_keep_list, by = c("Longitude", "Latitude", "Holes"))
})

oahu_per_course <- bind_rows(oahu_deduped_list) |>
    group_by(Longitude, Latitude) |>
    summarise(
        n_imputations         = n(),
        mean_final_acreage    = mean(final_acreage, na.rm = TRUE),
        mean_baseline_val     = mean(Baseline_Value_Per_Acre, na.rm = TRUE),
        mean_opportunity_cost = mean(Total_Opportunity_Cost, na.rm = TRUE),
        Holes                 = first(Holes),
        county_type           = first(county_type),
        .groups               = "drop"
    ) |>
    arrange(Longitude)

# Rubin's Rules on the deduplicated per-imputation opportunity cost totals
oahu_agg_dedup <- sapply(
    oahu_deduped_list,
    function(d) sum(d$Total_Opportunity_Cost, na.rm = TRUE)
)

# [METHODOLOGY] Rubin's Rules — pooling across M imputations; simplified formula
#               using total-level aggregates (see Phase 4 for full coefficient pooling)
q_bar <- mean(oahu_agg_dedup)
v_w   <- mean(sapply(
    oahu_deduped_list,
    function(d) var(d$Total_Opportunity_Cost, na.rm = TRUE)
))
v_b   <- var(oahu_agg_dedup)
v_t   <- v_w + v_b + v_b / M
se    <- sqrt(v_t)
ci_lo <- q_bar - 2.576 * se
ci_hi <- q_bar + 2.576 * se

cat(sprintf(
    "\nDeduplicated Pooled Oahu Opportunity Cost: $%.3fB (99%% CI: $%.3fB - $%.3fB)\n",
    q_bar / 1e9, ci_lo / 1e9, ci_hi / 1e9
))

# ---- Step 5: Build comparison table ----
cat(rep("-", 70), "\n", sep = "")
cat("[Step 5] Building comparison table...\n")
cat(rep("-", 70), "\n", sep = "")

comparison_df <- data.frame(
    Metric = character(), Value = character(), stringsAsFactors = FALSE
)

comparison_df <- add_row(
    comparison_df, "Total Golf Courses (Oahu, OSM polygons)", nrow(osm_polys_sf)
)
comparison_df <- add_row(
    comparison_df, "Total Unique TMKs (Step 2)",
    formatC(nrow(tmk_df), big.mark = ",")
)
comparison_df <- add_row(
    comparison_df, "TMKs Matched in Cadastre",
    formatC(nrow(matched_parcels), big.mark = ",")
)
comparison_df <- add_row(
    comparison_df, "OSM-Derived Legal Footprint (acres)",
    formatC(OSM_DERIVED_ACRES, format = "f", digits = 2, big.mark = ",")
)

for (i in seq_along(oahu_agg_dedup)) {
    comparison_df <- add_row(
        comparison_df,
        sprintf("Oahu Opportunity Cost - Imputation %d ($B)", i),
        sprintf("%.3f", oahu_agg_dedup[i] / 1e9)
    )
}

comparison_df <- add_row(
    comparison_df, "Pooled Oahu Opportunity Cost - q_bar ($B)",
    sprintf("%.3f", q_bar / 1e9)
)
comparison_df <- add_row(
    comparison_df, "Standard Error ($B)", sprintf("%.3f", se / 1e9)
)
comparison_df <- add_row(
    comparison_df, "95% CI Lower ($B)", sprintf("%.3f", ci_lo / 1e9)
)
comparison_df <- add_row(
    comparison_df, "95% CI Upper ($B)", sprintf("%.3f", ci_hi / 1e9)
)

if (!is.na(assessed_val) && assessed_val > 0) {
    comparison_df <- add_row(
        comparison_df, "Total Official Assessed Value ($B)",
        sprintf("%.3f", assessed_val / 1e9)
    )
    gap_ratio     <- q_bar / assessed_val
    comparison_df <- add_row(
        comparison_df, "Gap Ratio (Modelled / Assessed)",
        sprintf("%.4f", gap_ratio)
    )
}

# ---- Step 6: Print and save ----
cat(rep("=", 70), "\n", sep = "")
cat("PHASE 5B ECONOMIC VALIDATION - RESULTS\n")
cat(rep("=", 70), "\n", sep = "")

for (i in seq_len(nrow(comparison_df))) {
    cat(sprintf(
        "  %-55s %s\n",
        comparison_df$Metric[i],
        comparison_df$Value[i]
    ))
}
cat(rep("=", 70), "\n", sep = "")

write_csv(comparison_df, OUT_CSV)
cat(sprintf("\n[+] Comparison table saved -> %s\n", OUT_CSV))

cat(sprintf(
    "\nPer-Course Summary (%d Oahu courses, averaged across %d imputations):\n",
    nrow(oahu_per_course), M
))
cat(sprintf(
    "  %-12s %-12s %-10s %-18s %s\n",
    "Latitude", "Longitude", "Holes", "Mean Acreage", "Mean Opp. Cost ($M)"
))
cat(rep("-", 70), "\n", sep = "")

for (i in seq_len(nrow(oahu_per_course))) {
    r <- oahu_per_course[i, ]
    cat(sprintf(
        "  %-12.4f %-12.4f %-10s %-18.1f $%.2fM\n",
        r$Latitude,
        r$Longitude,
        as.character(r$Holes),
        r$mean_final_acreage,
        r$mean_opportunity_cost / 1e6
    ))
}

cat("\n[DONE] Step 3 Complete.\n")
