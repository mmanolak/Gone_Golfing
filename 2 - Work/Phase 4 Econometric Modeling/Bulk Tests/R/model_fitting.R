# Purpose: Fit OLS regression with HC1 robust standard errors on each of the
#          5 R-generated MICE imputed datasets from Phase 3.
# Inputs:  Phase 3 Economic Merge and MICE Imputation/R_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/R/R_model_results.rds


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(sandwich)
  library(lmtest)
  library(tidyverse)
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
PHASE3_DIR <- file.path(
  SCRIPT_DIR, "..", "..", "..", "Phase 3 Economic Merge and MICE Imputation"
)
OUT_DIR  <- SCRIPT_DIR
RDS_PATH <- file.path(OUT_DIR, "R_model_results.rds")

FORMULA_STR   <- "Log_Opportunity_Cost ~ Holes + factor(county_type)"
M             <- 5
IMPUTED_PATHS <- file.path(
  PHASE3_DIR,
  paste0("R_Imputed_Dataset_", seq_len(M), ".csv")
)


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

missing_files <- IMPUTED_PATHS[!file.exists(IMPUTED_PATHS)]
if (length(missing_files) > 0) {
  stop(paste(
    c("[FATAL] The following imputed dataset(s) were not found:", missing_files),
    collapse = "\n  "
  ))
}

cat("Phase 4 — Model Fitting\n")
cat("============================================================\n")
cat(sprintf("Phase 3 inputs : %s\n", PHASE3_DIR))
cat(sprintf("Output folder  : %s\n", OUT_DIR))
cat(sprintf("Formula        : %s\n", FORMULA_STR))
cat("============================================================\n\n")

model_results       <- list()
first_model_summary <- NULL

for (i in seq_along(IMPUTED_PATHS)) {
  path  <- IMPUTED_PATHS[i]
  fname <- basename(path)
  cat(sprintf("[%d/5] Loading %s...\n", i, fname))

  acreage_df <- read.csv(path, stringsAsFactors = FALSE)

  if (!"osm_acreage" %in% names(acreage_df)) {
    stop(sprintf("Column 'osm_acreage' not found in %s.", fname))
  }
  if (!"Baseline_Value_Per_Acre" %in% names(acreage_df)) {
    stop(sprintf("Column 'Baseline_Value_Per_Acre' not found in %s.", fname))
  }

  acreage_df$Total_Opportunity_Cost <- acreage_df$osm_acreage * acreage_df$Baseline_Value_Per_Acre
  acreage_df$Log_Opportunity_Cost   <- log1p(acreage_df$Total_Opportunity_Cost)

  cols_needed <- c(
    "Log_Opportunity_Cost", "Holes", "Baseline_Value_Per_Acre", "county_type"
  )
  n_before   <- nrow(acreage_df)
  acreage_df <- acreage_df[complete.cases(acreage_df[, cols_needed]), ]
  n_dropped  <- n_before - nrow(acreage_df)

  if (n_dropped > 0) {
    cat(sprintf(
      "       Dropped %d rows with missing values in model columns.\n",
      n_dropped
    ))
  }

  model <- lm(as.formula(FORMULA_STR), data = acreage_df)  # [METHODOLOGY] OLS — log-linear model for opportunity cost

  # [METHODOLOGY] HC1 robust standard errors — heteroskedasticity-consistent;
  #               HC1 applies n/(n-k) finite-sample correction
  vcov_hc1 <- vcovHC(model, type = "HC1")
  bse      <- sqrt(diag(vcov_hc1))

  summ         <- summary(model)
  rsquared     <- summ$r.squared
  rsquared_adj <- summ$adj.r.squared
  nobs_val     <- nobs(model)
  df_resid     <- df.residual(model)

  model_data <- list(
    params       = coef(model),
    bse          = bse,
    rsquared     = rsquared,
    rsquared_adj = rsquared_adj,
    nobs         = nobs_val,
    df_resid     = df_resid
  )

  model_results[[i]] <- model_data

  cat(sprintf(
    "       Done — R²=%.4f, N=%d, df_resid=%d\n",
    rsquared, nobs_val, df_resid
  ))

  if (i == 1) {
    summ_robust         <- coeftest(model, vcov. = vcov_hc1)
    first_model_summary <- capture.output(print(summ_robust))
  }
}

saveRDS(model_results, file = RDS_PATH)

cat(sprintf(
  "\n[+] Saved %d model data lists to:\n    %s\n",
  length(model_results), RDS_PATH
))

cat("\n============================================================\n")
cat("Model 1 Summary (R_Imputed_Dataset_1.csv)\n")
cat("============================================================\n")
cat(paste(first_model_summary, collapse = "\n"), "\n")
