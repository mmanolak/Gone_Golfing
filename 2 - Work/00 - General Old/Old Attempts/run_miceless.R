library(tidyverse)
library(sf)
library(tigris)
library(readxl)

options(scipen=999)
options(tigris_use_cache = TRUE)

raw_data <- read_csv("00 - Golf_Courses_Acreage_Combo.csv", show_col_types = FALSE)

df <- raw_data %>%
  mutate(
    address_clean = str_to_lower(str_trim(street_address)),
    city_clean = str_to_lower(str_trim(city)),
    lat_r = round(latitude, 3),
    lon_r = round(longitude, 3)
  )

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
        is.na(final_acreage) ~ "Missing",
        final_acreage < 30 ~ "Cleaned <30 ac",
        is.na(acreage_source) ~ "Missing Source",
        TRUE ~ acreage_source
    ),
    final_acreage_clean = ifelse(!is.na(final_acreage) & final_acreage < 30, NA, final_acreage)
  ) %>%
  mutate(temp_id = row_number())

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

miceless_df <- df_clean %>%
  filter(!is.na(final_acreage_clean)) %>%
  mutate(estimated_land_value = final_acreage_clean * Estimated_Price_Per_Acre) %>%
  select(course_name, street_address, city, state, zip_code, holes, county_type,
         Estimated_Price_Per_Acre, latitude, longitude, acreage_source, 
         final_acreage = final_acreage_clean, estimated_land_value)

write_csv(miceless_df, "Miceless_Cleaned_Golf_Valuation.csv")
cat(nrow(miceless_df), "\n")
