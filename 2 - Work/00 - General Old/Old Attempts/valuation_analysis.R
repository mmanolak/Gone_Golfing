# 1. SETUP & LIBRARIES
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, sf, tigris, mice, janitor, readr, methods)

# Set working directory - AUTO DETECT or MANUAL
tryCatch(
    setwd("G:/Shared drives/School Stuff/Old Sessions/9 - Spring 2026/02 - Econ 699 (Golf Course)/2 - Work"),
    error = function(e) print("Working directory not changed (using current)")
)

print("--- Starting Valuation Analysis Script (LINT CLEANUP V9) ---")

# HELPER: LIST FILES TO DEBUG
print("Current Directory Contents:")
print(list.files(pattern = ".csv"))

# 2. DATA LOADING
print("--- Step 2: Data Loading ---")
tryCatch(
    {
        # Auto-detect Golf Master File
        possible_files <- c(
            "00 - Golf_Courses_Acreage_Combo.csv",
            "Golf_Courses_Acreage_Combo.csv",
            "Golf_Courses_With_Acreage_tigris.csv",
            "Golf_Courses_Final_Master.csv"
        )

        # Find first mismatch
        master_file <- NULL
        for (f in possible_files) {
            if (file.exists(f)) {
                master_file <- f
                break
            }
        }

        if (is.null(master_file)) {
            stop("CRITICAL: No Master Golf Course CSV found! Please check file names.")
        }

        print(paste("Using Master File:", master_file))

        df_golf <<- read_csv(master_file, show_col_types = FALSE) |>
            mutate(temp_id = row_number())

        # Check if 'final_acreage' exists, if not rename
        if (!"final_acreage" %in% names(df_golf)) {
            if ("final_acres" %in% names(df_golf)) {
                df_golf <<- df_golf |> rename(final_acreage = final_acres)
                print("Renamed 'final_acres' to 'final_acreage'")
            } else {
                stop("Master file missing 'final_acreage' column!")
            }
        }

        print(paste("Loaded Golf Courses:", nrow(df_golf)))

        range_fhfa <- c(
            "Land_Prices_Counties.csv",
            "Cleaned Data/FHFA Data/Land_Prices_Counties.csv"
        )
        fhfa_file <- range_fhfa[file.exists(range_fhfa)][1]
        df_fhfa <<- read_csv(fhfa_file, show_col_types = FALSE)
        print(paste("Loaded FHFA Data:", nrow(df_fhfa)))

        range_ag <- c(
            "Land_Prices_States.csv",
            "Cleaned Data/Ag Data/Land_Prices_States.csv"
        )
        ag_file <- range_ag[file.exists(range_ag)][1]
        df_ag <<- read_csv(ag_file, show_col_types = FALSE)
        print(paste("Loaded Agricultural Data:", nrow(df_ag)))

        mice_output <<- readRDS("MICE_Output_Object.rds")
        print(paste("Loaded MICE Object. Class:", class(mice_output)))
    },
    error = function(e) stop(paste("Data Loading Failed:", e$message))
)


# 3. SPATIAL ENRICHMENT: GENERATING FIPS CODES
# ---------------------------------------------------------
print("--- Step 3: FIPS Generation ---")
tryCatch(
    {
        # Explicitly cast Golf Coords to Numeric if they aren't
        df_golf <<- df_golf |>
            mutate(
                longitude = as.numeric(longitude),
                latitude = as.numeric(latitude)
            )

        sf_golf <- st_as_sf(
            df_golf,
            coords = c("longitude", "latitude"),
            crs = 4326,
            remove = FALSE
        )

        # Ensure tigris cache dir is writable or use temp
        options(tigris_use_cache = TRUE)

        sf_counties <- counties(
            state = NULL,
            cb = TRUE,
            class = "sf",
            progress_bar = FALSE
        ) |>
            st_transform(4326) |>
            select(GEOID, NAME, STATE_NAME = STATE_NAME)

        sf_golf_joined <- st_join(sf_golf, sf_counties, join = st_intersects)

        df_golf_fips <<- sf_golf_joined |>
            st_drop_geometry() |>
            rename(fips_code = GEOID, county_name = NAME)

        print(paste("FIPS Generated for", nrow(df_golf_fips), "courses"))
    },
    error = function(e) stop(paste("FIPS Generation Failed:", e$message))
)


# 4. RUCC DATA FETCHING AND MERGING
# ---------------------------------------------------------
print("--- Step 4: RUCC Fetching ---")
tryCatch(
    {
        # Try multiple mirrors
        rucc_urls <- c(
            "https://raw.githubusercontent.com/juliachristensen/ps239T-final-project/master/ruralurbancodes2013.csv"
        )
        rucc_file <- "USDA_RUCC_Codes_2013.csv"

        download_success <- FALSE
        if (!file.exists(rucc_file)) {
            tryCatch(
                {
                    download.file(rucc_urls[1], rucc_file, mode = "wb")
                    download_success <- TRUE
                    print("RUCC file downloaded (Mirror 1).")
                },
                error = function(e) print("Mirror 1 failed.")
            )
        } else {
            download_success <- TRUE
            print("RUCC file already exists.")
        }

        if (download_success && file.exists(rucc_file)) {
            df_rucc <- read_csv(rucc_file, show_col_types = FALSE) |> clean_names()

            # HEURISTIC COLUMN DETECTION
            # 1. Identify FIPS Col
            fips_candidates <- c("fips", "fips_code", "geo_id")
            fips_col <- names(df_rucc)[names(df_rucc) %in% fips_candidates][1]
            if (is.na(fips_col)) fips_col <- names(df_rucc)[1] # Fallback to 1st col

            # 2. Identify Code Col
            code_pattern <- "2013|rucc|code"
            code_col <- names(df_rucc)[grep(code_pattern, names(df_rucc), ignore.case = TRUE)][1]
            if (is.na(code_col)) code_col <- names(df_rucc)[2] # Fallback to 2nd col

            print(paste("Using RUCC Cols -> FIPS:", fips_col, " | Code:", code_col))

            df_rucc_clean <- df_rucc |>
                rename(fips = all_of(fips_col), rucc_code = all_of(code_col)) |>
                mutate(fips = sprintf("%05d", as.numeric(fips))) |>
                select(fips, rucc_code)

            df_enriched <<- df_golf_fips |>
                mutate(fips_code = as.character(fips_code)) |>
                left_join(df_rucc_clean, by = c("fips_code" = "fips")) |>
                mutate(county_type = case_when(
                    rucc_code <= 3 ~ "Urban",
                    rucc_code >= 4 ~ "Rural",
                    TRUE ~ "Unknown"
                ))

            print(table(df_enriched$county_type))
        } else {
            print("WARNING: RUCC Download Failed. Defaulting all to 'Urban'.")
            df_enriched <<- df_golf_fips |> mutate(county_type = "Urban")
        }

        write_csv(df_enriched, "Golf_Courses_Enriched_Master.csv")
    },
    error = function(e) {
        print(paste("RUCC Failed:", e$message))
        print("Continuing with default 'Urban' classification...")
        df_enriched <<- df_golf_fips |> mutate(county_type = "Urban")
    }
)


# 5. PREPARING VALUATION DATA
# ---------------------------------------------------------
print("--- Step 5: Price Data Prep ---")
tryCatch(
    {
        # CORRECTED: Clean FHFA Data using 'fips' column directly
        print(paste("FHFA Cols:", paste(names(df_fhfa), collapse = ", ")))

        df_fhfa_clean <<- df_fhfa |>
            filter(year == 2022) |>
            mutate(
                fips = as.numeric(sub("[^0-9]", "", as.character(fips)))
            ) |>
            filter(!is.na(fips)) |>
            mutate(fips_code = sprintf("%05d", fips)) |>
            select(fips_code, fhfa_price = land_val_std)

        df_ag_clean <<- df_ag |>
            filter(year == 2022) |>
            select(state_abbr, usda_price = land_val_std)

        # CHECK IF THEY EXIST
        if (!exists("df_fhfa_clean")) stop("df_fhfa_clean failed to create")
        if (!exists("df_ag_clean")) stop("df_ag_clean failed to create")

        print("Price Data Prepared.")
    },
    error = function(e) stop(paste("Price Data Prep Failed:", e$message))
)


# 6. MICE PROCESSING & VALUATION
# ---------------------------------------------------------
print("--- Step 6: MICE Processing (DEBUG) ---")
tryCatch(
    {
        if (!exists("df_enriched")) stop("df_enriched missing")
        if (!exists("mice_output")) stop("mice_output missing")

        df_long <- complete(mice_output, action = "long", include = FALSE) |>
            rename(imputed_acreage = acreage)

        print(paste("Extracted Long Data. Rows:", nrow(df_long)))

        # 1. Create IDs
        df_long_step1 <- df_long |> mutate(original_id = as.integer(.id))

        # 2. Join 1: Enriched Data (FIX: Removed 'state' to avoid duplication)
        print("Attempting Join 1 (Long + Enriched)...")

        if (!"original_id" %in% names(df_long_step1)) {
            stop("original_id missing in long data")
        }
        if (!"temp_id" %in% names(df_enriched)) {
            stop("temp_id missing in enriched sorted data")
        }

        df_long_joined1 <- df_long_step1 |>
            left_join(
                df_enriched |> select(temp_id, fips_code, county_type),
                by = c("original_id" = "temp_id")
            )
        print("Join 1 Successful.")

        # 3. Join 2: FHFA
        print("Attempting Join 2 (+ FHFA)...")
        if (!"fips_code" %in% names(df_long_joined1)) {
            stop("fips_code missing in joined data")
        }

        df_long_joined2 <- df_long_joined1 |>
            left_join(df_fhfa_clean, by = "fips_code")

        # 4. Join 3: USDA
        print("Attempting Join 3 (+ USDA)...")
        if (!"state" %in% names(df_long_joined2)) {
            stop("state column missing before USDA join!")
        }

        df_long_enriched <- df_long_joined2 |>
            left_join(df_ag_clean, by = c("state" = "state_abbr"))

        # 5. Valuation
        df_final_long <<- df_long_enriched |>
            mutate(
                price_per_acre = case_when(
                    county_type == "Urban" & !is.na(fhfa_price) ~ fhfa_price,
                    county_type == "Rural" & !is.na(usda_price) ~ usda_price,
                    !is.na(fhfa_price) ~ fhfa_price,
                    !is.na(usda_price) ~ usda_price,
                    TRUE ~ NA_real_
                ),
                estimated_land_value = imputed_acreage * price_per_acre,
                valuation_method = case_when(
                    county_type == "Urban" & !is.na(fhfa_price) ~ "Residential",
                    !is.na(fhfa_price) ~ "Residential (Fallback)",
                    TRUE ~ "Agricultural (USDA)"
                )
            )
        print("Valuation Calculated.")
    },
    error = function(e) stop(paste("MICE/Valuation Failed:", e$message))
)


# 7. AGGREGATION & SUMMARY TABLES
# ---------------------------------------------------------
print("--- Step 7: Aggregation ---")
tryCatch(
    {
        if (!exists("df_final_long")) {
            stop("df_final_long is missing! Step 6 failed.")
        }

        df_report <<- df_final_long |> filter(.imp == 1)

        total_value <- sum(df_report$estimated_land_value, na.rm = TRUE)
        val_formatted <- format(total_value, big.mark = ",")
        print(paste("Total Estimated National Value (Imp 1): $", val_formatted))

        table_state <- df_report |>
            group_by(state) |>
            summarise(
                Course_Count = n(),
                Total_Value = sum(estimated_land_value, na.rm = TRUE)
            ) |>
            arrange(desc(Total_Value))
        write_csv(table_state, "Summary_Value_By_State.csv")

        table_type <- df_report |>
            group_by(course_type) |>
            summarise(
                Count = n(),
                Total_Value = sum(estimated_land_value, na.rm = TRUE)
            )
        write_csv(table_type, "Summary_Value_By_Type.csv")

        print("Summaries Saved.")
    },
    error = function(e) stop(paste("Summary Generation Failed:", e$message))
)


# 8. POOLED REGRESSION ANALYSIS
# ---------------------------------------------------------
print("--- Step 8: Regression ---")
tryCatch(
    {
        imp_list <- split(df_final_long, df_final_long$.imp)
        fit_list <- lapply(imp_list, function(d) {
            lm(estimated_land_value / 1e6 ~ holes + course_type, data = d)
        })
        pooled_results <- pool(fit_list)
        print(summary(pooled_results))
        capture.output(
            summary(pooled_results),
            file = "Regression_Results_Pooled.txt"
        )
    },
    error = function(e) {
        print(paste("Regression Failed (Non-Critical):", e$message))
    }
)


# 9. VISUALIZATION: MAP
# ---------------------------------------------------------
print("--- Step 9: Mapping ---")
tryCatch(
    {
        if (!exists("df_report")) stop("df_report is missing! Step 7 failed.")

        # Prepare data
        county_vals <- df_report |>
            group_by(fips_code) |>
            summarise(total_value = sum(estimated_land_value, na.rm = TRUE))

        # Join and Transform
        # User requested "flat" dimensions for legibility -> EPSG:4326 (Lat/Lon)
        map_data <- sf_counties |>
            left_join(county_vals, by = c("GEOID" = "fips_code")) |>
            filter(!is.na(total_value)) |>
            st_transform(4326)

        # Create "Flat" Map with readable labels
        p <- ggplot(map_data) +
            geom_sf(aes(fill = total_value), color = "white", lwd = 0.05) +
            scale_fill_viridis_c(
                option = "magma",
                trans = "log10",
                direction = -1, # Reversed: Low=Light, High=Dark
                na.value = "grey95",
                name = "Total Land Value",
                labels = scales::label_dollar(scale_cut = scales::cut_short_scale())
            ) +
            labs(
                title = "Total Estimated Golf Course Land Value by County",
                subtitle = "Hybrid Valuation Model (Residential + Agricultural)",
                caption = "Source: FHFA, USDA, and Imputed Golf Course Acreage"
            ) +
            theme_minimal() +
            theme(
                legend.position = "right",
                axis.text = element_blank(),
                axis.ticks = element_blank(),
                panel.grid = element_blank()
            )

        ggsave(
            "Map_Land_Value_County.png",
            plot = p, width = 12, height = 7, bg = "white"
        )
        print("Map saved to 'Map_Land_Value_County.png'")
    },
    error = function(e) print(paste("Mapping Failed:", e$message))
)

print("--- Analysis Complete ---")
