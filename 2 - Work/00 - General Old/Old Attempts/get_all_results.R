library(tidyverse)
library(mice)

setwd("G:/Shared drives/School Stuff/Old Sessions/9 - Spring 2026/02 - Econ 732 (Thesis Golf Course)/2 - Work")

mice_output <- readRDS("MICE_Output_Object.rds")
master <- read_csv("Golf_Courses_Enriched_Master.csv", show_col_types=FALSE) %>%
  mutate(county_fips = str_pad(fips_code, 5, pad="0"))

fhfa <- read_csv("Land_Prices_Counties.csv", show_col_types=FALSE) %>%
  filter(year == max(year)) %>%
  mutate(county_fips = str_pad(fips, 5, pad="0")) %>%
  select(county_fips, FHFA_Price_Per_Acre = land_val_std)

usda <- read_csv("USDA_Ag_State_2025.csv", show_col_types=FALSE) %>%
  filter(measure_type == "Total Ag Land (Incl Buildings)") %>%
  select(state_abbr, USDA_Ag_Price = value_numeric)

res_list <- list()
models <- list()

for (i in 1:5) {
  imp <- complete(mice_output, i)
  
  df <- imp %>% left_join(master %>% select(temp_id, county_type, county_fips), by=c("course_id" = "temp_id"))
  
  df <- df %>% 
    left_join(fhfa, by="county_fips") %>%
    left_join(usda, by=c("state" = "state_abbr"))
  
  df <- df %>% mutate(
    Estimated_Price_Per_Acre = case_when(
      county_type == "Urban" & !is.na(FHFA_Price_Per_Acre) ~ FHFA_Price_Per_Acre,
      county_type == "Urban" & is.na(FHFA_Price_Per_Acre) ~ USDA_Ag_Price,
      county_type == "Rural" ~ USDA_Ag_Price,
      TRUE ~ USDA_Ag_Price
    ),
    estimated_land_value = acreage * Estimated_Price_Per_Acre,
    final_acreage = acreage
  )
  res_list[[i]] <- df
  models[[i]] <- lm(log(estimated_land_value + 1) ~ holes + course_type + county_type, data = df)
}

sums <- sapply(res_list, function(d) sum(d$estimated_land_value, na.rm=TRUE))
mean_sum <- mean(sums)

cat("Task 1: Pooled Aggregate Valuation\n")
cat("Pooled Mean:", formatC(mean_sum, format="f", digits=2), "\n")
cat("Sums for each dataset:\n")
print(sums)

cat("\nTask 2: Urban vs Rural\n")
agg_list <- lapply(res_list, function(d) {
  d %>% group_by(county_type) %>%
    summarise(
      N = n(),
      Total_Acreage = sum(final_acreage, na.rm=TRUE),
      Total_Estimated_Land_Value = sum(estimated_land_value, na.rm=TRUE)
    ) %>%
    mutate(Avg_Price_Per_Acre = Total_Estimated_Land_Value / Total_Acreage)
})

agg_all <- bind_rows(agg_list) %>% 
  group_by(county_type) %>%
  summarise(
    N = mean(N),
    Total_Acreage = mean(Total_Acreage),
    Total_Estimated_Land_Value = mean(Total_Estimated_Land_Value),
    Avg_Price_Per_Acre = mean(Avg_Price_Per_Acre)
  )
print(agg_all)

cat("\nTask 3: Pooled Regression\n")
pooled_fit <- pool(models)
print(summary(pooled_fit))
