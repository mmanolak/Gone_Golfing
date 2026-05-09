# Purpose: Calculate the total physical footprint of U.S. golf courses (acres)
#          across the 5 MICE-imputed datasets and break it down by county_type
#          (Urban / Rural).  Acreage is a fixed spatial measurement, not a
#          modelled quantity, so pooling is done by simple averaging across
#          imputations; between-imputation variance is reported for transparency.
# Inputs:  Phase 3 Economic Merge and MICE Imputation/Data/python/Py_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/python/Py_National_Acreage_Summary.csv


# === 1. IMPORTS ===

from pathlib import Path

import numpy as np
import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR  = Path(__file__).parent
IMPUTED_DIR = (SCRIPT_DIR / ".." / ".." / "Data" / "python").resolve()
OUT_CSV     = SCRIPT_DIR / "Py_National_Acreage_Summary.csv"

M = 5


# === 3. FUNCTIONS ===

def pool_acreage(x: np.ndarray) -> dict:
    """Pool a per-imputation acreage vector by simple averaging.
    CI uses between-imputation variance only (within-variance = 0 for acreage).
    """
    q_bar = x.mean()
    v_b   = x.var(ddof=1)
    se    = np.sqrt(v_b + v_b / len(x))
    return {
        "mean":  q_bar,
        "sd_b":  np.sqrt(v_b),
        "ci_lo": q_bar - 1.96 * se,
        "ci_hi": q_bar + 1.96 * se,
    }


# === 4. EXECUTION ===

def main():
    print("\n" + "=" * 70)
    print("Phase 3 — National Acreage Summary")
    print("=" * 70 + "\n")

    # ── Step 1: Load datasets and compute per-imputation totals ───────────────
    print("-" * 70)
    print("[Step 1] Loading imputed datasets and computing acreage totals...\n")

    national_totals = np.zeros(M)
    by_type_frames  = []

    for i in range(1, M + 1):
        path = IMPUTED_DIR / f"Py_Imputed_Dataset_{i}.csv"
        if not path.exists():
            raise SystemExit(f"[FATAL] File not found:\n  {path}")

        df = pd.read_csv(path)

        national_totals[i - 1] = df["osm_acreage"].sum()

        type_sums = (
            df.groupby("county_type", as_index=False)["osm_acreage"]
            .sum()
            .rename(columns={"osm_acreage": "acreage"})
        )
        type_sums["imputation"] = i
        by_type_frames.append(type_sums)

        urban = type_sums.loc[type_sums["county_type"] == "Urban", "acreage"].iat[0]
        rural = type_sums.loc[type_sums["county_type"] == "Rural", "acreage"].iat[0]
        print(
            f"  Dataset {i}:  {round(national_totals[i - 1]):>12,} acres"
            f"  ({round(urban):,} Urban / {round(rural):,} Rural)"
        )

    # ── Step 2: Pool totals ───────────────────────────────────────────────────
    print("\n" + "-" * 70)
    print("[Step 2] Pooling across imputations...\n")

    nat_pool = pool_acreage(national_totals)

    all_by_type = pd.concat(by_type_frames, ignore_index=True)
    type_pool = (
        all_by_type.groupby("county_type")["acreage"]
        .apply(lambda x: pd.Series(pool_acreage(x.to_numpy())))
        .unstack()
        .reset_index()
        .rename(columns={"mean": "pooled_acres"})
        .sort_values("pooled_acres", ascending=False)
        .reset_index(drop=True)
    )

    # ── Console output ────────────────────────────────────────────────────────
    print("=" * 70)
    print("NATIONAL ACREAGE SUMMARY — POOLED RESULTS")
    print("=" * 70)

    print(f"\n  {'NATIONAL TOTAL (all types)':<38} {'Pooled Acres'}")
    print(f"  {'-' * 38} {'-' * 20}")
    print(f"  {'Total U.S. Golf Acreage':<38} {round(nat_pool['mean']):,}")
    print(f"  {'Between-Imputation SD':<38} {nat_pool['sd_b']:,.2f}")
    print(
        f"  {'95% CI':<38} "
        f"{round(nat_pool['ci_lo']):,} - {round(nat_pool['ci_hi']):,}"
    )

    print(f"\n  {'County Type':<20} {'Pooled Acres':>15} {'SD (between)':>15} {'95% CI':>15}")
    print(f"  {'-' * 20} {'-' * 15} {'-' * 15} {'-' * 15}")
    for _, row in type_pool.iterrows():
        print(
            f"  {row['county_type']:<20} {round(row['pooled_acres']):>15,}"
            f" {row['sd_b']:>15.2f}"
            f"  {round(row['ci_lo']):,} - {round(row['ci_hi']):,}"
        )
    print("=" * 70 + "\n")

    # ── Save CSV ──────────────────────────────────────────────────────────────
    national_row = pd.DataFrame([{
        "Category":          "National Total",
        "County_Type":       "All",
        "Pooled_Acres":      round(nat_pool["mean"], 2),
        "SD_Between":        round(nat_pool["sd_b"], 4),
        "CI_95_Lower_Acres": round(nat_pool["ci_lo"], 2),
        "CI_95_Upper_Acres": round(nat_pool["ci_hi"], 2),
    }])
    type_rows = pd.DataFrame({
        "Category":          "By County Type",
        "County_Type":       type_pool["county_type"],
        "Pooled_Acres":      type_pool["pooled_acres"].round(2),
        "SD_Between":        type_pool["sd_b"].round(4),
        "CI_95_Lower_Acres": type_pool["ci_lo"].round(2),
        "CI_95_Upper_Acres": type_pool["ci_hi"].round(2),
    })
    summary_df = pd.concat([national_row, type_rows], ignore_index=True)

    summary_df.to_csv(OUT_CSV, index=False)
    print(f"  [+] Summary saved -> {OUT_CSV.name}")
    print("\n[DONE] National Acreage Summary complete.")


if __name__ == "__main__":
    main()
