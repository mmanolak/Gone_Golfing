# Purpose: Generate two national choropleth maps showing golf course opportunity
#          cost by U.S. state:
#            1.1 — MICE-pooled estimate (M = 100 imputations, Rubin's Rules q_bar)
#            1.2 — Observed-acreage-only estimate (no imputation)
# Inputs:  Phase 3 Economic Merge and MICE Imputation/Data/R/R_Imputed_Dataset_{1..5}.csv
#          Phase 1 Parsing/Data/R/R_Phase1_Baseline_Golf_Valuation.csv
#          Phase 2 Spatial Polygons and True Acreage/Data/R/R_Phase2_Acreage_Matched_v2.csv
# Outputs: Bulk/R/output/1.1_National_Opportunity_Cost_Map.png
#          Bulk/R/output/1.2_National_Opportunity_Cost_Map_ObservedOnly.png


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
PHASE2_CSV    <- file.path(
    WORK_DIR, "Phase 2 Spatial Polygons and True Acreage", "Data", "R",
    "R_Phase2_Acreage_Matched_v2.csv"
)
PHASE3_DIR    <- file.path(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "R"
)
IMPUTED_PATHS <- file.path(PHASE3_DIR, paste0("R_Imputed_Dataset_", 1:100, ".csv"))
OUTPUT_DIR    <- file.path(SCRIPT_DIR, "output")
OUT_PNG1      <- file.path(OUTPUT_DIR, "1.1_National_Opportunity_Cost_Map.png")
OUT_PNG2      <- file.path(OUTPUT_DIR, "1.2_National_Opportunity_Cost_Map_ObservedOnly.png")

M                 <- 100L
TERRITORY_EXCLUDE <- c("AS", "GU", "MP", "PR", "VI", "UM")


# === 3. FUNCTIONS ===

# Render national state choropleth and return the ggplot object.
# Expects a column named `pooled_opp_cost` in states_joined (billions if /1e9).
build_state_map <- function(states_joined, subtitle, caption_text) {
    ggplot(states_joined) +
        geom_sf(
            aes(fill = pooled_opp_cost / 1e9),
            colour = "white",
            linewidth = 0.25
        ) +
        scale_fill_viridis_c(
            option = "magma",
            na.value = "#d4d4d4",
            name = "Opportunity Cost",
            labels = label_dollar(suffix = "B", accuracy = 1),
            guide = guide_colorbar(
                barwidth       = unit(21, "cm"),
                barheight      = unit(0.45, "cm"),
                title.position = "top",
                title.hjust    = 0.5,
                ticks.colour   = "white"
            )
        ) +
        labs(
            title    = "Golf Course Opportunity Cost by State",
            subtitle = subtitle,
            caption  = stringr::str_wrap(caption_text, width = 192)
        ) +
        theme_void(base_size = 12) +
        theme(
            plot.title = element_text(
                face = "bold", size = 18, hjust = 0.5, margin = margin(b = 5)
            ),
            plot.subtitle = element_text(
                size = 10, hjust = 0.5, colour = "#024731", margin = margin(b = 0)
            ),
            plot.caption = element_text(
                size = 10, colour = "#024731", hjust = 0, margin = margin(t = 6), lineheight = 0.9
            ),
            plot.caption.position = "plot",
            legend.position = "bottom",
            legend.title = element_text(size = 14, face = "bold"),
            legend.text = element_text(size = 12),
            plot.margin = margin(12, 24, 8, 24)
        )
}


# === 4. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Macro Map 1: National Opportunity Cost by State\n")
cat(strrep("=", 70), "\n\n")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# -- Guard inputs
for (f in c(PHASE1_CSV, PHASE2_CSV, IMPUTED_PATHS)) {
    if (!file.exists(f)) stop(sprintf("[FATAL] Input not found:\n  %s", f))
}


# ── Step 1: Build state lookup ────────────────────────────────────────────────

cat("[Step 1] Building state lookup from Phase 1 baseline...\n")
phase1_df    <- read_csv(PHASE1_CSV, show_col_types = FALSE)
state_lookup <- phase1_df |>
    select(Longitude, Latitude, State_Abbr) |>
    distinct()
cat(sprintf("  %d unique course coordinates loaded.\n", nrow(state_lookup)))


# ── Step 2: Pool opportunity costs across M imputations ───────────────────────
# [METHODOLOGY] Total_Opportunity_Cost = final_acreage * Baseline_Value_Per_Acre.
#               State totals summed within each imputed dataset, then averaged
#               across M = 100 datasets (Rubin's Rules q_bar at the state level).

cat(sprintf("\n[Step 2] Pooling opportunity cost across %d imputed datasets...\n", M))
state_total_list <- vector("list", M)

for (i in seq_len(M)) {
    imp_df <- read_csv(IMPUTED_PATHS[i], show_col_types = FALSE) |>
        mutate(total_opp_cost = final_acreage * Baseline_Value_Per_Acre) |>
        left_join(state_lookup, by = c("Longitude", "Latitude"))

    n_unmatched <- sum(is.na(imp_df$State_Abbr))
    if (n_unmatched > 0) {
        cat(sprintf(
            "  [WARNING] Dataset %d: %d rows with no state match (excluded).\n",
            i, n_unmatched
        ))
    }

    state_total_list[[i]] <- imp_df |>
        filter(!is.na(State_Abbr)) |>
        group_by(State_Abbr) |>
        summarise(
            total_opp_cost = sum(total_opp_cost, na.rm = TRUE),
            .groups = "drop"
        ) |>
        mutate(imputation = i)

    cat(sprintf(
        "  Imputation %d: %d states, national total $%.3fT\n",
        i, nrow(state_total_list[[i]]),
        sum(state_total_list[[i]]$total_opp_cost) / 1e12
    ))
}

pooled_state <- bind_rows(state_total_list) |>
    group_by(State_Abbr) |>
    summarise(
        pooled_opp_cost = mean(total_opp_cost, na.rm = TRUE),
        .groups = "drop"
    ) |>
    arrange(desc(pooled_opp_cost))

cat(sprintf(
    "\n  MICE pooled national total: $%.3fT across %d states\n",
    sum(pooled_state$pooled_opp_cost) / 1e12,
    nrow(pooled_state)
))

cat("\n  Top 10 states by opportunity cost:\n")
cat(sprintf("  %-6s  %s\n", "State", "Pooled Cost ($B)"))
cat(sprintf("  %s\n", strrep("-", 30)))
for (i in seq_len(min(10L, nrow(pooled_state)))) {
    cat(sprintf(
        "  %-6s  $%.2fB\n",
        pooled_state$State_Abbr[i],
        pooled_state$pooled_opp_cost[i] / 1e9
    ))
}


# ── Step 3: Download state boundaries (shared between both maps) ───────────────
# [METHODOLOGY] tigris::states(cb = TRUE) downloads the Census Bureau's cartographic
#               boundary file (1:500k). Territories are excluded. shift_geometry()
#               repositions Alaska and Hawaii as insets below the lower 48.

cat("\n[Step 3] Downloading state boundaries via tigris...\n")
states_sf <- tigris::states(cb = TRUE, progress_bar = FALSE) |>
    filter(!STUSPS %in% TERRITORY_EXCLUDE) |>
    shift_geometry() |>
    st_transform(5070)
cat(sprintf("  %d states loaded with AK/HI insets (EPSG 5070).\n", nrow(states_sf)))


# ── Step 4: Render + save Map 1.1 (MICE-pooled) ───────────────────────────────

cat("\n[Step 4] Rendering Map 1.1: MICE-pooled state map...\n")

states_mice <- states_sf |>
    left_join(pooled_state, by = c("STUSPS" = "State_Abbr"))

no_data <- states_mice |> filter(is.na(pooled_opp_cost)) |> pull(STUSPS)
if (length(no_data) > 0) {
    cat(sprintf(
        "  [INFO] No-data states (rendered gray): %s\n",
        paste(sort(no_data), collapse = ", ")
    ))
}

map1 <- build_state_map(
    states_mice,
    subtitle     = paste0(
        "Pooled estimate across 100 MICE imputations  —  ",
        "Opportunity Cost = OSM Acreage × Baseline Land Value per Acre"
    ),
    caption_text = paste0(
        "Sources: OpenStreetMap golf course polygons; FHFA residential land price index ",
        "(urban counties, RUCC 1–3);\nUSDA agricultural land values (rural counties, ",
        "RUCC 4–9). CRS: NAD83 / Conus Albers (EPSG 5070). Alaska and Hawaii shown as insets."
    )
)
ggsave(OUT_PNG1, map1, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG1)))


# ── Step 5: Compute observed-only state totals ────────────────────────────────
# [METHODOLOGY] Phase 2 records acreage_source for every course. Filtering to
#               acreage_source != "MICE_Target" retains only courses with a directly
#               measured OSM polygon area, eliminating all imputed contributions.
#               No pooling is required since there is only one observed value per course.

cat("\n[Step 5] Computing observed-only state totals from Phase 2...\n")

obs_state <- read_csv(PHASE2_CSV, show_col_types = FALSE) |>
    filter(acreage_source != "MICE_Target") |>
    mutate(opp_cost = final_acreage * Baseline_Value_Per_Acre) |>
    filter(!is.na(State_Abbr)) |>
    group_by(State_Abbr) |>
    summarise(
        pooled_opp_cost = sum(opp_cost, na.rm = TRUE),
        .groups = "drop"
    ) |>
    arrange(desc(pooled_opp_cost))

cat(sprintf(
    "  Observed-only national total: $%.3fT across %d states\n",
    sum(obs_state$pooled_opp_cost) / 1e12,
    nrow(obs_state)
))
cat(sprintf(
    "  Coverage vs. MICE-pooled: %.1f%%\n",
    sum(obs_state$pooled_opp_cost) / sum(pooled_state$pooled_opp_cost) * 100
))


# ── Step 6: Render + save Map 1.2 (Observed-only) ────────────────────────────

cat("\n[Step 6] Rendering Map 1.2: Observed-only state map...\n")

states_obs <- states_sf |>
    left_join(obs_state, by = c("STUSPS" = "State_Abbr"))

map2 <- build_state_map(
    states_obs,
    subtitle     = paste0(
        "Observed acreage only — no imputation  —  ",
        "Opportunity Cost = OSM Acreage × Baseline Land Value per Acre"
    ),
    caption_text = paste0(
        "Restricted to courses with directly measured OSM polygon acreage ",
        "(acreage_source ≠ MICE_Target). Courses lacking polygon coverage excluded.\n",
        "Sources: OpenStreetMap; FHFA residential land price index (urban); ",
        "USDA agricultural land values (rural). CRS: EPSG 5070. Alaska and Hawaii shown as insets."
    )
)
ggsave(OUT_PNG2, map2, width = 14, height = 9, dpi = 300, units = "in")
cat(sprintf("  Saved: output/%s\n", basename(OUT_PNG2)))


cat("\n")
cat(strrep("=", 70), "\n")
cat("[DONE] Phase 6 - Macro Map 1: Both state maps written.\n\n")
