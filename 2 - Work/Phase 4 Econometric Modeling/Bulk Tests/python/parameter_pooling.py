# Purpose: Pool the 5 per-imputation OLS estimates from model_fitting.py via
#          Rubin's Rules and save a regression table.
# Inputs:  Bulk Tests/python/Py_model_results.pkl
# Outputs: Bulk Tests/python/Py_Regression_Results.csv


# === 1. LIBRARIES ===

import pathlib
import pickle
import numpy as np
import pandas as pd
from scipy import stats


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = pathlib.Path(__file__).parent
PKL_PATH   = SCRIPT_DIR / "Py_model_results.pkl"
OUT_CSV    = SCRIPT_DIR / "Py_Regression_Results.csv"


# === 3. FUNCTIONS ===

def stars(p: float) -> str:
    """Return significance stars for a single p-value."""
    if p < 0.001: return "***"
    if p < 0.01:  return "**"
    if p < 0.05:  return "*"
    if p < 0.1:   return "."
    return ""


# === 4. EXECUTION ===

def main():
    if not PKL_PATH.is_file():
        print(f"[FATAL] Could not find model results file:\n  {PKL_PATH}")
        print("  Run model_fitting.py first.")
        raise SystemExit(1)

    with open(PKL_PATH, "rb") as f:
        model_results = pickle.load(f)

    M = len(model_results)
    print("Phase 4 — Parameter Pooling (Rubin's Rules)")
    print("=" * 60)
    print(f"Loaded {M} model data dictionaries from:\n  {PKL_PATH}\n")

    coef_df = pd.DataFrame([r["params"] for r in model_results])
    var_df  = pd.DataFrame([r["bse"] ** 2 for r in model_results])

    all_params = coef_df.columns.tolist()
    coef_df    = coef_df.reindex(columns=all_params)
    var_df     = var_df.reindex(columns=all_params)

    missing_mask = coef_df.isna().any(axis=0)
    if missing_mask.any():
        print("[!] The following parameters were absent in at least one model and will")
        print("    be pooled only over models where they appeared:")
        for p in missing_mask[missing_mask].index:
            present_in = coef_df[p].notna().sum()
            print(f"      {p}  (present in {present_in}/{M} models)")
        print()

    # [METHODOLOGY] Rubin's Rules — Barnard & Rubin (1999) df approximation
    m_i = coef_df.notna().sum(axis=0).clip(lower=2)

    q_bar   = coef_df.mean(axis=0)
    v_w     = var_df.mean(axis=0)
    v_b     = coef_df.var(axis=0, ddof=1)
    v_t     = v_w + (1 + 1 / m_i) * v_b
    se      = np.sqrt(v_t)

    t_stat  = q_bar / se
    lambda_ = (1 + 1 / m_i) * v_b / v_t
    df_old  = (m_i - 1) / (lambda_ ** 2)
    df_com  = model_results[0]["df_resid"]
    df_obs  = (df_com + 1) / (df_com + 3) * df_com * (1 - lambda_)
    df_adj  = 1 / (1 / df_old + 1 / df_obs)

    p_val = 2 * stats.t.sf(np.abs(t_stat), df=df_adj)

    pooled_df = pd.DataFrame({
        "Parameter": q_bar.index,
        "Coef":      q_bar.values,
        "Std_Error": se.values,
        "t_stat":    t_stat.values,
        "df_adj":    df_adj.values,
        "p_value":   p_val,
        "Sig":       [stars(p) for p in p_val],
        "V_within":  v_w.values,
        "V_between": v_b.values,
        "V_total":   v_t.values,
        "FMI":       lambda_.values,
    }).reset_index(drop=True)

    print(f"Pooled OLS Regression Results  (M={M} imputations, Rubin's Rules)")
    print("Formula: Log_Opportunity_Cost ~ Holes + C(county_type)")
    print("Robust variance: HC1  |  Significance: *** p<.001  ** p<.01  * p<.05  . p<.1")
    print("-" * 90)

    header = f"{'Parameter':<45} {'Coef':>10} {'SE':>10} {'t':>8} {'p':>8}  {'Sig'}"
    print(header)
    print("-" * 90)

    for _, row in pooled_df.iterrows():
        print(
            f"{str(row['Parameter']):<45} "
            f"{row['Coef']:>10.4f} "
            f"{row['Std_Error']:>10.4f} "
            f"{row['t_stat']:>8.3f} "
            f"{row['p_value']:>8.4f}  "
            f"{row['Sig']}"
        )

    print("-" * 90)

    r2_vals  = [r["rsquared"]     for r in model_results]
    r2a_vals = [r["rsquared_adj"] for r in model_results]
    n_vals   = [int(r["nobs"])    for r in model_results]

    print(f"\nModel diagnostics across {M} imputations:")
    print(
        f"  R²         : mean={np.mean(r2_vals):.4f}  "
        f"min={np.min(r2_vals):.4f}  max={np.max(r2_vals):.4f}"
    )
    print(
        f"  Adj. R²    : mean={np.mean(r2a_vals):.4f}  "
        f"min={np.min(r2a_vals):.4f}  max={np.max(r2a_vals):.4f}"
    )
    print(f"  N per model: {n_vals}")

    pooled_df.to_csv(OUT_CSV, index=False)
    print(f"\n[+] Py_Regression_Results.csv saved to:\n    {OUT_CSV}")


if __name__ == "__main__":
    main()
