# Purpose: Fit OLS regression with HC1 robust standard errors on each of the
#          5 Python-generated MICE imputed datasets from Phase 3.
# Inputs:  Phase 3 Economic Merge and MICE Imputation/Py_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/python/Py_model_results.pkl


# === 1. LIBRARIES ===

import pathlib
import pickle
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR    = pathlib.Path(__file__).parent
PHASE3_DIR    = SCRIPT_DIR.parents[2] / "Phase 3 Economic Merge and MICE Imputation"
OUT_DIR       = SCRIPT_DIR
PKL_PATH      = OUT_DIR / "Py_model_results.pkl"

FORMULA_STR   = "Log_Opportunity_Cost ~ Holes + C(county_type)"
M             = 5
IMPUTED_PATHS = [PHASE3_DIR / f"Py_Imputed_Dataset_{i}.csv" for i in range(1, M + 1)]


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

def main():
    missing = [p for p in IMPUTED_PATHS if not p.is_file()]
    if missing:
        print("[FATAL] The following imputed dataset(s) were not found:")
        for p in missing:
            print(f"  {p}")
        raise SystemExit(1)

    print("Phase 4 — Model Fitting")
    print("=" * 60)
    print(f"Phase 3 inputs : {PHASE3_DIR}")
    print(f"Output folder  : {OUT_DIR}")
    print(f"Formula        : {FORMULA_STR}")
    print("=" * 60 + "\n")

    model_results       = []
    first_model_summary = None

    for i, path in enumerate(IMPUTED_PATHS, start=1):
        fname = path.name
        print(f"[{i}/5] Loading {fname}...")

        acreage_df = pd.read_csv(path, low_memory=False)

        if "osm_acreage" not in acreage_df.columns:
            raise KeyError(f"Column 'osm_acreage' not found in {fname}.")
        if "Baseline_Value_Per_Acre" not in acreage_df.columns:
            raise KeyError(f"Column 'Baseline_Value_Per_Acre' not found in {fname}.")

        acreage_df["Total_Opportunity_Cost"] = (
            acreage_df["osm_acreage"] * acreage_df["Baseline_Value_Per_Acre"]
        )
        acreage_df["Log_Opportunity_Cost"] = np.log1p(
            acreage_df["Total_Opportunity_Cost"]
        )

        cols_needed = [
            "Log_Opportunity_Cost", "Holes", "Baseline_Value_Per_Acre", "county_type"
        ]
        n_before   = len(acreage_df)
        acreage_df = acreage_df.dropna(subset=cols_needed)
        n_dropped  = n_before - len(acreage_df)
        if n_dropped:
            print(f"       Dropped {n_dropped:,} rows with missing values in model columns.")

        model  = smf.ols(FORMULA_STR, data=acreage_df)  # [METHODOLOGY] OLS — log-linear model for opportunity cost
        result = model.fit(cov_type="HC1")               # [METHODOLOGY] HC1 robust SEs — heteroskedasticity-consistent; HC1 = n/(n-k) correction

        model_data = {
            "params":       result.params,
            "bse":          result.bse,
            "rsquared":     result.rsquared,
            "rsquared_adj": result.rsquared_adj,
            "nobs":         result.nobs,
            "df_resid":     result.df_resid,
        }

        model_results.append(model_data)
        print(
            f"       Done — R²={result.rsquared:.4f}, N={int(result.nobs):,}, "
            f"df_resid={int(result.df_resid):,}"
        )

        if i == 1:
            first_model_summary = result.summary()

    with open(PKL_PATH, "wb") as f:
        pickle.dump(model_results, f)

    print(f"\n[+] Saved {len(model_results)} model data dictionaries to:\n    {PKL_PATH}")

    print(f"\n{'=' * 60}")
    print("Model 1 Summary (Py_Imputed_Dataset_1.csv)")
    print("=" * 60)
    print(first_model_summary)


if __name__ == "__main__":
    main()
