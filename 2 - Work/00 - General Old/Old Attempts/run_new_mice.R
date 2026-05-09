library(tidyverse)
library(sf)
library(mice)
library(tigris)
library(readxl)
library(viridisLite)

options(tigris_use_cache = TRUE)

# Load data and logic from 3_Valuation_Analysis.R up to apply_valuation
golf_data <- read_csv("00 - Golf_Courses_Acreage_Combo.csv", show_col_types = FALSE) %>%
    mutate(course_id = row_number())

fhfa_data <- read_csv("Land_Prices_Counties.csv", show_col_types = FALSE) %>%
    filter(year == max(year)) %>%
    mutate(
        FIPS = str_pad(as.character(fips), 5, pad = "0"),
        FHFA_Price_Per_Acre = land_val_std
    ) %>% select(FIPS, FHFA_Price_Per_Acre)

usda_data <- read_csv("USDA_Ag_State_2025.csv", show_col_types = FALSE) %>%
    filter(measure_type == "Total Ag Land (Incl Buildings)") %>%
    mutate(USDA_Ag_Price = value_numeric) %>% select(state_abbr, USDA_Ag_Price)

rucc_data <- read_csv("USDA_RUCC_Codes.csv", show_col_types = FALSE) %>%
    mutate(FIPS = str_pad(as.character(FIPS), 5, pad = "0")) %>% select(FIPS, RUCC_2013)

# Spatial Join
golf_sf <- golf_data %>%
    filter(!is.na(longitude) & !is.na(latitude)) %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

counties_sf <- tigris::counties(cb = TRUE, resolution = "20m", year = 2022) %>%
    select(GEOID, NAME) %>% st_transform(crs = st_crs(golf_sf))

golf_joined <- st_join(golf_sf, counties_sf, join = st_within) %>%
    mutate(county_fips = GEOID) %>% st_drop_geometry()

golf_master <- golf_data %>%
    left_join(golf_joined %>% select(course_id, county_fips), by = "course_id")

apply_valuation <- function(df, fhfa, usda, rucc) {
    df_joined <- df %>%
        left_join(fhfa, by = c("county_fips" = "FIPS")) %>%
        left_join(usda, by = c("state" = "state_abbr")) %>%
        left_join(rucc, by = c("county_fips" = "FIPS"))
    
    df_final <- df_joined %>%
        mutate(
            county_type = case_when(
                RUCC_2013 %in% 1:3 ~ "Urban",
                RUCC_2013 %in% 4:9 ~ "Rural",
                TRUE ~ "Unknown"
            ),
            Estimated_Price_Per_Acre = case_when(
                county_type == "Urban" & !is.na(FHFA_Price_Per_Acre) ~ FHFA_Price_Per_Acre,
                county_type == "Rural" ~ USDA_Ag_Price,
                county_type == "Urban" & is.na(FHFA_Price_Per_Acre) ~ USDA_Ag_Price,
                !is.na(FHFA_Price_Per_Acre) ~ FHFA_Price_Per_Acre,
                TRUE ~ USDA_Ag_Price
            )
        )
    return(df_final)
}

golf_pre_impute <- apply_valuation(golf_master, fhfa_data, usda_data, rucc_data)

# Ensure final_acreage is available. "acreage" column usually
if("acreage" %in% names(golf_pre_impute)) {
  golf_pre_impute <- golf_pre_impute %>% mutate(final_acreage = acreage) 
}

# Step 1: Acreage Correction
golf_pre_impute <- golf_pre_impute %>%
  mutate(final_acreage = ifelse(!is.na(final_acreage) & final_acreage < 30, NA, final_acreage))

# Step 1: Hole Count Investigation (Top 10)
cat("## Step 1: Top 10 Courses by Hole Count\n\n")
# Creating markdown table
top_10 <- golf_pre_impute %>%
  arrange(desc(holes)) %>%
  slice(1:10) %>%
  select(course_id, holes, state, county_type)

knitr::kable(top_10, format = "markdown") %>% cat(sep="\n")

# Step 2: Re-Run MICE Imputation
mice_data <- golf_pre_impute %>% select(course_id, final_acreage, holes, course_type, longitude, latitude, state, county_type, Estimated_Price_Per_Acre) %>%
  mutate(
    course_type = as.factor(course_type),
    state = as.factor(state),
    county_type = as.factor(county_type)
  )

ini <- mice(mice_data, maxit=0)
pred <- ini$predictorMatrix
pred[,] <- 0
pred["final_acreage", c("holes", "course_type", "longitude", "latitude", "state", "county_type")] <- 1

cat("\n## Step 2: Running MICE Imputation...\n")
mice_out <- mice(mice_data, m = 5, method = 'pmm', maxit = 5, predictorMatrix = pred, printFlag = FALSE)

# Step 3: Recalculate Final Valuations
results_list_new <- list()
for(i in 1:5) {
  imp_i <- complete(mice_out, i)
  imp_i <- imp_i %>% mutate(estimated_land_value = final_acreage * Estimated_Price_Per_Acre)
  results_list_new[[i]] <- imp_i
}

# Step 4: Output the Corrected Summary Statistics
cat("\n## Corrected Summary Statistics\n\n")
calc_stats_new <- function(var_name) {
  means <- sapply(results_list_new, function(df) mean(df[[var_name]], na.rm=TRUE))
  medians <- sapply(results_list_new, function(df) median(df[[var_name]], na.rm=TRUE))
  sds <- sapply(results_list_new, function(df) sd(df[[var_name]], na.rm=TRUE))
  mins <- sapply(results_list_new, function(df) min(df[[var_name]], na.rm=TRUE))
  maxs <- sapply(results_list_new, function(df) max(df[[var_name]], na.rm=TRUE))
  
  c(
    Mean = mean(means),
    Median = mean(medians),
    SD = mean(sds),
    Min = mean(mins),
    Max = mean(maxs)
  )
}

stats_list_new <- lapply(c("final_acreage", "holes", "estimated_land_value"), calc_stats_new)
names(stats_list_new) <- c("final_acreage", "holes", "estimated_land_value")
df_stats <- do.call(rbind, stats_list_new)
df_stats <- as.data.frame(df_stats)
df_stats$Variable <- rownames(df_stats)
df_stats <- df_stats %>% select(Variable, Mean, Median, SD, Min, Max)

knitr::kable(df_stats, format = "markdown", row.names = FALSE) %>% cat(sep="\n")
