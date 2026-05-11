# Purpose: Map OLS residuals (actual − predicted) at the county level to
#          diagnose spatial autocorrelation in the Phase 4 regression.
#            15.1 — Mean log-residual per county  (statistical diagnostic)
#            15.2 — Sum dollar-residual per county (economic interpretation)
# Inputs:  Phase 4 Econometric Modeling/Data/R/R_Regression_Results.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..100}.csv
#          Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv
# Outputs: Bulk/R/output/15.1_Log_Residual_Map.png
#          Bulk/R/output/15.2_Dollar_Residual_Map.png


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(tidyverse)
    library(sf)
    library(tigris)
    library(scales)
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
PHASE3_DIR    <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "R"
)
REG_CSV       <- file.path(
    WORK_DIR, "Phase 4 Econometric Modeling", "Data", "R",
    "R_Regression_Results.csv"
)
IMPUTED_PATHS <- file.path(PHASE3_DIR, paste0("R_Imputed_Dataset_", 1:100, ".csv"))
OUTPUT_DIR    <- file.path(SCRIPT_DIR, "output")
OUT_PNG1      <- file.path(OUTPUT_DIR, "15.1_Log_Residual_Map.png")
OUT_PNG2      <- file.path(OUTPUT_DIR, "15.2_Dollar_Residual_Map.png")

M                 <- 100L
TERRITORY_STATEFP <- c("60", "66", "69", "72", "74", "78")


# === 3. FUNCTIONS ===

# Render a diverging county choropleth. map_type = "log" uses the raw
# Mean_Log_Residual; map_type = "dollar" applies a signed square-root
# compression to handle the fat-tailed dollar distribution (LA, NYC outliers).
build_residual_map <- function(counties_joined, fill_col, title, subtitle,
                                caption_text, map_type = c("log", "dollar")) {
    map_type <- match.arg(map_type)

    if (map_type == "log") {
        lim <- max(abs(counties_joined[[fill_col]]), na.rm = TRUE)

        fill_scale <- scale_fill_gradient2(
            low      = "#4575b4",   # blue  = over-predict  (negative residual)
            mid      = "white",
            high     = "#d73027",   # red   = under-predict (positive residual)
            midpoint = 0,
            limits   = c(-lim, lim),
            na.value = "#d4d4d4",
            name     = "Mean Log-Residual",
            guide    = guide_colorbar(
                barwidth       = unit(14, "cm"),
                barheight      = unit(0.45, "cm"),
                title.position = "top",
                title.hjust    = 0.5,
                ticks.colour   = "grey40"
            )
        )

    } else {
        # [METHODOLOGY] Signed square-root: plot_fill = sign(x) * sqrt(|x| / 1e6).
        # Preserves sign (direction) and compresses outlier magnitude symmetrically
        # on both sides of zero — unlike log, it handles negative residuals cleanly.
        counties_joined <- counties_joined |>
            mutate(
                plot_fill = sign(.data[[fill_col]]) *
                    sqrt(abs(.data[[fill_col]]) / 1e6)
            )
        fill_col <- "plot_fill"
        lim      <- max(abs(counties_joined$plot_fill), na.rm = TRUE)

        # Build legend breaks in sqrt-space; label them in original dollar units.
        sqrt_breaks   <- pretty(c(-lim, lim), n = 6)
        dollar_labels <- sapply(sqrt_breaks, function(s) {
            d <- sign(s) * s^2 * 1e6  # inverse transform
            if      (abs(d) >= 1e9) sprintf("$%.1fB", d / 1e9)
            else if (abs(d) >= 1e6) sprintf("$%.0fM", d / 1e6)
            else if (abs(d) >= 1e3) sprintf("$%.0fK", d / 1e3)
            else                    sprintf("$%.0f",  d)
        })

        fill_scale <- scale_fill_gradient2(
            low      = "#4575b4",
            mid      = "white",
            high     = "#d73027",
            midpoint = 0,
            limits   = c(-lim, lim),
            breaks   = sqrt_breaks,
            labels   = dollar_labels,
            na.value = "#d4d4d4",
            name     = "Dollar Residual",
            guide    = guide_colorbar(
                barwidth       = unit(14, "cm"),
                barheight      = unit(0.45, "cm"),
                title.position = "top",
                title.hjust    = 0.5,
                ticks.colour   = "grey40"
            )
        )
    }

    ggplot(counties_joined) +
        geom_sf(
            aes(fill = .data[[fill_col]]),
            colour    = "white",
            linewidth = 0.08
        ) +
        fill_scale +
        labs(title = title, subtitle = subtitle, caption = caption_text) +
        theme_void(base_size = 12) +
        theme(
            plot.title    = element_text(
                face = "bold", size = 18, hjust = 0.5, margin = margin(b = 5)
            ),
            plot.subtitle = element_text(
                size = 10, hjust = 0.5, colour = "grey35", margin = margin(b = 12)
            ),
            plot.caption  = element_text(
                size = 7, colour = "grey50", hjust = 0, margin = margin(t = 12)
            ),
            legend.position = "bottom",
            legend.title    = element_text(size = 9, face = "bold"),
            legend.text     = element_text(size = 8),
            plot.margin     = margin(12, 24, 8, 24)
        )
}


# === 4. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Map 15: OLS Residual Maps (Log + Dollar)\n")
cat(strrep("=", 70), "\n\n")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

for (f in c(PHASE1_CSV, REG_CSV, IMPUTED_PATHS)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}


# ── Step 1: Load Phase 4 regression coefficients ──────────────────────────────

cat("[Step 1] Loading Phase 4 regression coefficients...\n")
reg_df   <- read_csv(REG_CSV, show_col_types = FALSE)
get_coef <- function(param) reg_df$Coef[reg_df$Parameter == param]

b0      <- get_coef("(Intercept)")
b_holes <- get_coef("Holes")
b_urban <- get_coef("factor(county_type)Urban")

cat(sprintf("  b0 = %.5f  |  b_holes = %.5f  |  b_urban = %.5f\n",
    b0, b_holes, b_urban))


# ── Step 2: Build county FIPS lookup from Phase 1 ─────────────────────────────
# [METHODOLOGY] Imputed datasets carry only Longitude/Latitude — no FIPS.
#               Phase 1 maps every course coordinate to its 5-digit FIPS code,
#               enabling county-level aggregation via the same join used in
#               Scripts 1 and 2.

cat("\n[Step 2] Building county FIPS lookup from Phase 1...\n")
phase1_df     <- read_csv(PHASE1_CSV, show_col_types = FALSE)
county_lookup <- phase1_df |>
    select(Longitude, Latitude, FIPS, County_Name, State_Abbr) |>
    distinct() |>
    mutate(FIPS = sprintf("%05d", as.integer(FIPS)))
cat(sprintf("  %d unique course coordinates loaded.\n", nrow(county_lookup)))


# ── Step 3: Compute residuals per imputation and pool ─────────────────────────
# [METHODOLOGY] For each imputed dataset:
#   Predicted_Log   = b0 + b_holes * Holes + b_urban * I(county_type == "Urban")
#   Log_Residual    = log(final_acreage) - Predicted_Log
#   Dollar_Residual = (final_acreage - exp(Predicted_Log)) * Baseline_Value_Per_Acre
# County aggregation: mean of log-residuals (Map 1), sum of dollar-residuals (Map 2).
# Both are averaged across M = 100 imputations via Rubin's Rules q_bar.

cat(sprintf("\n[Step 3] Computing residuals across %d imputed datasets...\n", M))
resid_list <- vector("list", M)

for (i in seq_len(M)) {
    imp_df <- read_csv(IMPUTED_PATHS[i], show_col_types = FALSE) |>
        left_join(county_lookup, by = c("Longitude", "Latitude")) |>
        filter(
            !is.na(FIPS),
            !is.na(Holes),
            !is.na(final_acreage), final_acreage > 0,
            !is.na(Baseline_Value_Per_Acre)
        ) |>
        mutate(
            Holes         = as.numeric(Holes),
            is_urban      = as.integer(county_type == "Urban"),
            predicted_log = b0 + b_holes * Holes + b_urban * is_urban,
            log_residual  = log(final_acreage) - predicted_log,
            dollar_resid  = (final_acreage - exp(predicted_log)) * Baseline_Value_Per_Acre
        )

    resid_list[[i]] <- imp_df |>
        group_by(FIPS, County_Name, State_Abbr) |>
        summarise(
            mean_log_residual   = mean(log_residual, na.rm = TRUE),
            sum_dollar_residual = sum(dollar_resid,  na.rm = TRUE),
            .groups = "drop"
        ) |>
        mutate(imputation = i)

    cat(sprintf(
        "  Imputation %3d: %d counties  |  national dollar residual sum $%.3fB\n",
        i, nrow(resid_list[[i]]),
        sum(resid_list[[i]]$sum_dollar_residual) / 1e9
    ))
}

pooled_resid <- bind_rows(resid_list) |>
    group_by(FIPS, County_Name, State_Abbr) |>
    summarise(
        Mean_Log_Residual   = mean(mean_log_residual,   na.rm = TRUE),
        Sum_Dollar_Residual = mean(sum_dollar_residual, na.rm = TRUE),
        .groups = "drop"
    )

cat(sprintf("\n  Residuals pooled: %d counties\n", nrow(pooled_resid)))
cat(sprintf(
    "  Log-residual range:    [%.3f, %.3f]  (0 = perfect fit)\n",
    min(pooled_resid$Mean_Log_Residual),
    max(pooled_resid$Mean_Log_Residual)
))
cat(sprintf(
    "  Dollar-residual range: [$%.2fB, $%.2fB]\n",
    min(pooled_resid$Sum_Dollar_Residual) / 1e9,
    max(pooled_resid$Sum_Dollar_Residual) / 1e9
))


# ── Step 4: Download county boundaries ────────────────────────────────────────

cat("\n[Step 4] Downloading county boundaries via tigris...\n")
counties_sf <- tigris::counties(cb = TRUE, progress_bar = FALSE) |>
    filter(!STATEFP %in% TERRITORY_STATEFP) |>
    shift_geometry() |>
    st_transform(5070)
cat(sprintf("  %d counties loaded with AK/HI insets (EPSG 5070).\n", nrow(counties_sf)))

counties_joined <- counties_sf |>
    left_join(pooled_resid, by = c("GEOID" = "FIPS"))

no_data_n <- sum(is.na(counties_joined$Mean_Log_Residual))
cat(sprintf(
    "  %d counties with no course data (gray)  |  %d with residuals.\n",
    no_data_n, nrow(counties_joined) - no_data_n
))


# ── Step 5: Render + save Map 15.1 (Log-Residual) ─────────────────────────────

cat("\n[Step 5] Rendering Map 15.1: Mean log-residual by county...\n")

map1 <- build_residual_map(
    counties_joined,
    fill_col     = "Mean_Log_Residual",
    title        = "OLS Spatial Diagnostics: Mean Log-Residuals by County",
    subtitle     = paste0(
        "log(actual acreage) − log(predicted acreage)  │  ",
        "Red = model under-predicts  │  Blue = model over-predicts  │  ",
        "Pooled across M = 100 MICE imputations"
    ),
    caption_text = paste0(
        "OLS model: log(final_acreage) = β₀ + β₁·Holes + β₂·I(Urban), ",
        "estimated via Rubin's Rules (M = 100 imputations). ",
        "County value = mean of course-level log-residuals.\n",
        "Sources: OpenStreetMap golf course polygons; FHFA residential land price index (urban); ",
        "USDA agricultural land values (rural). ",
        "CRS: NAD83 / Conus Albers (EPSG 5070). Alaska and Hawaii shown as insets."
    ),
    map_type = "log"
)
ggsave(OUT_PNG1, map1, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG1)))


# ── Step 6: Render + save Map 15.2 (Dollar-Residual) ─────────────────────────

cat("\n[Step 6] Rendering Map 15.2: Sum dollar-residual by county...\n")

map2 <- build_residual_map(
    counties_joined,
    fill_col     = "Sum_Dollar_Residual",
    title        = "Uncaptured Latent Value: Total Dollar Residuals by County",
    subtitle     = paste0(
        "Σ (Actual OC − Predicted OC) per county  │  ",
        "Red = model under-predicts (latent value)  │  Blue = model over-predicts  │  ",
        "Signed √ scale (compresses outliers)"
    ),
    caption_text = paste0(
        "Dollar residual = (final_acreage − exp(Predicted log-acreage)) × Baseline_Value_Per_Acre. ",
        "Fill uses signed square-root compression: color encodes direction, ",
        "intensity encodes magnitude.\n",
        "Pooled mean of per-imputation county sums across M = 100 MICE imputations. ",
        "Sources: OpenStreetMap; FHFA/USDA land values. ",
        "CRS: NAD83 / Conus Albers (EPSG 5070). Alaska and Hawaii shown as insets."
    ),
    map_type = "dollar"
)
ggsave(OUT_PNG2, map2, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG2)))


cat("\n")
cat(strrep("=", 70), "\n")
cat("[DONE] Phase 6 - Map 15: Both residual maps written.\n\n")
