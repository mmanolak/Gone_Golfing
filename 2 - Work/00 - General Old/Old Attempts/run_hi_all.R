library(tidyverse)
options(scipen = 999)
invisible(capture.output(suppressMessages(source("run_dedup.R"))))

hi_courses_all <- bind_rows(dedup_results) %>%
  filter(state == "HI") %>%
  group_by(course_id, holes, latitude, longitude) %>%
  summarise(
    final_acreage = mean(final_acreage, na.rm = TRUE),
    estimated_land_value = mean(estimated_land_value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(estimated_land_value)) %>%
  select(course_id, holes, final_acreage, latitude, longitude, estimated_land_value)

hi_courses_all <- hi_courses_all %>%
  mutate(
    final_acreage = round(final_acreage, 3),
    latitude = round(latitude, 5),
    longitude = round(longitude, 5),
    estimated_land_value = paste0("$", formatC(estimated_land_value, format = "f", big.mark = ",", digits = 2))
  )

knitr::kable(hi_courses_all, format = "markdown", row.names = FALSE) %>% cat(sep = "\n")
