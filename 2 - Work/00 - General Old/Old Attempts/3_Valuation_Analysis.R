# 3_Valuation_Analysis.R
# Golf Course Land Valuation Analysis
# Author: Golf Course Valuation Project
# Date: 2026-02-16

# -----------------------------------------------------------------------------
# 1. Setup and Library Loading
# -----------------------------------------------------------------------------
library(tidyverse)
library(sf)
library(mice)
library(tigris)
library(readxl)
library(viridis)

options(tigris_use_cache = TRUE)

# Set Working Directory (Adjust as needed)
# setwd("g:/Shared drives/School Stuff/Old Sessions/9 - Spring 2026/02 - Econ 699 (Golf Course)/2 - Work")

# -----------------------------------------------------------------------------
# 2. Data Loading
# -----------------------------------------------------------------------------

# A. Master Golf Course List
# Using '00 - Golf_Courses_Acreage_Combo.csv' as the base for location data
master_file_path <- "00 - Golf_Courses_Acreage_Combo.csv"
if (!file.exists(master_file_path)) stop("Master file not found!")
golf_data <- read_csv(master_file_path, show_col_types = FALSE) %>%
    mutate(course_id = row_number()) # Ensure ID for joining

# B. MICE Imputed Acreage Data
mice_object_path <- "MICE_Output_Object.rds"
if (!file.exists(mice_object_path)) stop("MICE object not found!")
mice_output <- readRDS(mice_object_path)

# C. FHFA Residential Land Values (Urban Proxy)
fhfa_path <- "Land_Prices_Counties.csv" # Confirm file name
fhfa_data <- read_csv(fhfa_path, show_col_types = FALSE) %>%
    # Filter for most recent year avail (Assume 2022 based on file checks)
    filter(year == max(year)) %>%
    mutate(
        # Pad FIPS to 5 digits
        FIPS = str_pad(as.character(fips), 5, pad = "0"),
        FHFA_Price_Per_Acre = land_val_std # Adjust column name if needed
    ) %>%
    select(FIPS, FHFA_Price_Per_Acre)

# D. USDA Agricultural Land Values (Rural Proxy)
usda_path <- "USDA_Ag_State_2025.csv"
usda_data <- read_csv(usda_path, show_col_types = FALSE) %>%
    filter(measure_type == "Total Ag Land (Incl Buildings)") %>%
    mutate(USDA_Ag_Price = value_numeric) %>% # Use Total Ag
    select(state_abbr, USDA_Ag_Price)

# E. Rural-Urban Continuum Codes (RUCC)
# Note: If file missing, script will warn.
rucc_path <- "USDA_RUCC_Codes.csv"
if (file.exists(rucc_path)) {
    rucc_data <- read_csv(rucc_path, show_col_types = FALSE) %>%
        mutate(FIPS = str_pad(as.character(FIPS), 5, pad = "0")) %>%
        select(FIPS, RUCC_2013)
} else {
    warning("RUCC file not found. Urban/Rural classification may be limited.")
    rucc_data <- NULL
}

# -----------------------------------------------------------------------------
# 3. Spatial Join for FIPS Codes
# -----------------------------------------------------------------------------

# Convert Golf Data to SF object (WGS84)
golf_sf <- golf_data %>%
    filter(!is.na(longitude) & !is.na(latitude)) %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

# Get US Counties Shapefile
counties_sf <- counties(cb = TRUE, resolution = "20m", year = 2022) %>%
    select(GEOID, NAME) %>%
    st_transform(crs = st_crs(golf_sf))

# Perform Spatial Join
golf_joined <- st_join(golf_sf, counties_sf, join = st_within) %>%
    mutate(county_fips = GEOID) %>%
    st_drop_geometry() # Drop geometry for data manipulation

# Merge back to Master
golf_master <- golf_data %>%
    left_join(golf_joined %>% select(course_id, county_fips), by = "course_id")

# -----------------------------------------------------------------------------
# 4. Hybrid Valuation Logic
# -----------------------------------------------------------------------------

apply_valuation <- function(df, fhfa, usda, rucc) {
    # Join supporting data
    df_joined <- df %>%
        left_join(fhfa, by = c("county_fips" = "FIPS")) %>%
        left_join(usda, by = c("state" = "state_abbr"))

    if (!is.null(rucc)) {
        df_joined <- df_joined %>% left_join(rucc, by = c("county_fips" = "FIPS"))
    } else {
        df_joined$RUCC_2013 <- NA # Placeholder if missing
    }

    # Logic
    # Urban: RUCC 1, 2, 3
    # Rural: RUCC 4-9
    # If RUCC missing (or file missing), default to Rural if FHFA missing?
    # Better fallback: If FHFA exists, use it (Urban assumption). If not, USDA (Rural assumption).

    df_final <- df_joined %>%
        mutate(
            county_type = case_when(
                RUCC_2013 %in% 1:3 ~ "Urban",
                RUCC_2013 %in% 4:9 ~ "Rural",
                TRUE ~ "Unknown"
            ),
            Estimated_Price_Per_Acre = case_when(
                # Urban Case: Prefer FHFA
                county_type == "Urban" & !is.na(FHFA_Price_Per_Acre) ~ FHFA_Price_Per_Acre,
                # Rural Case: Prefer USDA
                county_type == "Rural" ~ USDA_Ag_Price,
                # Fallback 1: Urban but no FHFA -> USDA
                county_type == "Urban" & is.na(FHFA_Price_Per_Acre) ~ USDA_Ag_Price,
                # Fallback 2: Unknown Type -> Try FHFA first, then USDA
                !is.na(FHFA_Price_Per_Acre) ~ FHFA_Price_Per_Acre,
                TRUE ~ USDA_Ag_Price
            ),
            estimated_land_value = final_acreage * Estimated_Price_Per_Acre
        )

    return(df_final)
}

# -----------------------------------------------------------------------------
# 5. Analysis & Pooling (MICE)
# -----------------------------------------------------------------------------

# A. Pooling for Regression
# We need to run the analysis on EACH of the 5 imputed datasets
# Then pool the results.

# Extract completed datasets
imputed_datasets <- lapply(1:5, function(i) complete(mice_output, i))

# Run process for each
models <- list()
results_list <- list()

for (i in 1:5) {
    # Get dataset
    data_i <- imputed_datasets[[i]]

    # Ensure ID or join key is present if 'complete' dropped it or if order is same
    # 'mice' preserves order, so we can bind columns if needed, but 'complete'
    # returns the full dataset used in mice.
    # We need to re-join the location/FIPS data since MICE likely only had predictors.
    # Assuming 'mice_output' was run on a dataframe that is row-aligned with 'golf_master'.

    # Add FIPS/State from master
    data_i_aug <- data_i %>%
        left_join(golf_master %>% select(course_id, county_fips), by = "course_id") %>%
        mutate(final_acreage = acreage)

    # Apply Valuation
    data_valued <- apply_valuation(data_i_aug, fhfa_data, usda_data, rucc_data)

    # Store for summary
    results_list[[i]] <- data_valued

    # Run Regression
    # Variable names as specified: estimated_land_value, holes, course_type
    # +1 added to avoid log(0) if any value is 0
    fit <- lm(log(estimated_land_value + 1) ~ holes + course_type + county_type, data = data_valued)
    models[[i]] <- fit
}

# Pool Results using Rubin's Rules
pool_fit <- pool(models)
print("--- Pooled Regression Results ---")
print(summary(pool_fit))


# B. Summary Statistics (Using Imputation 1 as representative for tables)
final_data <- results_list[[1]]

# National Total
national_value <- sum(final_data$estimated_land_value, na.rm = TRUE)
print(paste("Total National Golf Course Land Value:", scales::dollar(national_value)))

# State Breakdown
state_summary <- final_data %>%
    group_by(state) %>%
    summarise(
        Total_Value = sum(estimated_land_value, na.rm = TRUE),
        Count = n()
    ) %>%
    arrange(desc(Total_Value))
print(head(state_summary))

# MSA Breakdown (Placeholder - Requires MSA delineation in Spatial Join)
# To do: Add MSA join in Step 3 if desired.

# -----------------------------------------------------------------------------
# 6. Visualization
# -----------------------------------------------------------------------------

# Visualize Imputation 1
plot_data <- final_data %>%
    group_by(county_fips) %>%
    summarise(County_Value = sum(estimated_land_value, na.rm = TRUE))

# Join with Geometry
plot_sf <- counties_sf %>%
    left_join(plot_data, by = c("GEOID" = "county_fips")) %>%
    st_transform(crs = "ESRI:102003") # Albers Equal Area

# Map
ggplot(plot_sf) +
    geom_sf(aes(fill = log(County_Value)), color = NA) +
    scale_fill_viridis_c(option = "magma", na.value = "grey90") +
    labs(title = "Golf Course Land Value by County", fill = "Log Value") +
    theme_minimal()

# Save Map
ggsave("Golf_Land_Value_Map.png", width = 10, height = 6)

print("Analysis Complete.")
