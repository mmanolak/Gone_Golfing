# Purpose: Pool the 5 per-imputation OLS estimates from model_fitting.R via
#          Rubin's Rules and save a regression table.
# Inputs:  Bulk Tests/R/R_model_results.rds
# Outputs: Bulk Tests/R/R_Regression_Results.csv


# === 1. LIBRARIES ===

suppressPackageStartupMessages({
  library(this.path)
})


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR <- this.path::this.dir()
RDS_PATH   <- file.path(SCRIPT_DIR, "R_model_results.rds")
OUT_CSV    <- file.path(SCRIPT_DIR, "R_Regression_Results.csv")


# === 3. FUNCTIONS ===

#' Return significance stars for a vector of p-values.
#'
#' @param p Numeric vector of p-values.
#' @return Character vector of star strings.
stars <- function(p) {
  sapply(p, function(x) {
    if (is.na(x))  return("")
    if (x < 0.001) return("***")
    if (x < 0.01)  return("**")
    if (x < 0.05)  return("*")
    if (x < 0.1)   return(".")
    ""
  })
}


# === 4. EXECUTION ===

if (!file.exists(RDS_PATH)) {
  stop(sprintf(
    "[FATAL] Model results file not found:\n  %s\n  Run model_fitting.R first.",
    RDS_PATH
  ))
}

model_results <- readRDS(RDS_PATH)
num_imp       <- length(model_results)

cat("Phase 4 — Parameter Pooling (Rubin's Rules)\n")
cat("============================================================\n")
cat(sprintf("Loaded %d model data lists from:\n  %s\n\n", num_imp, RDS_PATH))

params_list <- lapply(model_results, function(r) r$params)
bse_list    <- lapply(model_results, function(r) r$bse)

all_params <- unique(unlist(lapply(params_list, names)))

coef_mat <- matrix(NA, nrow = num_imp, ncol = length(all_params))
colnames(coef_mat) <- all_params
var_mat  <- matrix(NA, nrow = num_imp, ncol = length(all_params))
colnames(var_mat)  <- all_params

for (i in seq_len(num_imp)) {
  p_names              <- names(params_list[[i]])
  coef_mat[i, p_names] <- params_list[[i]]
  var_mat[i, p_names]  <- (bse_list[[i]])^2
}

missing_mask <- apply(is.na(coef_mat), 2, any)
if (any(missing_mask)) {
  cat("[!] The following parameters were absent in at least one model and will\n")
  cat("    be pooled only over models where they appeared:\n")
  for (p in names(which(missing_mask))) {
    present_in <- sum(!is.na(coef_mat[, p]))
    cat(sprintf(
      "      %s  (present in %d/%d models)\n",
      p, present_in, num_imp
    ))
  }
  cat("\n")
}

# [METHODOLOGY] Rubin's Rules — Barnard & Rubin (1999) df approximation
m_i <- apply(!is.na(coef_mat), 2, sum)
m_i[m_i < 2] <- 2

q_bar  <- colMeans(coef_mat, na.rm = TRUE)
v_w    <- colMeans(var_mat, na.rm = TRUE)
v_b    <- apply(coef_mat, 2, var, na.rm = TRUE)
v_t    <- v_w + (1 + 1 / m_i) * v_b
se     <- sqrt(v_t)

t_stat  <- q_bar / se
lambda_ <- (1 + 1 / m_i) * v_b / v_t
df_old  <- (m_i - 1) / (lambda_^2)
df_com  <- model_results[[1]]$df_resid
df_obs  <- (df_com + 1) / (df_com + 3) * df_com * (1 - lambda_)
df_adj  <- 1 / (1 / df_old + 1 / df_obs)

p_val <- 2 * pt(abs(t_stat), df = df_adj, lower.tail = FALSE)

pooled_df <- data.frame(
  Parameter = names(q_bar),
  Coef      = q_bar,
  Std_Error = se,
  t_stat    = t_stat,
  df_adj    = df_adj,
  p_value   = p_val,
  Sig       = stars(p_val),
  V_within  = v_w,
  V_between = v_b,
  V_total   = v_t,
  FMI       = lambda_,
  stringsAsFactors = FALSE
)
rownames(pooled_df) <- NULL

cat(sprintf(
  "Pooled OLS Regression Results  (M=%d imputations, Rubin's Rules)\n",
  num_imp
))
cat("Formula: Log_Opportunity_Cost ~ Holes + factor(county_type)\n")
cat("Robust variance: HC1 | Sig: *** p<.001  ** p<.01  * p<.05  . p<.1\n")
cat("----------------------------------------------------------------------\n")

header <- sprintf(
  "%-45s %10s %10s %8s %8s  %s",
  "Parameter", "Coef", "SE", "t", "p", "Sig"
)
cat(header, "\n")
cat("----------------------------------------------------------------------\n")

for (i in seq_len(nrow(pooled_df))) {
  cat(sprintf(
    "%-45s %10.4f %10.4f %8.3f %8.4f  %s\n",
    pooled_df$Parameter[i],
    pooled_df$Coef[i],
    pooled_df$Std_Error[i],
    pooled_df$t_stat[i],
    pooled_df$p_value[i],
    pooled_df$Sig[i]
  ))
}

cat("----------------------------------------------------------------------\n")

r2_vals  <- sapply(model_results, function(r) r$rsquared)
r2a_vals <- sapply(model_results, function(r) r$rsquared_adj)
n_vals   <- sapply(model_results, function(r) r$nobs)

cat(sprintf("\nModel diagnostics across %d imputations:\n", num_imp))
cat(sprintf(
  "  R²         : mean=%.4f  min=%.4f  max=%.4f\n",
  mean(r2_vals), min(r2_vals), max(r2_vals)
))
cat(sprintf(
  "  Adj. R²    : mean=%.4f  min=%.4f  max=%.4f\n",
  mean(r2a_vals), min(r2a_vals), max(r2a_vals)
))
cat(sprintf("  N per model: [%s]\n", paste(n_vals, collapse = ", ")))

write.csv(pooled_df, OUT_CSV, row.names = FALSE)
cat(sprintf(
  "\n[+] R_Regression_Results.csv saved to:\n    %s\n",
  OUT_CSV
))
