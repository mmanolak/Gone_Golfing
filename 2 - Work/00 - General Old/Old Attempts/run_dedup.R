library(tidyverse)
options(scipen=999)
invisible(capture.output(suppressMessages(source("run_new_mice.R"))))

cat("\n## Task 1: Extract Coordinates for Hawai'i Case Study\n\n")

cs_ids <- c(3741, 3742, 3727, 3729, 3758)
cs_data <- results_list_new[[1]] %>%
  filter(course_id %in% cs_ids) %>%
  select(course_id, holes, final_acreage, latitude, longitude)

knitr::kable(cs_data, format = "markdown", row.names=FALSE) %>% cat(sep="\n")

cat("\n## Task 2: Identify and Remove Spatial Duplicates\n\n")

orig_n <- nrow(results_list_new[[1]])

dedup_results <- lapply(results_list_new, function(df) {
  df %>%
    mutate(
      lat_r = round(latitude, 3),
      lon_r = round(longitude, 3)
    ) %>%
    group_by(state, lat_r, lon_r) %>%
    arrange(desc(holes), desc(final_acreage)) %>%
    slice(1) %>%
    ungroup()
})

new_n <- nrow(dedup_results[[1]])
removed_n <- orig_n - new_n
cat("Number of duplicate observations removed: ", removed_n, "\n")

cat("\n## Task 3: Recalculate Final Aggregates (Post-Deduplication)\n\n")

nat_summaries <- lapply(dedup_results, function(df) {
  df %>%
    summarise(
      N = n(),
      Total_Acreage = sum(final_acreage, na.rm=TRUE),
      Total_Land_Value = sum(estimated_land_value, na.rm=TRUE)
    )
})
nat_agg <- bind_rows(nat_summaries) %>%
  summarise(
    N = mean(N),
    Total_Acreage = mean(Total_Acreage),
    Total_Land_Value = mean(Total_Land_Value)
  )

cat("### Updated National Aggregate\n\n")
knitr::kable(nat_agg, format="markdown", row.names=FALSE) %>% cat(sep="\n")

urb_summaries <- lapply(dedup_results, function(df) {
  df %>%
    filter(county_type == "Urban") %>%
    summarise(
      N = n(),
      Total_Land_Value = sum(estimated_land_value, na.rm=TRUE)
    )
})
urb_agg <- bind_rows(urb_summaries) %>%
  summarise(
    N = mean(N),
    Total_Land_Value = mean(Total_Land_Value)
  )

cat("\n### Updated Urban Aggregate\n\n")
knitr::kable(urb_agg, format="markdown", row.names=FALSE) %>% cat(sep="\n")
