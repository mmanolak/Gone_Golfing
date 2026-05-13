# Purpose: Generate two bivariate choropleth maps showing the joint distribution
#          of opportunity cost and golf course density (total Holes) at the U.S.
#          county level using a 3x3 tertile grid:
#            7.1 — MICE-pooled OC estimate (M = 100 imputations, Rubin's Rules)
#            7.2 — Observed-acreage-only OC estimate (no imputation)
# Inputs:  Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..100}.csv
#          Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv
#          Phase 2 Spatial Polygons and True Acreage/Data/R/R_Phase2_Acreage_Matched_v2.csv
# Outputs: Bulk/R/output/7.1_Bivariate_Cost_vs_Density_Map.png
#          Bulk/R/output/7.2_Bivariate_Cost_vs_Density_Map_ObservedOnly.png


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(tidyverse)
    library(sf)
    library(tigris)
    library(biscale)
    library(cowplot)
    library(this.path)
})
options(tigris_use_cache = TRUE)


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR    <- this.path::this.dir()
WORK_DIR      <- normalizePath(
    file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE
)
PHASE1_CSV    <- file.path(
    WORK_DIR, "Phase 1 Parsing", "Data", "R",
    "R_Phase1_Baseline_Golf_Valuation.csv"
)
PHASE2_CSV    <- file.path(
    WORK_DIR, "Phase 2 Spatial Polygons and True Acreage", "Data", "R",
    "R_Phase2_Acreage_Matched_v2.csv"
)
PHASE3_DIR    <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "R"
)
IMPUTED_PATHS <- file.path(PHASE3_DIR, paste0("R_Imputed_Dataset_", 1:100, ".csv"))
OUTPUT_DIR    <- file.path(SCRIPT_DIR, "output")
OUT_PNG1      <- file.path(OUTPUT_DIR, "7.1_Bivariate_Cost_vs_Density_Map.png")
OUT_PNG2      <- file.path(OUTPUT_DIR, "7.2_Bivariate_Cost_vs_Density_Map_ObservedOnly.png")

M             <- 100L

TERRITORY_EXCLUDE_FP <- c("60", "66", "69", "72", "74", "78")


# === 3. FUNCTIONS ===

# Classify county_data into a 3x3 bivariate grid, render the choropleth with
# an inset legend, and return the composed cowplot figure.
# county_data must have columns: FIPS, pooled_opp_cost, total_holes.
build_bivariate_map <- function(counties_sf, states_sf, county_data,
                                subtitle, caption_text) {
    counties_joined <- counties_sf |>
        left_join(county_data, by = c("GEOID" = "FIPS"))

    no_data_n <- sum(is.na(counties_joined$pooled_opp_cost))
    cat(sprintf(
        "    %d counties with no data (gray)  |  %d with data.\n",
        no_data_n, nrow(counties_joined) - no_data_n
    ))

    counties_golf <- counties_joined |>
        filter(!is.na(pooled_opp_cost), !is.na(total_holes))

    counties_bi <- bi_class(
        counties_golf,
        x     = pooled_opp_cost,
        y     = total_holes,
        style = "quantile",
        dim   = 3
    )

    tbl <- table(
        OC_tertile    = sub("-.*", "", counties_bi$bi_class),
        Holes_tertile = sub(".*-", "", counties_bi$bi_class)
    )
    cat("    Bivariate class distribution (col = OC tertile, row = Holes tertile):\n")
    capture.output(print(tbl)) |> (\(x) cat(paste0("    ", x, "\n")))()

    map_plot <- ggplot() +
        geom_sf(
            data   = counties_sf,
            fill   = "#d9d9d9",
            colour = NA
        ) +
        geom_sf(
            data        = counties_bi,
            aes(fill    = bi_class),
            colour      = NA,
            show.legend = FALSE
        ) +
        bi_scale_fill(pal = "DkViolet", dim = 3) +
        geom_sf(
            data      = states_sf,
            fill      = NA,
            colour    = "#ffffff",
            linewidth = 0.30
        ) +
        labs(
            title    = paste0(
                "Golf Course Opportunity Cost vs. Course Density",
                " — U.S. Counties"
            ),
            subtitle = subtitle,
            caption  = caption_text
        ) +
        theme_void(base_size = 12) +
        theme(
            plot.title    = element_text(face = "bold", size = 16, hjust = 0.5,
                                         margin = margin(b = 5)),
            plot.subtitle = element_text(size = 10, hjust = 0.5, colour = "grey35",
                                         margin = margin(b = 10)),
            plot.caption  = element_text(size = 7.5, colour = "grey50", hjust = 0,
                                         margin = margin(t = 10)),
            plot.margin   = margin(12, 24, 8, 24)
        )

    legend_plot <- bi_legend(
        pal  = "DkViolet",
        dim  = 3,
        xlab = "Higher OC →",
        ylab = "More Holes →",
        size = 9
    )

    ggdraw() +
        draw_plot(map_plot,    x = 0,    y = 0,    width = 1,    height = 1) +
        draw_plot(legend_plot, x = 0.58, y = 0.05, width = 0.205, height = 0.205)
}


# === 4. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Map 7: Bivariate Cost vs. Golf Density (National)\n")
cat(strrep("=", 70), "\n\n")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# -- Guard inputs
for (f in c(PHASE1_CSV, PHASE2_CSV, IMPUTED_PATHS)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}


# ── Step 1: Build county lookup ───────────────────────────────────────────────

cat("[Step 1] Building county lookup from Phase 1 baseline...\n")
phase1_df     <- read_csv(PHASE1_CSV, show_col_types = FALSE)
county_lookup <- phase1_df |>
    select(Longitude, Latitude, FIPS, County_Name, State_Abbr) |>
    distinct() |>
    mutate(FIPS = sprintf("%05d", as.integer(FIPS)))
cat(sprintf("  %d unique course coordinates loaded.\n", nrow(county_lookup)))


# ── Step 2: Pool opportunity costs across M imputations ───────────────────────

cat(sprintf(
    "\n[Step 2] Pooling opportunity cost across %d imputed datasets...\n", M
))
county_total_list <- vector("list", M)

for (i in seq_len(M)) {
    imp_df <- read_csv(IMPUTED_PATHS[i], show_col_types = FALSE) |>
        mutate(opp_cost = final_acreage * Baseline_Value_Per_Acre) |>
        left_join(county_lookup, by = c("Longitude", "Latitude"))

    n_unmatched <- sum(is.na(imp_df$FIPS))
    if (n_unmatched > 0) {
        cat(sprintf(
            "  [WARNING] Dataset %d: %d rows with no county match (excluded).\n",
            i, n_unmatched
        ))
    }

    county_total_list[[i]] <- imp_df |>
        filter(!is.na(FIPS)) |>
        group_by(FIPS, County_Name, State_Abbr) |>
        summarise(
            total_opp_cost = sum(opp_cost, na.rm = TRUE),
            .groups = "drop"
        ) |>
        mutate(imputation = i)

    cat(sprintf(
        "  Imputation %d: %d counties, national total $%.3fT\n",
        i,
        nrow(county_total_list[[i]]),
        sum(county_total_list[[i]]$total_opp_cost) / 1e12
    ))
}

pooled_county <- bind_rows(county_total_list) |>
    group_by(FIPS, County_Name, State_Abbr) |>
    summarise(
        pooled_opp_cost = mean(total_opp_cost, na.rm = TRUE),
        .groups = "drop"
    )

cat(sprintf(
    "\n  Pooled national total: $%.3fT across %d counties\n",
    sum(pooled_county$pooled_opp_cost) / 1e12,
    nrow(pooled_county)
))


# ── Step 3: Total holes per county from imputation 1 ─────────────────────────
# Holes is not a MICE-imputed variable; all 5 draws are identical.

cat("\n[Step 3] Computing total holes per county (imputation 1)...\n")
county_holes_mice <- read_csv(IMPUTED_PATHS[1], show_col_types = FALSE) |>
    left_join(county_lookup, by = c("Longitude", "Latitude")) |>
    filter(!is.na(FIPS)) |>
    group_by(FIPS) |>
    summarise(total_holes = sum(Holes, na.rm = TRUE), .groups = "drop")

cat(sprintf("  %d counties with holes data.\n", nrow(county_holes_mice)))
cat(sprintf(
    "  National total: %s holes.\n",
    format(sum(county_holes_mice$total_holes), big.mark = ",")
))

county_data_mice <- inner_join(pooled_county, county_holes_mice, by = "FIPS")
cat(sprintf(
    "  %d counties have both OC and Holes (inner join).\n",
    nrow(county_data_mice)
))

cat("\n  Top 10 counties by opportunity cost:\n")
cat(sprintf("  %-30s  %-6s  %10s  %s\n", "County", "State", "OC ($B)", "Holes"))
cat(sprintf("  %s\n", strrep("-", 62)))
top10 <- county_data_mice |> arrange(desc(pooled_opp_cost)) |> slice_head(n = 10)
for (i in seq_len(nrow(top10))) {
    cat(sprintf("  %-30s  %-6s  %10.2f  %d\n",
        top10$County_Name[i], top10$State_Abbr[i],
        top10$pooled_opp_cost[i] / 1e9, top10$total_holes[i]
    ))
}


# ── Step 4: Download county and state boundaries (shared between both maps) ────

cat("\n[Step 4] Downloading county and state boundaries via tigris...\n")
counties_sf <- tigris::counties(cb = TRUE, progress_bar = FALSE) |>
    filter(!STATEFP %in% TERRITORY_EXCLUDE_FP) |>
    shift_geometry() |>
    st_transform(5070)
cat(sprintf("  %d counties loaded with AK/HI insets (EPSG 5070).\n", nrow(counties_sf)))

states_sf <- tigris::states(cb = TRUE, progress_bar = FALSE) |>
    filter(!STATEFP %in% TERRITORY_EXCLUDE_FP) |>
    shift_geometry() |>
    st_transform(5070)
cat(sprintf("  %d states loaded with AK/HI insets.\n", nrow(states_sf)))


# ── Step 5: Render + save Map 7.1 (MICE-pooled) ───────────────────────────────

cat("\n[Step 5] Rendering Map 7.1: MICE-pooled bivariate map...\n")

final_plot1 <- build_bivariate_map(
    counties_sf  = counties_sf,
    states_sf    = states_sf,
    county_data  = county_data_mice,
    subtitle     = paste0(
        "Bivariate map  │  X: total OC (pooled M=100 MICE imputations)  ",
        "│  Y: total holes  │  AK and HI shown as insets"
    ),
    caption_text = paste0(
        "OC = OSM acreage × baseline land value per acre, pooled across M=100 MICE ",
        "imputations (Rubin's Rules). ",
        "Tertile quantile breaks applied independently to each dimension. ",
        "Counties without golf courses shown in gray. CRS: NAD83/Conus Albers (EPSG 5070). ",
        "Alaska and Hawaii repositioned as insets."
    )
)
ggsave(OUT_PNG1, final_plot1, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("\n  Saved: output/%s\n", basename(OUT_PNG1)))


# ── Step 6: Observed-only county data (OC + Holes restricted to measured courses)
# [METHODOLOGY] Phase 2 acreage_source identifies directly measured courses
#               (acreage_source != "MICE_Target"). Both OC and Holes are aggregated
#               from the same observed-course subset so the two bivariate dimensions
#               remain consistent — only counties with known acreage data contribute
#               to either axis. Since Holes is not a MICE-imputed variable, filtering
#               here has the effect of restricting to counties where we also have
#               observed acreage, enabling a clean like-for-like comparison.

cat("\n[Step 6] Computing observed-only county OC + Holes from Phase 2...\n")

obs_county_data <- read_csv(PHASE2_CSV, show_col_types = FALSE) |>
    filter(acreage_source != "MICE_Target") |>
    mutate(
        opp_cost = final_acreage * Baseline_Value_Per_Acre,
        FIPS     = sprintf("%05d", as.integer(FIPS))
    ) |>
    filter(!is.na(FIPS)) |>
    group_by(FIPS, County_Name, State_Abbr) |>
    summarise(
        pooled_opp_cost = sum(opp_cost,  na.rm = TRUE),
        total_holes     = sum(Holes,     na.rm = TRUE),
        .groups = "drop"
    )

cat(sprintf(
    "  Observed-only: %d counties  |  national OC $%.3fT\n",
    nrow(obs_county_data),
    sum(obs_county_data$pooled_opp_cost) / 1e12
))
cat(sprintf(
    "  Coverage vs. MICE-pooled: %.1f%%\n",
    sum(obs_county_data$pooled_opp_cost) /
        sum(county_data_mice$pooled_opp_cost) * 100
))


# ── Step 7: Render + save Map 7.2 (Observed-only) ────────────────────────────

cat("\n[Step 7] Rendering Map 7.2: Observed-only bivariate map...\n")

final_plot2 <- build_bivariate_map(
    counties_sf  = counties_sf,
    states_sf    = states_sf,
    county_data  = obs_county_data,
    subtitle     = paste0(
        "Bivariate map  │  X: total OC (observed acreage only)  ",
        "│  Y: total holes  │  AK and HI shown as insets"
    ),
    caption_text = paste0(
        "OC restricted to courses with directly measured OSM polygon acreage ",
        "(acreage_source ≠ MICE_Target). Holes aggregated from the same observed ",
        "subset. Tertile breaks applied independently per dimension. ",
        "CRS: NAD83/Conus Albers (EPSG 5070). Alaska and Hawaii repositioned as insets."
    )
)
ggsave(OUT_PNG2, final_plot2, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("\n  Saved: output/%s\n", basename(OUT_PNG2)))


cat("\n")
cat(strrep("=", 70), "\n")
cat("[DONE] Phase 6 - Map 7: Both bivariate maps written.\n\n")
