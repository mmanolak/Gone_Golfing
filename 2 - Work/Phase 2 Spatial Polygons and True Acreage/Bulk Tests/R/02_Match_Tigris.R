# Purpose: Tigris area-landmarks fallback for courses that had no OSM polygon
#          match; nearest-neighbour within 500 m using Census golf boundaries.
# Inputs:  Bulk Tests/R/R_Acreage_Step1_OSM.csv
# Outputs: Bulk Tests/R/R_Acreage_Step2_Tigris.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(wooldridge)
  library(tidyverse)
  library(sf)
  library(tigris)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

options(tigris_use_cache = TRUE)

SCRIPT_DIR <- this.path::this.dir()
STEP1_CSV  <- file.path(SCRIPT_DIR, "R_Acreage_Step1_OSM.csv")
OUT_CSV    <- file.path(SCRIPT_DIR, "R_Acreage_Step2_Tigris.csv")

TARGET_CRS    <- 5070
MAX_DIST_M    <- 500
MIN_ACRES     <- 5
MAX_ACRES     <- 1500
SQ_M_PER_ACRE <- 4046.8564224

ALL_STATES <- c(
  "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN",
  "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH",
  "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT",
  "VT", "VA", "WA", "WV", "WI", "WY"
)


# === 3. FUNCTIONS ===

print_separator <- function(char = "=") {
  cat(paste(rep(char, 80), collapse = ""), "\n")
}


# === 4. EXECUTION ===

if (!file.exists(STEP1_CSV)) stop(paste("Input file not found:", STEP1_CSV))

print_separator()
cat("Phase 2: Tigris Landmarks Fallback\n")
cat("Script: 02_Match_Tigris.R\n")
print_separator()


cat("\n[Step 1] Loading Step 1 OSM output\n")

courses_df   <- read_csv(STEP1_CSV, show_col_types = FALSE)
missing_mask <- is.na(courses_df$acreage_source)
cat(sprintf("  Loaded %s courses\n", formatC(nrow(courses_df), big.mark = ",")))
cat(sprintf("  Courses needing fallback: %s (%.1f%%)\n",
            formatC(sum(missing_mask), big.mark = ","), 100 * mean(missing_mask)))

if (sum(missing_mask) == 0) {
  cat("  All courses already have acreage. Writing unchanged file.\n")
  write_csv(courses_df, OUT_CSV)
  cat(sprintf("  [OK] Saved -> %s\n", OUT_CSV))
  stop("Nothing to do — exiting cleanly.", call. = FALSE)
}


cat(sprintf("\n[Step 2] Downloading Tigris area landmarks (%d states)\n", length(ALL_STATES)))
cat("  Cached files reused after first run.\n\n")

landmark_list <- vector("list", length(ALL_STATES))

for (i in seq_along(ALL_STATES)) {
  st_abbr <- ALL_STATES[i]
  tryCatch(
    {
      lm <- landmarks(st_abbr, type = "area", progress_bar = FALSE) |>
        filter(str_detect(FULLNAME, "(?i)Golf|Country Club"))
      landmark_list[[i]] <- lm
      cat(sprintf("    %s: %d golf polygons\n", st_abbr, nrow(lm)))
    },
    error = function(e) {
      cat(sprintf("    %s: skipped (%s)\n", st_abbr, conditionMessage(e)))
    }
  )
}

tigris_golf_sf <- bind_rows(landmark_list)
cat(sprintf("  Total golf polygons from Tigris: %s\n",
            formatC(nrow(tigris_golf_sf), big.mark = ",")))

if (nrow(tigris_golf_sf) == 0) {
  stop("No golf area landmarks downloaded — check internet / tigris version.")
}

tigris_golf_sf <- tigris_golf_sf |>
  st_transform(TARGET_CRS) |>  # [METHODOLOGY] EPSG:5070 — equal-area CRS for distance accuracy
  mutate(tigris_acreage = as.numeric(st_area(geometry)) / SQ_M_PER_ACRE) |>  # [METHODOLOGY]
  filter(tigris_acreage >= MIN_ACRES, tigris_acreage <= MAX_ACRES)

cat(sprintf("  After plausibility filter (%.0f-%.0f acres): %s polygons remain\n",
            MIN_ACRES, MAX_ACRES, formatC(nrow(tigris_golf_sf), big.mark = ",")))


cat(sprintf("\n[Step 3] Nearest-neighbour match (max %d m)\n", MAX_DIST_M))

miss_sf <- st_as_sf(  # [METHODOLOGY]
  courses_df[missing_mask, ],
  coords = c("Longitude", "Latitude"),
  crs    = 4326,
  remove = FALSE
) |> st_transform(TARGET_CRS)

nearest <- st_join(  # [METHODOLOGY] nearest-feature fallback for unmatched courses
  miss_sf,
  tigris_golf_sf |> select(tigris_acreage),
  join = st_nearest_feature
)

dists <- as.numeric(st_distance(
  miss_sf,
  tigris_golf_sf[st_nearest_feature(miss_sf, tigris_golf_sf), ],
  by_element = TRUE
))
nearest$tigris_acreage[dists > MAX_DIST_M] <- NA

n_recovered <- sum(!is.na(nearest$tigris_acreage))
cat(sprintf("  Recovered via Tigris nearest-neighbor: %s\n",
            formatC(n_recovered, big.mark = ",")))


cat("\n[Step 4] Patching Tigris acreage back into master frame\n")

courses_df$tigris_acreage <- NA_real_
miss_idx <- which(missing_mask)
courses_df$tigris_acreage[miss_idx] <- nearest$tigris_acreage
courses_df$acreage_source[miss_idx[!is.na(nearest$tigris_acreage)]] <- "Tigris"


print_separator()
cat("SUMMARY - Tigris Fallback Results\n")
print_separator()

osm_n    <- sum(courses_df$acreage_source == "OSM",    na.rm = TRUE)
tig_n    <- sum(courses_df$acreage_source == "Tigris", na.rm = TRUE)
still_na <- sum(is.na(courses_df$acreage_source))

cat(sprintf("\n  OSM matches (Step 1):       %s (%.1f%%)\n",
            formatC(osm_n, big.mark = ","), 100 * osm_n / nrow(courses_df)))
cat(sprintf("  New Tigris matches:         %s (%.1f%%)\n",
            formatC(tig_n, big.mark = ","), 100 * tig_n / nrow(courses_df)))
cat(sprintf("  Still unmatched (MICE):     %s (%.1f%%)\n",
            formatC(still_na, big.mark = ","), 100 * still_na / nrow(courses_df)))

if (tig_n > 0) {
  ac <- courses_df$tigris_acreage[!is.na(courses_df$tigris_acreage)]
  cat("\n  Tigris acreage (matched only):\n")
  cat(sprintf("    Min:    %.1f acres\n", min(ac)))
  cat(sprintf("    Median: %.1f acres\n", median(ac)))
  cat(sprintf("    Mean:   %.1f acres\n", mean(ac)))
  cat(sprintf("    Max:    %.1f acres\n", max(ac)))
}


write_csv(courses_df, OUT_CSV)
cat(sprintf("\n  [OK] Saved -> %s\n", OUT_CSV))
print_separator()
cat("[Complete] 02_Match_Tigris.R finished.\n")
