# Purpose: Generate Magnitude Comparison Bar Chart.
#          Contextualises U.S. golf course land area against key benchmarks:
#          total U.S. utility-scale solar, Delaware + Rhode Island combined
#          land area, and a forward-looking NREL full-solar projection.
# Inputs:  None (hardcoded, confirmed values — see caption for citations).
# Outputs: output/16.141_Magnitude_Comparison_TriLanguage.png


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(tidyverse)
    library(scales)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
OUTPUT_DIR <- file.path(SCRIPT_DIR, "output")
OUT_PNG    <- file.path(OUTPUT_DIR, "16.141_Magnitude_Comparison_TriLanguage.png")


# === 3. FUNCTIONS ===

build_magnitude_chart <- function(out_path) {

    UHM_GREEN       <- "#024731"
    UHM_SILVER      <- "#B2B2B2"
    PROJECTION_GRAY <- "#D8D8D8"

    # Values confirmed 2026-05-18:
    #   Golf  — National_Acreage_Summary.csv (MICE-pooled, M = 100)
    #   Solar — EIA Preliminary Monthly Generator Inventory, Aug 2024
    #            (107.4 GW × 6 ac/MW per SEIA central land-use intensity)
    #   DE+RI — U.S. Census Bureau, 2010 Census, land area only
    #            (Delaware 1,247,040 ac + Rhode Island 661,690 ac)
    #   NREL  — PV Magazine USA, June 2024 (forward-looking 100% solar scenario)
    bars <- tibble(
        label = c(
            "U.S. Utility-Scale Solar\n(EIA, Aug 2024)",
            "Delaware + Rhode Island\n(U.S. Census 2010, land area)",
            "U.S. Golf Courses\n(This thesis, Phase 2 OSM)",
            "NREL Full-Solar Scenario\n(Forward-looking projection)"
        ),
        acres = c(644000L, 1908730L, 2300521L, 10000000L),
        type  = c("comparison", "comparison", "golf", "projection")
    ) |>
        mutate(
            label = fct_reorder(label, acres),
            fill  = case_when(
                type == "golf"       ~ UHM_GREEN,
                type == "projection" ~ PROJECTION_GRAY,
                TRUE                 ~ UHM_SILVER
            )
        )

    format_acres <- function(x) {
        case_when(
            x >= 1e6 ~ paste0(formatC(x / 1e6, digits = 1, format = "f"), "M ac"),
            TRUE     ~ paste0(round(x / 1e3), "K ac")
        )
    }

    golf_ac  <- 2300521L
    solar_ac <- 644000L
    deri_ac  <- 1908730L

    p <- ggplot(bars, aes(x = label, y = acres, fill = fill)) +
        geom_col(width = 0.65) +
        geom_text(
            aes(label = format_acres(acres)),
            hjust = -0.12,
            size  = 3.8,
            color = "gray25"
        ) +
        scale_fill_identity() +
        scale_y_continuous(
            breaks = c(0, 2e6, 4e6, 6e6, 8e6, 10e6),
            labels = c("0", "2", "4", "6", "8", "10"),
            expand = expansion(mult = c(0, 0.28))
        ) +
        coord_flip() +
        labs(
            title    = "U.S. Golf Course Land in Context",
            subtitle = paste0(
                sprintf(
                    "Golf footprint (%.2fM ac) is %.1f× total U.S. utility-scale solar",
                    golf_ac / 1e6, golf_ac / solar_ac
                ),
                sprintf(
                    " — and %.0f%% larger than Delaware + Rhode Island combined",
                    (golf_ac / deri_ac - 1) * 100
                )
            ),
            x       = NULL,
            y       = "Land Area (million acres)",
            caption = paste0(
                "Sources — Golf: this thesis, Phase 2 OSM aggregate ",
                "(MICE-pooled, M = 100; 2,300,521 ac). ",
                "Solar: EIA Preliminary Monthly Electric Generator Inventory, Aug 2024 ",
                "(107.4 GW × 6 ac/MW per SEIA central land-use intensity estimate). ",
                "DE + RI: U.S. Census Bureau, 2010 Census, land area only ",
                "(Delaware 1,247,040 ac + Rhode Island 661,690 ac). ",
                "NREL: as reported in PV Magazine USA, June 2024 ",
                "(forward-looking 100% solar electricity scenario; not a current deployment figure)."
            )
        ) +
        theme_minimal(base_size = 13) +
        theme(
            plot.title         = element_text(face = "bold", size = 16, color = UHM_GREEN),
            plot.subtitle      = element_text(
                size = 11, color = "gray30", margin = margin(b = 14)
            ),
            plot.caption       = element_text(
                size = 7.5, color = "gray50", hjust = 0, lineheight = 1.3,
                margin = margin(t = 10)
            ),
            plot.margin        = margin(t = 14, r = 20, b = 14, l = 14),
            axis.text.y        = element_text(size = 10, lineheight = 1.25, color = "gray20"),
            axis.text.x        = element_text(size = 9),
            axis.title.x       = element_text(size = 10, color = "gray40"),
            panel.grid.major.y = element_blank(),
            panel.grid.minor   = element_blank(),
            panel.grid.major.x = element_line(color = "gray90", linewidth = 0.4)
        )

    ggsave(out_path, p, width = 12, height = 5.5, dpi = 300, units = "in")
    invisible(p)
}


# === 4. EXECUTION ===

cat("\n")
cat(strrep("=", 70), "\n")
cat("Phase 6 - Script 16: Magnitude Comparison Bar Chart\n")
cat(strrep("=", 70), "\n\n")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

cat("[Chart] Building magnitude comparison chart...\n")
build_magnitude_chart(OUT_PNG)
cat(sprintf("  Saved: %s\n\n", basename(OUT_PNG)))

cat(strrep("=", 70), "\n")
cat("[DONE] Phase 6 - Script 16: Magnitude Comparison Chart written.\n\n")
