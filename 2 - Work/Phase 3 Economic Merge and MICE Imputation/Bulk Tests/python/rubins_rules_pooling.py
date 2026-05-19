# Purpose: Pool the 5 MICE-imputed aggregate estimates using Rubin's Rules
#          to produce a single national land-value point estimate with 95% CI.
# Inputs:  Bulk Tests/python/Py_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/python/Py_Rubins_Rules_Summary.csv


# === 1. LIBRARIES ===

import pathlib

import numpy as np
import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = pathlib.Path(__file__).parent
IN_DIR     = SCRIPT_DIR
OUT_CSV    = SCRIPT_DIR / "Py_Rubins_Rules_Summary.csv"

M = 5


# === 3. FUNCTIONS ===

def run_pooling(in_dir, out_csv, m_datasets=5):
    aggregates  = []
    within_vars = []

    print("--- 1  Loading imputed datasets and computing aggregates ---\n")
    for i in range(1, m_datasets + 1):
        fpath = in_dir / f"Py_Imputed_Dataset_{i}.csv"

        if not fpath.exists():
            raise FileNotFoundError(f"Imputed dataset not found: {fpath}")

        df = pd.read_csv(fpath)
        df["Total_Opportunity_Cost"] = (
            df["osm_acreage"] * df["Baseline_Value_Per_Acre"]
        )

        q_i   = df["Total_Opportunity_Cost"].sum()
        var_i = df["Total_Opportunity_Cost"].var()

        aggregates.append(q_i)
        within_vars.append(var_i)

        print(f"  Dataset {i}:  ${q_i / 1e9:>10,.3f} B")

    aggregates  = np.array(aggregates)
    within_vars = np.array(within_vars)

    # [METHODOLOGY] Rubin's Rules pooling — q_bar is the pooled national estimate;
    #               v_t combines within- and between-imputation variance (Rubin 1987)
    print("\n--- 2  Applying Rubin's Rules ---")

    q_bar = aggregates.mean()
    v_w   = within_vars.mean()
    v_b   = aggregates.var(ddof=1)
    v_t   = v_w + v_b + v_b / m_datasets
    se    = np.sqrt(v_t)
    ci_lo = q_bar - 2.576 * se
    ci_hi = q_bar + 2.576 * se

    print(f"\n=== RUBIN'S RULES RESULTS ===")
    print(f"  Pooled Aggregate National Value:  ${q_bar / 1e9:,.3f} Billion")
    print(f"  Within-Imputation Variance (v_w): {v_w:.4e}")
    print(f"  Between-Imputation Variance (v_b):{v_b:.4e}")
    print(f"  Total Variance (v_t):             {v_t:.4e}")
    print(f"  Standard Error:                   ${se / 1e9:,.3f} Billion")
    print(
        f"  99% Confidence Interval:          "
        f"${ci_lo / 1e9:,.3f} B  -  ${ci_hi / 1e9:,.3f} B"
    )

    pooled_df = pd.DataFrame({
        "Metric": [
            "Pooled Aggregate National Value ($)",
            "Pooled Aggregate National Value ($B)",
            "Within-Imputation Variance (v_w)",
            "Between-Imputation Variance (v_b)",
            "Total Variance (v_t)",
            "Standard Error ($)",
            "95% CI Lower ($B)",
            "95% CI Upper ($B)",
        ] + [f"Dataset {i} Aggregate ($B)" for i in range(1, m_datasets + 1)],
        "Value": [
            f"{q_bar:,.2f}",
            f"{q_bar / 1e9:,.3f}",
            f"{v_w:.4e}",
            f"{v_b:.4e}",
            f"{v_t:.4e}",
            f"{se:,.2f}",
            f"{ci_lo / 1e9:,.3f}",
            f"{ci_hi / 1e9:,.3f}",
        ] + [f"{q / 1e9:,.3f}" for q in aggregates],
    })

    pooled_df.to_csv(out_csv, index=False)
    print(f"\n  [OK] Saved -> {out_csv}")


# === 4. EXECUTION ===

if __name__ == "__main__":
    run_pooling(IN_DIR, OUT_CSV, M)
