library(tidyverse)
options(scipen=999)
invisible(capture.output(suppressMessages(source("run_dedup.R"))))

hi_courses_full <- bind_rows(dedup_results) %>%
  filter(state == "HI") %>%
  group_by(course_id) %>%
  summarise(
    final_acreage = mean(final_acreage, na.rm = TRUE),
    estimated_land_value = mean(estimated_land_value, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(estimated_land_value))

raw_data <- read_csv("00 - Golf_Courses_Acreage_Combo.csv", show_col_types = FALSE) %>%
  mutate(course_id = row_number()) %>%
  select(course_id, course_name, street_address, city)

hi_merged_full <- hi_courses_full %>%
  left_join(raw_data, by = "course_id") %>%
  rename(name = course_name, address = street_address) %>%
  select(course_id, name, address, city, final_acreage, estimated_land_value)

write_csv(hi_merged_full, "HI_Golf_Courses_with_Addresses.csv")

top10 <- hi_merged_full %>%
  slice(1:10) %>%
  mutate(
    final_acreage = round(final_acreage, 3),
    estimated_land_value = paste0("$", formatC(estimated_land_value, format="f", big.mark=",", digits=2))
  )

knitr::kable(top10, format = "markdown", row.names=FALSE) %>% cat(sep="\n")
