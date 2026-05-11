# Purpose: Merge Step 2 TMKs with the Honolulu cadastral CSV to extract TMK
#          zones and map each zone to its official Oahu geographic district.
# Inputs:  Bulk Tests/R/Target_Golf_Parcels_List.csv               (Step 2 output)
#          00 - Data Sources/Honolulu/All_Parcels_-4613852522541990741.csv
# Outputs: Bulk Tests/R/Phase5_Step5_Geographic_Breakdown.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
    library(tidyverse)
    library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR        <- this.path::this.dir()
WORK_DIR          <- normalizePath(
    file.path(SCRIPT_DIR, "..", "..", ".."), mustWork = FALSE
)
HONOLULU_DATA_DIR <- file.path(WORK_DIR, "00 - Data Sources", "Honolulu")
TMK_LIST_PATH     <- file.path(SCRIPT_DIR, "Target_Golf_Parcels_List.csv")
TAX_CSV_PATH      <- file.path(
    HONOLULU_DATA_DIR, "All_Parcels_-4613852522541990741.csv"
)
OUT_CSV           <- file.path(SCRIPT_DIR, "Phase5_Step5_Geographic_Breakdown.csv")


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

cat("\n======================================================================\n")
cat("Phase 5b - Step 5: Geographic Concentration Breakdown\n")
cat("======================================================================\n\n")

if (!file.exists(TMK_LIST_PATH)) {
    stop(sprintf("[FATAL] TMK list not found. Run Step 2 first.\n  %s", TMK_LIST_PATH))
}
if (!file.exists(TAX_CSV_PATH)) {
    stop(sprintf("[FATAL] Cadastral CSV not found:\n  %s", TAX_CSV_PATH))
}

tmk_df <- read_csv(TMK_LIST_PATH, show_col_types = FALSE)
names(tmk_df)[1] <- "TMK"
tmk_df$TMK_clean <- str_remove_all(as.character(tmk_df$TMK), "[^0-9]")

tax_data <- read_csv(TAX_CSV_PATH, show_col_types = FALSE)
tmk_col  <- grep("(?i)^tmk$", names(tax_data), value = TRUE)[1]
tax_data$TMK_clean <- str_remove_all(
    as.character(tax_data[[tmk_col]]),
    "[^0-9]"
)

merged_data <- tmk_df |> inner_join(tax_data, by = "TMK_clean")

# Map 2nd TMK digit to Oahu geographic district name
district_map <- c(
    "1" = "Honolulu (Urban Core)",
    "2" = "Honolulu (East/Anomalies)",
    "3" = "Honolulu (Anomalies)",
    "4" = "Koolaupoko (Kailua/Kaneohe)",
    "5" = "Koolauloa (North/East)",
    "6" = "Waialua (North Shore)",
    "7" = "Wahiawa (Central)",
    "8" = "Waianae (West)",
    "9" = "Ewa (Kapolei/Pearl City)"
)

merged_data <- merged_data |>
    mutate(
        Zone_Code    = as.character(Zone),
        District_Name = ifelse(
            Zone_Code %in% names(district_map),
            district_map[Zone_Code],
            paste("Zone", Zone_Code)
        )
    )

geo_summary <- merged_data |>
    group_by(Zone_Code, District_Name) |>
    summarise(Parcel_Count = n(), .groups = "drop") |>
    mutate(
        Pct_of_Total_Parcels = (Parcel_Count / sum(Parcel_Count)) * 100
    ) |>
    arrange(desc(Parcel_Count))

cat("----------------------------------------------------------------------\n")
cat(sprintf(
    "%-5s %-35s %-15s %-15s\n",
    "Zone", "Geographic District", "Parcel Count", "% of Parcels"
))
cat("----------------------------------------------------------------------\n")

for (i in seq_len(nrow(geo_summary))) {
    cat(sprintf(
        "%-5s %-35s %-15d %-15.1f%%\n",
        geo_summary$Zone_Code[i],
        geo_summary$District_Name[i],
        geo_summary$Parcel_Count[i],
        geo_summary$Pct_of_Total_Parcels[i]
    ))
}
cat("----------------------------------------------------------------------\n")
cat(sprintf(
    "%-5s %-35s %-15d %-15.1f%%\n",
    "", "TOTAL", sum(geo_summary$Parcel_Count), 100.0
))
cat("----------------------------------------------------------------------\n")

write_csv(geo_summary, OUT_CSV)
cat(sprintf(
    "\n[+] Geographic Breakdown saved -> %s\n",
    basename(OUT_CSV)
))
cat("\n[DONE] Step 5 Complete. Phase 5 is fully finished!\n")
