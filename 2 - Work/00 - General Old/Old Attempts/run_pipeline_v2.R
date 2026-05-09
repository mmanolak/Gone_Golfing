library(tidyverse)
library(sf)
library(mice)
library(tigris)
library(readxl)

options(scipen=999)
options(tigris_use_cache = TRUE)

# Phase 1: Rigorous Deduplication
raw_data <- read_csv("00 - Golf_Courses_Acreage_Combo.csv", show_col_types = FALSE)

df <- raw_data %>%
  mutate(
    address_clean = str_to_lower(str_trim(street_address)),
    city_clean = str_to_lower(str_trim(city)),
    lat_r = round(latitude, 3),
    lon_r = round(longitude, 3)
  )

orig_n <- nrow(df)

df_spatial <- df %>%
  group_by(lat_r, lon_r) %>%
  arrange(desc(holes), desc(final_acreage)) %>%
  slice(1) %>%
  ungroup()

df_clean <- df_spatial %>%
  mutate(
    group_addr = case_when(
      is.na(address_clean) | address_clean == "" | address_clean == "na" ~ paste0("no_address_", row_number()),
      is.na(city_clean) | city_clean == "" ~ paste0("no_city_", row_number()),
      TRUE ~ paste(address_clean, city_clean, sep = "_")
    )
  ) %>%
  group_by(group_addr) %>%
  arrange(desc(holes), desc(final_acreage)) %>%
  slice(1) %>%
  ungroup()

df_clean <- df_clean %>%
  mutate(
    acreage_source = case_when(
        is.na(final_acreage) ~ "MICE Imputed (Missing)",
        final_acreage < 30 ~ "MICE Imputed (Cleaned <30 ac)",
        is.na(acreage_source) ~ "MICE Imputed (Missing Source)",
        TRUE ~ acreage_source
    ),
    final_acreage = ifelse(!is.na(final_acreage) & final_acreage < 30, NA, final_acreage)
  ) %>%
  mutate(temp_id = row_number())

cleaned_n <- nrow(df_clean)
removed_n <- orig_n - cleaned_n

cat("## Phase 1: Rigorous Deduplication\n\n")
cat("| Metric | Value |\n")
cat("| :--- | :--- |\n")
cat("| **Original N** |", orig_n, "|\n")
cat("| **Duplicates Removed** |", removed_n, "|\n")
cat("| **Cleaned N** |", cleaned_n, "|\n\n")

# Phase 2: Spatial Join and Hybrid Classification
golf_sf <- df_clean %>%
    filter(!is.na(longitude) & !is.na(latitude)) %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

counties_sf <- tigris::counties(cb = TRUE, resolution = "20m", year = 2022) %>%
    select(GEOID) %>% st_transform(crs = st_crs(golf_sf))

golf_joined <- st_join(golf_sf, counties_sf, join = st_within) %>% st_drop_geometry()

df_clean <- df_clean %>%
   left_join(golf_joined %>% select(temp_id, county_fips = GEOID), by = "temp_id")

fhfa_data <- read_csv("Land_Prices_Counties.csv", show_col_types = FALSE) %>% filter(year == max(year)) %>% mutate(FIPS = str_pad(as.character(fips), 5, pad = "0"), FHFA_Price_Per_Acre = land_val_std) %>% select(FIPS, FHFA_Price_Per_Acre)
usda_data <- read_csv("USDA_Ag_State_2025.csv", show_col_types = FALSE) %>% filter(measure_type == "Total Ag Land (Incl Buildings)") %>% mutate(USDA_Ag_Price = value_numeric) %>% select(state_abbr, USDA_Ag_Price)
rucc_data <- read_csv("USDA_RUCC_Codes.csv", show_col_types = FALSE) %>% mutate(FIPS = str_pad(as.character(FIPS), 5, pad = "0")) %>% select(FIPS, RUCC_2013)

df_clean <- df_clean %>%
  left_join(fhfa_data, by = c("county_fips" = "FIPS")) %>%
  left_join(usda_data, by = c("state" = "state_abbr")) %>%
  left_join(rucc_data, by = c("county_fips" = "FIPS")) %>%
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

# Phase 3: MICE Imputation
pct_missing <- sum(is.na(df_clean$final_acreage)) / nrow(df_clean) * 100

mice_data <- df_clean %>%
  select(temp_id, final_acreage, holes, course_type, longitude, latitude, state, county_type, Estimated_Price_Per_Acre) %>%
  mutate(
    course_type = as.factor(course_type),
    state = as.factor(state),
    county_type = as.factor(county_type)
  )

ini <- mice(mice_data, maxit=0)
pred <- ini$predictorMatrix
pred[,] <- 0
pred["final_acreage", c("holes", "county_type", "Estimated_Price_Per_Acre", "latitude", "longitude")] <- 1

mice_out <- mice(mice_data, m = 5, method = 'pmm', maxit = 5, predictorMatrix = pred, printFlag = FALSE)

# Phase 4: Valuation and Pooling
results_list <- list()
nat_sums <- numeric(5)
urb_sums <- numeric(5)
rur_sums <- numeric(5)

for(i in 1:5) {
  imp_i <- complete(mice_out, i)
  imp_i_full <- df_clean %>%
    select(-final_acreage, -holes, -course_type, -longitude, -latitude, -state, -county_type, -Estimated_Price_Per_Acre) %>%
    left_join(imp_i, by = "temp_id") %>%
    mutate(estimated_land_value = final_acreage * Estimated_Price_Per_Acre)
    
  results_list[[i]] <- imp_i_full
  nat_sums[i] <- sum(imp_i_full$estimated_land_value, na.rm=TRUE)
  urb_sums[i] <- sum(imp_i_full$estimated_land_value[imp_i_full$county_type == "Urban"], na.rm=TRUE)
  rur_sums[i] <- sum(imp_i_full$estimated_land_value[imp_i_full$county_type == "Rural"], na.rm=TRUE)
}

pooled_nat_sum <- mean(nat_sums)
pooled_urb_sum <- mean(urb_sums)
pooled_rur_sum <- mean(rur_sums)

pooled_df <- bind_rows(results_list) %>%
  group_by(temp_id, course_name, street_address, city, state, zip_code, holes, county_type, Estimated_Price_Per_Acre, latitude, longitude, acreage_source) %>%
  summarise(
    final_acreage = mean(final_acreage, na.rm=TRUE),
    estimated_land_value = mean(estimated_land_value, na.rm=TRUE),
    .groups = 'drop'
  ) %>%
  ungroup() %>%
  select(-temp_id)

write_csv(pooled_df, "Version2_Cleaned_Golf_Valuation.csv")

# Phase 5: Output Generation
cat("### National Aggregate\n\n")
cat("| Metric | Value |\n")
cat("| :--- | :--- |\n")
cat("| **Total National Estimated Land Value** | $", formatC(pooled_nat_sum, format="f", big.mark=",", digits=2), " |\n\n", sep="")

cat("### Urban / Rural Bifurcation\n\n")
cat("| Type | Estimated Land Value |\n")
cat("| :--- | :--- |\n")
cat("| **Urban** | $", formatC(pooled_urb_sum, format="f", big.mark=",", digits=2), " |\n", sep="")
cat("| **Rural** | $", formatC(pooled_rur_sum, format="f", big.mark=",", digits=2), " |\n\n", sep="")

cat("### Top 10 Hawai'i Courses\n\n")

hi_top10 <- pooled_df %>%
  filter(state == "HI") %>%
  arrange(desc(estimated_land_value)) %>%
  slice(1:10) %>%
  select(name=course_name, address=street_address, city, holes, final_acreage, Estimated_Price_Per_Acre, estimated_land_value)

hi_top10 <- hi_top10 %>%
  mutate(
    final_acreage = round(final_acreage, 3),
    Estimated_Price_Per_Acre = paste0("$", formatC(Estimated_Price_Per_Acre, format="f", big.mark=",", digits=2)),
    estimated_land_value = paste0("$", formatC(estimated_land_value, format="f", big.mark=",", digits=2))
  )

knitr::kable(hi_top10, format = "markdown", row.names=FALSE) %>% cat(sep="\n")
