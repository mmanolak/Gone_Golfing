# Purpose: Diagnostic merge of Step 2 TMKs against the Honolulu cadastral CSV
#          to verify TMK format compatibility before Step 5 geographic analysis.
# Inputs:  Bulk Tests/R/Target_Golf_Parcels_List.csv             (Step 2 output)
#          00 - Data Sources/Honolulu/All_Parcels_-4613852522541990741.csv
#          00 - Data Sources/Honolulu/Cadastral_2020_8454252231025374231.csv
# Outputs: (console diagnostic output only)


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

TAX_CSV_CANDIDATES <- c(
    file.path(HONOLULU_DATA_DIR, "All_Parcels_-4613852522541990741.csv"),
    file.path(HONOLULU_DATA_DIR, "Cadastral_2020_8454252231025374231.csv")
)


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

cat("\n======================================================================\n")
cat("Phase 5b - Step 4: Tax Assessment Merge (Diagnostic)\n")
cat("======================================================================\n\n")

if (!file.exists(TMK_LIST_PATH)) {
    stop(sprintf("[FATAL] TMK list not found. Run Step 2 first.\n  %s", TMK_LIST_PATH))
}

tmk_df <- read_csv(TMK_LIST_PATH, show_col_types = FALSE)
names(tmk_df)[1] <- "TMK"
tmk_df$TMK_clean <- str_remove_all(as.character(tmk_df$TMK), "[^0-9]")

tax_file_to_use <- Filter(file.exists, TAX_CSV_CANDIDATES)[1]
if (is.na(tax_file_to_use)) {
    stop(sprintf(
        "[FATAL] No Honolulu cadastral CSV found. Expected:\n  %s",
        paste(TAX_CSV_CANDIDATES, collapse = "\n  ")
    ))
}
tax_data <- read_csv(tax_file_to_use, show_col_types = FALSE, guess_max = 1000)

cat("--- DIAGNOSTIC INFO ---\n")
cat("All Columns in Honolulu CSV:\n")
print(names(tax_data))

tmk_col <- grep(
    "(?i)^tmk$|parcel_id|tax_map_key|pin",
    names(tax_data),
    value = TRUE
)[1]
tax_data$TMK_clean <- str_remove_all(
    as.character(tax_data[[tmk_col]]),
    "[^0-9]"
)

cat("\nFirst 5 TMKs from Step 2 (Target Golf Courses):\n")
print(head(tmk_df$TMK_clean, 5))

cat("\nFirst 5 TMKs from Honolulu CSV:\n")
print(head(tax_data$TMK_clean, 5))
cat("-----------------------\n\n")

# [REVIEW NEEDED] auto-fix logic has a likely parenthesis error on the else-if branch:
#   `all(nchar(tmk_df$TMK_clean)) == 9` should be `all(nchar(tmk_df$TMK_clean) == 9)` —
#   behavior may differ; flagged for review before production use
if (all(nchar(tmk_df$TMK_clean) == 8) &&
    all(nchar(na.omit(tax_data$TMK_clean)) == 9)) {
    cat("[AUTO-FIX] Step 2 TMKs are missing the Oahu '1' prefix...\n")
    tmk_df$TMK_clean <- paste0("1", tmk_df$TMK_clean)
} else if (all(
    nchar(tmk_df$TMK_clean)
) == 9 && all(nchar(na.omit(tax_data$TMK_clean)) == 8)) {
    cat("[AUTO-FIX] CSV TMKs are missing the Oahu '1' prefix...\n")
    tax_data$TMK_clean <- paste0("1", tax_data$TMK_clean)
}

merged_data   <- tmk_df |> inner_join(tax_data, by = "TMK_clean")
matched_count <- nrow(merged_data)

cat(sprintf(
    "  Successfully matched %d out of %d TMKs (%.1f%%).\n",
    matched_count, nrow(tmk_df), (matched_count / nrow(tmk_df)) * 100
))

if (matched_count > 0) {
    cat("\n[SUCCESS] The TMKs are now matching! Please paste this output back to me so I can see the column names and write the final Step 5 script.\n")
} else {
    cat("\n[FAIL] Still 0 matches. Please paste this output back to me so I can analyze the TMK formats.\n")
}
