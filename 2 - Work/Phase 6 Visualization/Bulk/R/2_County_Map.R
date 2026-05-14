# Purpose: Generate two national choropleth maps showing golf course opportunity
#          cost by U.S. county (log10 fill scale):
#            2.1 — MICE-pooled estimate (M = 100 imputations, Rubin's Rules q_bar)
#            2.2 — Observed-acreage-only estimate (no imputation)
# Inputs:  Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..5}.csv
#          Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv
#          Phase 2 Spatial Polygons and True Acreage/Data/R/R_Phase2_Acreage_Matched_v2.csv
# Outputs: Bulk/R/output/2.1_County_Opportunity_Cost_Map.png
#          Bulk/R/output/2.2_County_Opportunity_Cost_Map_ObservedOnly.png


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

SCRIPT_DIR        <- this.path::this.dir()
WORK_DIR          <- normalizePath(
    file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE
)
PHASE1_CSV        <- file.path(
    WORK_DIR, "Phase 1 Parsing", "Data", "R",
    "R_Phase1_Baseline_Golf_Valuation.csv"
)
PHASE2_CSV        <- file.path(
    WORK_DIR, "Phase 2 Spatial Polygons and True Acreage", "Data", "R",
    "R_Phase2_Acreage_Matched_v2.csv"
)
PHASE3_DIR        <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "R"
)
IMPUTED_PATHS     <- file.path(PHASE3_DIR, paste0("R_Imputed_Dataset_", 1:100, ".csv"))
OUTPUT_DIR        <- file.path(SCRIPT_DIR, "output")
OUT_PNG1          <- file.path(OUTPUT_DIR, "2.1_County_Opportunity_Cost_Map.png")
OUT_PNG2          <- file.path(OUTPUT_DIR, "2.2_County_Opportunity_Cost_Map_ObservedOnly.png")

M                 <- 100L
TERRITORY_STATEFP <- c("60", "66", "69", "72", "74", "78")


# === 3. FUNCTIONS ===

# Render national county choropleth (log10 fill) and return the ggplot object.
# Expects a column named `pooled_opp_cost` in counties_joined (millions if /1e6).
build_county_map <- function(counties_joined, subtitle, caption_text) {
ggplot(counties_joined) +
        geom_sf(
            aes(fill = pooled_opp_cost / 1e6),
            colour    = "white",
            linewidth = 0.08
        ) +
        scale_fill_viridis_c(
            option   = "magma",
            trans    = "log10",
            na.value = "#8f8f8f",
            name     = "Opportunity Cost",
            breaks   = c(1, 10, 100, 1000, 10000),
            labels   = c("$1M", "$10M", "$100M", "$1B", "$10B"),
            guide    = guide_colorbar(
                barwidth       = unit(21, "cm"),
                barheight      = unit(0.45, "cm"),
                title.position = "top",
                title.hjust    = 0.5,
                ticks.colour   = "white"
            )
        ) +
        labs(
            title    = "Golf Course Opportunity Cost by County",
            subtitle = subtitle,
            caption  = stringr::str_wrap(caption_text, width = 192)
        ) +
        theme_void(base_size = 12) +
        theme(
            plot.title      = element_text(
                face = "bold", size = 18, hjust = 0.5, margin = margin(b = 5)
            ),
            plot.subtitle   = element_text(
                size = 10, hjust = 0.5, colour = "#024731", margin = margin(b = 0)
            ),
            plot.caption    = element_text(
                size = 10, colour = "#024731", hjust = 0, margin = margin(t = 6), lineheight = 0.9
            ),
            plot.caption.position = "plot",
            legend.position = "bottom",
            legend.title    = element_text(size = 14, face = "bold"),
            legend.text     = element_text(size = 12),
            plot.margin     = margin(12, 24, 8, 24)
        )
}


# === 4. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Macro Map 2: County-Level Opportunity Cost\n")
cat(strrep("=", 70), "\n\n")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# -- Guard inputs
for (f in c(PHASE1_CSV, PHASE2_CSV, IMPUTED_PATHS)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}


# ── Step 1: Build county lookup ───────────────────────────────────────────────
# FIPS is zero-padded to 5 characters to match tigris GEOID format.

cat("[Step 1] Building county lookup from Phase 1 baseline...\n")
phase1_df     <- read_csv(PHASE1_CSV, show_col_types = FALSE)
county_lookup <- phase1_df |>
    select(Longitude, Latitude, FIPS, County_Name, State_Abbr) |>
    distinct() |>
    mutate(FIPS = sprintf("%05d", as.integer(FIPS)))
cat(sprintf("  %d unique course coordinates loaded.\n", nrow(county_lookup)))


# ── Step 2: Pool opportunity costs across M imputations ───────────────────────
# [METHODOLOGY] County totals summed within each imputed dataset, then averaged
#               across M = 100 datasets (Rubin's Rules q_bar at the county level).

cat(sprintf("\n[Step 2] Pooling opportunity cost across %d imputed datasets...\n", M))
county_total_list <- vector("list", M)

for (i in seq_len(M)) {
    imp_df <- read_csv(IMPUTED_PATHS[i], show_col_types = FALSE) |>
        mutate(total_opp_cost = final_acreage * Baseline_Value_Per_Acre) |>
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
            total_opp_cost = sum(total_opp_cost, na.rm = TRUE),
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
    ) |>
    arrange(desc(pooled_opp_cost))

cat(sprintf(
    "\n  MICE pooled national total: $%.3fT across %d counties\n",
    sum(pooled_county$pooled_opp_cost) / 1e12,
    nrow(pooled_county)
))

cat("\n  Top 10 counties by opportunity cost:\n")
cat(sprintf("  %-30s  %-6s  %s\n", "County", "State", "Pooled Cost ($B)"))
cat(sprintf("  %s\n", strrep("-", 52)))
for (i in seq_len(min(10L, nrow(pooled_county)))) {
    cat(sprintf(
        "  %-30s  %-6s  $%.2fB\n",
        pooled_county$County_Name[i],
        pooled_county$State_Abbr[i],
        pooled_county$pooled_opp_cost[i] / 1e9
    ))
}


# ── Step 3: Download county and state boundaries (shared between both maps) ────
# [METHODOLOGY] tigris::counties(cb = TRUE) downloads the 1:500k cartographic
#               boundary file. Territories are excluded by STATEFP code.
#               shift_geometry() repositions Alaska and Hawaii as insets.

cat("\n[Step 3] Downloading county boundaries via tigris...\n")
counties_sf <- tigris::counties(cb = TRUE, progress_bar = FALSE) |>
    filter(!STATEFP %in% TERRITORY_STATEFP) |>
    shift_geometry() |>
    st_transform(5070)
cat(sprintf("  %d counties loaded with AK/HI insets (EPSG 5070).\n", nrow(counties_sf)))


# ── Step 4: Render + save Map 2.1 (MICE-pooled) ───────────────────────────────

cat("\n[Step 4] Rendering Map 2.1: MICE-pooled county map...\n")

counties_mice <- counties_sf |>
    left_join(pooled_county, by = c("GEOID" = "FIPS"))

no_data_n <- sum(is.na(counties_mice$pooled_opp_cost))
cat(sprintf(
    "  %d counties with no course data (gray)  |  %d with data.\n",
    no_data_n, nrow(counties_mice) - no_data_n
))

map1 <- build_county_map(
    counties_mice,
    subtitle     = paste0(
        "Pooled estimate across 100 MICE imputations  —  ",
        "Opportunity Cost = OSM Acreage × Baseline Land Value per Acre  —  ",
        "Log₁₀ scale"
    ),
    caption_text = paste0(
        "Sources: OpenStreetMap golf course polygons; FHFA residential land price index ",
        "(urban counties, RUCC 1–3);\nUSDA agricultural land values (rural counties, ",
        "RUCC 4–9). CRS: NAD83 / Conus Albers (EPSG 5070). ",
        "Alaska and Hawaii shown as insets."
    )
)
ggsave(OUT_PNG1, map1, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG1)))


# ── Step 5: Compute observed-only county totals ───────────────────────────────
# [METHODOLOGY] Filtering Phase 2 to acreage_source != "MICE_Target" retains
#               only courses with directly measured OSM polygon acreage. County
#               totals are a simple sum — no pooling required.

cat("\n[Step 5] Computing observed-only county totals from Phase 2...\n")

obs_county <- read_csv(PHASE2_CSV, show_col_types = FALSE) |>
    filter(acreage_source != "MICE_Target") |>
    mutate(
        opp_cost = final_acreage * Baseline_Value_Per_Acre,
        FIPS     = sprintf("%05d", as.integer(FIPS))
    ) |>
    filter(!is.na(FIPS)) |>
    group_by(FIPS, County_Name, State_Abbr) |>
    summarise(
        pooled_opp_cost = sum(opp_cost, na.rm = TRUE),
        .groups = "drop"
    ) |>
    arrange(desc(pooled_opp_cost))

cat(sprintf(
    "  Observed-only national total: $%.3fT across %d counties\n",
    sum(obs_county$pooled_opp_cost) / 1e12,
    nrow(obs_county)
))
cat(sprintf(
    "  Coverage vs. MICE-pooled: %.1f%%\n",
    sum(obs_county$pooled_opp_cost) / sum(pooled_county$pooled_opp_cost) * 100
))


# ── Step 6: Render + save Map 2.2 (Observed-only) ────────────────────────────

cat("\n[Step 6] Rendering Map 2.2: Observed-only county map...\n")

counties_obs <- counties_sf |>
    left_join(obs_county, by = c("GEOID" = "FIPS"))

map2 <- build_county_map(
    counties_obs,
    subtitle     = paste0(
        "Observed acreage only — no imputation  —  ",
        "Opportunity Cost = OSM Acreage × Baseline Land Value per Acre  —  ",
        "Log₁₀ scale"
    ),
    caption_text = paste0(
        "Restricted to courses with directly measured OSM polygon acreage ",
        "(acreage_source ≠ MICE_Target). Courses lacking polygon coverage excluded.\n",
        "Sources: OpenStreetMap; FHFA residential land price index (urban); ",
        "USDA agricultural land values (rural). CRS: EPSG 5070. ",
        "Alaska and Hawaii shown as insets."
    )
)
ggsave(OUT_PNG2, map2, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG2)))


cat("\n")
cat(strrep("=", 70), "\n")
cat("[DONE] Phase 6 - Macro Map 2: Both county maps written.\n\n")
