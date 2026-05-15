# Purpose: Map OLS residuals (actual − predicted) at the county level to
#          diagnose spatial autocorrelation in the Phase 4 regression.
#            15.141 — Mean log-residual per county  (Grand Mean across R, Py, Jl)
#            15.241 — Sum dollar-residual per county (Grand Mean across R, Py, Jl)
# Inputs:  Phase 4 Econometric Modeling/Data/R/R_Regression_Results.csv
#          Phase 4 Econometric Modeling/Data/python/Py_Regression_Results.csv
#          Phase 4 Econometric Modeling/Data/Julia/Jl_Regression_Results.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..100}.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/python/Py_Imputed_Dataset_{1..100}.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/Julia/Jl_Imputed_Dataset_{1..100}.csv
#          Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv
# Outputs: Bulk/R/output/15.141_Log_Residual_Map_GrandMean.png
#          Bulk/R/output/15.241_Dollar_Residual_Map_GrandMean.png


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
PHASE3_DIR_R  <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "R"
)
PHASE3_DIR_PY <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "python"
)
PHASE3_DIR_JL <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "Julia"
)
REG_CSV_R  <- file.path(
    WORK_DIR, "Phase 4 Econometric Modeling", "Data", "R",
    "R_Regression_Results.csv"
)
REG_CSV_PY <- file.path(
    WORK_DIR, "Phase 4 Econometric Modeling", "Data", "python",
    "Py_Regression_Results.csv"
)
REG_CSV_JL <- file.path(
    WORK_DIR, "Phase 4 Econometric Modeling", "Data", "Julia",
    "Jl_Regression_Results.csv"
)
IMPUTED_PATHS_R  <- file.path(PHASE3_DIR_R,  paste0("R_Imputed_Dataset_",  1:100, ".csv"))
IMPUTED_PATHS_PY <- file.path(PHASE3_DIR_PY, paste0("Py_Imputed_Dataset_", 1:100, ".csv"))
IMPUTED_PATHS_JL <- file.path(PHASE3_DIR_JL, paste0("Jl_Imputed_Dataset_", 1:100, ".csv"))
OUTPUT_DIR    <- file.path(SCRIPT_DIR, "output")
OUT_PNG1      <- file.path(OUTPUT_DIR, "15.141_Log_Residual_Map_GrandMean.png")
OUT_PNG2      <- file.path(OUTPUT_DIR, "15.241_Dollar_Residual_Map_GrandMean.png")

M                 <- 100L
TERRITORY_STATEFP <- c("60", "66", "69", "72", "74", "78")


# === 3. FUNCTIONS ===

get_acreage <- function(df) {
    if ("osm_acreage" %in% names(df)) df[["osm_acreage"]] else df[["final_acreage"]]
}

# Pool county-level OLS residuals for one language group across M = 100 imputations.
#
# FIPS resolution: R Phase 3 imputed files carry no FIPS column. Python and Julia
# Phase 3 imputed files do carry FIPS, but in variable formats. To guarantee
# consistent 5-digit FIPS codes and County_Name / State_Abbr for grouping across
# all three language groups, any native FIPS / county columns are dropped before
# the left-join against the Phase 1 county lookup (keyed on Longitude / Latitude).
pool_lang_residuals <- function(paths, b0, b_holes, b_urban,
                                    county_lookup, lang_label) {
    n <- length(paths)
    resid_list <- vector("list", n)
    cat(sprintf("  [%s] Pooling %d imputations...\n", lang_label, n))

    for (i in seq_len(n)) {
        df <- read_csv(paths[i], show_col_types = FALSE) |>
            select(-any_of(c("FIPS", "County_Name", "State_Abbr", "Tigris_State_Abbr"))) |>
            # [METHODOLOGY] Re-resolve FIPS for all language groups via Phase 1 lookup
            #               keyed on Longitude/Latitude. R imputed files have no FIPS
            #               column; Py/Jl native FIPS is dropped above to guarantee
            #               consistent 5-digit formatting from the lookup.
            left_join(county_lookup, by = c("Longitude", "Latitude")) |>
            filter(
                !is.na(FIPS),
                !is.na(Holes),
                !is.na(Baseline_Value_Per_Acre)
            ) |>
            mutate(
                acreage       = get_acreage(pick(everything())),
                Holes         = as.numeric(Holes),
                is_urban      = as.integer(!is.na(county_type) & county_type == "Urban"),
                predicted_log = b0 + b_holes * Holes + b_urban * is_urban
            ) |>
            # Guard against log-linear model explosion for extreme Holes outliers.
            # Phase 1 contains a 252-hole aggregate record; exp(b_holes * 252) ≈ $3.7T
            # per course, which dominates county sums. 72 holes = 4 × 18H, the largest
            # legitimate multi-course complex in the dataset (24 records).
            filter(acreage > 1, between(Holes, 9, 72)) |>
            mutate(
                # [METHODOLOGY] Dependent variable is log(Opportunity_Cost).
                #               Residual = log(acreage * BVPA) - predicted_log.
                #               Dollar residual: both terms in dollars.
                log_residual = log(acreage * Baseline_Value_Per_Acre) - predicted_log,
                dollar_resid = (acreage * Baseline_Value_Per_Acre) - exp(predicted_log)
            )

        resid_list[[i]] <- df |>
            group_by(FIPS, County_Name, State_Abbr) |>
            summarise(
                mean_log_residual   = mean(log_residual, na.rm = TRUE),
                sum_dollar_residual = sum(dollar_resid,  na.rm = TRUE),
                .groups = "drop"
            ) |>
            mutate(imputation = i)

        rm(df)
        gc()
    }

    # [METHODOLOGY] Rubin's Rules q_bar: mean of per-imputation county-level
    #               residuals across M = 100 imputations for this language group.
    bind_rows(resid_list) |>
        group_by(FIPS, County_Name, State_Abbr) |>
        summarise(
            Mean_Log_Residual   = mean(mean_log_residual,   na.rm = TRUE),
            Sum_Dollar_Residual = mean(sum_dollar_residual, na.rm = TRUE),
            .groups = "drop"
        )
}


# Render a diverging county choropleth. map_type = "log" uses the raw
# Mean_Log_Residual; map_type = "dollar" applies a signed square-root
# compression to handle the fat-tailed dollar distribution (LA, NYC outliers).
build_residual_map <- function(counties_joined, fill_col, title, subtitle,
                                caption_text, map_type = c("log", "dollar")) {
    map_type <- match.arg(map_type)

    if (map_type == "log") {
        lim <- max(abs(counties_joined[[fill_col]]), na.rm = TRUE)

        fill_scale <- scale_fill_gradient2(
            low      = "#4575b4",
            mid      = "white",
            high     = "#d73027",
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

        sqrt_breaks   <- pretty(c(-lim, lim), n = 6)
        dollar_labels <- sapply(sqrt_breaks, function(s) {
            d <- sign(s) * s^2 * 1e6
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
                size = 10, hjust = 0.5, colour = "#024731", margin = margin(b = 12)
            ),
            plot.caption  = element_text(
                size = 7, colour = "#024731", hjust = 0, margin = margin(t = 12)
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
cat("Phase 6 - Map 15: OLS Residual Maps (Log + Dollar — Grand Mean)\n")
cat(strrep("=", 70), "\n\n")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

for (f in c(PHASE1_CSV, REG_CSV_R, REG_CSV_PY, REG_CSV_JL)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}
for (f in c(IMPUTED_PATHS_R[c(1L, 100L)], IMPUTED_PATHS_PY[c(1L, 100L)],
            IMPUTED_PATHS_JL[c(1L, 100L)])) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}


# ── Step 1: Load regression coefficients for all three languages ───────────────

cat("[Step 1] Loading Phase 4 regression coefficients (R, Py, Jl)...\n")

reg_r  <- read_csv(REG_CSV_R,  show_col_types = FALSE)
reg_py <- read_csv(REG_CSV_PY, show_col_types = FALSE)
reg_jl <- read_csv(REG_CSV_JL, show_col_types = FALSE)

get_coef <- function(reg_df, param) reg_df$Coef[reg_df$Parameter == param]

b0_r  <- get_coef(reg_r,  "(Intercept)")
b0_py <- get_coef(reg_py, "Intercept")
b0_jl <- get_coef(reg_jl, "(Intercept)")

b_holes_r  <- get_coef(reg_r,  "Holes")
b_holes_py <- get_coef(reg_py, "Holes")
b_holes_jl <- get_coef(reg_jl, "Holes")

b_urban_r  <- get_coef(reg_r,  "factor(county_type)Urban")
b_urban_py <- get_coef(reg_py, "C(county_type)[T.Urban]")
b_urban_jl <- get_coef(reg_jl, "county_type: Urban")

cat(sprintf("  R:  b0=%.5f  b_holes=%.5f  b_urban=%.5f\n", b0_r,  b_holes_r,  b_urban_r))
cat(sprintf("  Py: b0=%.5f  b_holes=%.5f  b_urban=%.5f\n", b0_py, b_holes_py, b_urban_py))
cat(sprintf("  Jl: b0=%.5f  b_holes=%.5f  b_urban=%.5f\n", b0_jl, b_holes_jl, b_urban_jl))


# ── Step 2: Build county FIPS lookup from Phase 1 ─────────────────────────────
# [METHODOLOGY] Used inside pool_lang_residuals() to assign FIPS, County_Name,
#               and State_Abbr to all three language groups via Longitude/Latitude
#               join. Courses with FIPS = NA in Phase 1 remain NA after the join
#               and are excluded from county aggregation.

cat("\n[Step 2] Building county FIPS lookup from Phase 1...\n")
phase1_df     <- read_csv(PHASE1_CSV, show_col_types = FALSE)
county_lookup <- phase1_df |>
    select(Longitude, Latitude, FIPS, County_Name, State_Abbr) |>
    distinct(Longitude, Latitude, .keep_all = TRUE) |>
    mutate(FIPS = if_else(!is.na(FIPS), sprintf("%05d", as.integer(FIPS)), NA_character_))
cat(sprintf("  %d unique course coordinates loaded.\n", nrow(county_lookup)))
cat(sprintf("  %d coordinates with FIPS = NA (will be excluded from county aggregation).\n",
    sum(is.na(county_lookup$FIPS))))


# ── Step 3: Pool residuals per language, compute Grand Mean ───────────────────
# [METHODOLOGY] Rubin's Rules applied independently per language group (M = 100).
#               Grand Mean = arithmetic mean of three language-specific pooled estimates.

cat(sprintf("\n[Step 3] Pooling residuals across M = %d imputations per language...\n", M))

pooled_r  <- pool_lang_residuals(IMPUTED_PATHS_R,  b0_r,  b_holes_r,  b_urban_r,
                                    county_lookup, "R")
pooled_py <- pool_lang_residuals(IMPUTED_PATHS_PY, b0_py, b_holes_py, b_urban_py,
                                    county_lookup, "Py")
pooled_jl <- pool_lang_residuals(IMPUTED_PATHS_JL, b0_jl, b_holes_jl, b_urban_jl,
                                    county_lookup, "Jl")

grand_mean_resid <- bind_rows(
    pooled_r  |> mutate(lang = "R"),
    pooled_py |> mutate(lang = "Py"),
    pooled_jl |> mutate(lang = "Jl")
) |>
    group_by(FIPS, County_Name, State_Abbr) |>
    summarise(
        Mean_Log_Residual   = mean(Mean_Log_Residual,   na.rm = TRUE),
        Sum_Dollar_Residual = mean(Sum_Dollar_Residual, na.rm = TRUE),
        .groups = "drop"
    )

cat(sprintf("\n  Grand Mean residuals pooled: %d counties\n", nrow(grand_mean_resid)))
cat(sprintf(
    "  Log-residual range:    [%.3f, %.3f]  (0 = perfect fit)\n",
    min(grand_mean_resid$Mean_Log_Residual,   na.rm = TRUE),
    max(grand_mean_resid$Mean_Log_Residual,   na.rm = TRUE)
))
cat(sprintf(
    "  Dollar-residual range: [$%.2fB, $%.2fB]\n",
    min(grand_mean_resid$Sum_Dollar_Residual, na.rm = TRUE) / 1e9,
    max(grand_mean_resid$Sum_Dollar_Residual, na.rm = TRUE) / 1e9
))


# ── Step 4: Download county boundaries ────────────────────────────────────────

cat("\n[Step 4] Downloading county boundaries via tigris...\n")
# [METHODOLOGY] CRS transform to NAD83 / Conus Albers (EPSG 5070) for equal-area display.
counties_sf <- tigris::counties(cb = TRUE, progress_bar = FALSE) |>
    filter(!STATEFP %in% TERRITORY_STATEFP) |>
    shift_geometry() |>
    st_transform(5070)
cat(sprintf("  %d counties loaded with AK/HI insets (EPSG 5070).\n", nrow(counties_sf)))

counties_joined <- counties_sf |>
    left_join(grand_mean_resid, by = c("GEOID" = "FIPS"))

no_data_n <- sum(is.na(counties_joined$Mean_Log_Residual))
cat(sprintf(
    "  %d counties with no course data (gray)  |  %d with residuals.\n",
    no_data_n, nrow(counties_joined) - no_data_n
))


# ── Step 5: Render + save Map 15.141 (Log-Residual) ───────────────────────────

cat("\n[Step 5] Rendering Map 15.141: Mean log-residual by county...\n")

map1 <- build_residual_map(
    counties_joined,
    fill_col     = "Mean_Log_Residual",
    title        = "OLS Spatial Diagnostics: Mean Log-Residuals by County",
    subtitle     = paste0(
        "log(Actual OC) − log(Predicted OC) per county  │  ",
        "Red = county OC exceeds prediction (model underpredicts)  │  ",
        "Blue = county OC falls short of prediction (model overpredicts)  │  ",
        "Grand Mean of three Rubin-pooled estimates (Python · R · Julia, M = 100 each)"
    ),
    caption_text = paste0(
        "OLS model: log(Opportunity_Cost) = β₀ + β₁·Holes + β₂·I(Urban). ",
        "Each county’s value = mean of course-level log-residuals for courses in that county. ",
        "No systematic geographic pattern in residuals indicates the model is spatially unbiased. ",
        "Gray counties contain no golf courses in the Phase 1 dataset.\n",
        "Sources: OpenStreetMap golf course polygons; FHFA residential land price index (urban); ",
        "USDA agricultural land values (rural). ",
        "CRS: NAD83 / Conus Albers (EPSG 5070). Alaska and Hawaii shown as insets."
    ),
    map_type = "log"
)
ggsave(OUT_PNG1, map1, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG1)))


# ── Step 6: Render + save Map 15.241 (Dollar-Residual) ────────────────────────

cat("\n[Step 6] Rendering Map 15.241: Sum dollar-residual by county...\n")

map2 <- build_residual_map(
    counties_joined,
    fill_col     = "Sum_Dollar_Residual",
    title        = "Uncaptured Latent Value: Total Dollar Residuals by County",
    subtitle     = paste0(
        "Σ (Actual OC − Predicted OC) per county  │  ",
        "Red = county value exceeds prediction (undercaptured latent value)  │  ",
        "Blue = county value falls short of prediction  │  ",
        "Grand Mean of three Rubin-pooled estimates (Python · R · Julia, M = 100 each)  │  Signed √ scale"
    ),
    caption_text = paste0(
        "Dollar residual = (acreage × Baseline_Value_Per_Acre) − exp(Predicted_log_OC); both terms in dollars. ",
        "Fill uses signed square-root compression to handle the fat-tailed distribution: ",
        "color encodes direction, intensity encodes magnitude; legend tick labels back-transform to dollar values.\n",
        "Gray counties contain no golf courses. ",
        "Sources: OpenStreetMap; FHFA/USDA land values. ",
        "CRS: NAD83 / Conus Albers (EPSG 5070). Alaska and Hawaii shown as insets."
    ),
    map_type = "dollar"
)
ggsave(OUT_PNG2, map2, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG2)))


cat("\n")
cat(strrep("=", 70), "\n")
cat("[DONE] Phase 6 - Map 15: Both Grand Mean residual maps written.\n\n")
