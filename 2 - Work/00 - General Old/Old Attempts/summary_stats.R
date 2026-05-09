library(tidyverse)
source("3_Valuation_Analysis.R")
calc_stats <- function(var_name) {
  means <- sapply(results_list, function(df) mean(df[[var_name]], na.rm=TRUE))
  medians <- sapply(results_list, function(df) median(df[[var_name]], na.rm=TRUE))
  sds <- sapply(results_list, function(df) sd(df[[var_name]], na.rm=TRUE))
  mins <- sapply(results_list, function(df) min(df[[var_name]], na.rm=TRUE))
  maxs <- sapply(results_list, function(df) max(df[[var_name]], na.rm=TRUE))
  c(
    Mean = mean(means),
    Median = mean(medians),
    SD = mean(sds),
    Min = mean(mins),
    Max = mean(maxs)
  )
}
stats_list <- lapply(c("final_acreage", "holes", "estimated_land_value"), calc_stats)
names(stats_list) <- c("Final Acreage", "Holes", "Estimated Value")
df <- do.call(rbind, stats_list)
print(df)
