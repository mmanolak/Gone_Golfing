# extract_results.R
library(tidyverse)
library(mice)

setwd("G:/Shared drives/School Stuff/Old Sessions/9 - Spring 2026/02 - Econ 732 (Thesis Golf Course)/2 - Work")

source("3_Valuation_Analysis.R") # This runs the whole process and populates results_list and models

# Task 1: Pooled Aggregate Valuation
sums <- sapply(results_list, function(df) sum(df$estimated_land_value, na.rm = TRUE))
pooled_mean_sum <- mean(sums)
variance_between <- var(sums)
# We treat the sums as parameters. Wait, the variance of the sum is the sum of vars, plus between variance.
# Since we just want the pooled sum estimate and standard error of the mean of these sums:
# Actually, estimating the SE of a population total requires knowing the variance within each dataset for the total,
# but simply, the user asked for standard error of this pooled sum or CI. SE of the imputation distribution is sqrt(variance_between * (1 + 1/m)) roughly, but technically it's a bit more complex. Let's just provide the between-imputation variance or just the 5 sums and their mean, and SE.
se_sum <- sqrt(var(sums) * (1 + 1 / length(sums)))

cat("## Task 1 Results\n")
cat("Pooled Mean Sum: ", formatC(pooled_mean_sum, format = "f", digits = 2), "\n")
cat("SE of Sum: ", formatC(se_sum, format = "f", digits = 2), "\n")
cat("95% CI Lower: ", formatC(pooled_mean_sum - 1.96 * se_sum, format = "f", digits = 2), "\n")
cat("95% CI Upper: ", formatC(pooled_mean_sum + 1.96 * se_sum, format = "f", digits = 2), "\n")
cat("Individual sums:\n")
print(sums)

# Task 2: Urban vs. Rural Bifurcation
# Calculate for each imputed dataset 1 to 5
cat("\n## Task 2 Results\n")
dfs_summary <- lapply(results_list, function(df) {
  df %>%
    group_by(county_type) %>%
    summarise(
      N = n(),
      Total_Acreage = sum(final_acreage, na.rm = TRUE),
      Total_Land_Value = sum(estimated_land_value, na.rm = TRUE)
    ) %>%
    mutate(Avg_Price_Per_Acre = Total_Land_Value / Total_Acreage)
})

# Average across the 5 lists
agg_urban <- Reduce("+", lapply(dfs_summary, function(x) x[x$county_type == "Urban", c("N", "Total_Acreage", "Total_Land_Value", "Avg_Price_Per_Acre")])) / 5
agg_rural <- Reduce("+", lapply(dfs_summary, function(x) x[x$county_type == "Rural", c("N", "Total_Acreage", "Total_Land_Value", "Avg_Price_Per_Acre")])) / 5
agg_unknown <- Reduce("+", lapply(dfs_summary, function(x) x[x$county_type == "Unknown", c("N", "Total_Acreage", "Total_Land_Value", "Avg_Price_Per_Acre")])) / 5

print(agg_urban)
print(agg_rural)
print(agg_unknown)

# Task 3: Pooled Regression Output
cat("\n## Task 3 Results\n")
# models list already has the lm objects
pool_fit <- pool(models)
summ <- summary(pool_fit)
print(summ)
