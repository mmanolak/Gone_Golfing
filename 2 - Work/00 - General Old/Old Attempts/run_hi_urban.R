library(tidyverse)
invisible(capture.output(suppressMessages(source("run_new_mice.R"))))

# Task 1: Hawai'i State Aggregate Valuation
hi_summaries <- lapply(results_list_new, function(df) {
  df %>%
    filter(state == "HI") %>%
    summarise(
      N = n(),
      Total_Acreage = sum(final_acreage, na.rm = TRUE),
      Total_Land_Value = sum(estimated_land_value, na.rm = TRUE)
    )
})
hi_agg <- bind_rows(hi_summaries) %>%
  summarise(
    N = mean(N),
    Total_Acreage = mean(Total_Acreage),
    Total_Land_Value = mean(Total_Land_Value)
  ) %>%
  mutate(Avg_Price_Per_Acre = Total_Land_Value / Total_Acreage)

cat("\n## Task 1: Hawai'i State Aggregate Valuation\n\n")
print(hi_agg)

# Task 2: Top 5 Most Valuable Golf Courses in Hawai'i
hi_courses <- bind_rows(results_list_new) %>%
  filter(state == "HI") %>%
  group_by(course_id, holes, Estimated_Price_Per_Acre) %>%
  summarise(
    final_acreage = mean(final_acreage, na.rm = TRUE),
    estimated_land_value = mean(estimated_land_value, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(estimated_land_value)) %>%
  select(course_id, holes, final_acreage, Estimated_Price_Per_Acre, estimated_land_value) %>%
  slice(1:5)

cat("\n## Task 2: Top 5 Most Valuable Golf Courses in Hawai'i\n\n")
print(hi_courses)

# Task 3: Updated National "Urban" Aggregate
urban_summaries <- lapply(results_list_new, function(df) {
  df %>%
    filter(county_type == "Urban") %>%
    summarise(
      N = n(),
      Total_Urban_Acreage = sum(final_acreage, na.rm = TRUE),
      Total_Urban_Land_Value = sum(estimated_land_value, na.rm = TRUE)
    )
})
urban_agg <- bind_rows(urban_summaries) %>%
  summarise(
    N = mean(N),
    Total_Urban_Acreage = mean(Total_Urban_Acreage),
    Total_Urban_Land_Value = mean(Total_Urban_Land_Value)
  )

cat("\n## Task 3: Updated National 'Urban' Aggregate\n\n")
print(urban_agg)
