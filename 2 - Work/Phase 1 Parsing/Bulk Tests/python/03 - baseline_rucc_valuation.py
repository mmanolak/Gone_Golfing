# Purpose: Fetch 2023 USDA RUCC codes, classify counties as Urban (RUCC 1–3) or
#          Rural (RUCC 4–9), and assign Baseline_Value_Per_Acre accordingly.
# Inputs:  Bulk Tests/python/Py_Phase1_Valuation_Joined_Golf_Courses.csv
#          https://www.ers.usda.gov/media/5768/2023-rural-urban-continuum-codes.csv
# Outputs: Bulk Tests/python/Py_Phase1_Baseline_Golf_Valuation.csv


# === 1. LIBRARIES ===

from pathlib import Path

import numpy as np
import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = Path(__file__).parent

GOLF_IN  = SCRIPT_DIR / "Py_Phase1_Valuation_Joined_Golf_Courses.csv"
RUCC_URL = "https://www.ers.usda.gov/media/5768/2023-rural-urban-continuum-codes.csv?v=98246"
OUT_CSV  = SCRIPT_DIR / "Py_Phase1_Baseline_Golf_Valuation.csv"


# === 3. EXECUTION ===

def main():
    if not GOLF_IN.exists():
        raise FileNotFoundError(f"Input file not found: {GOLF_IN}")

    courses_df = pd.read_csv(GOLF_IN)
    courses_df["FIPS"] = (courses_df["FIPS"].astype(str)
                          .str.replace(r"\.0$", "", regex=True).str.zfill(5))

    rucc_df = pd.read_csv(RUCC_URL, encoding="latin1")

    # RUCC source is long-format with multiple attributes per FIPS — isolate RUCC_2023 to get one code per county
    rucc_df = rucc_df[rucc_df["Attribute"] == "RUCC_2023"].copy()
    rucc_df["RUCC_2023"] = pd.to_numeric(rucc_df["Value"], errors="coerce")
    rucc_df["FIPS"] = (rucc_df["FIPS"].astype(str)
                       .str.replace(r"\.0$", "", regex=True).str.zfill(5))
    rucc_df = rucc_df[["FIPS", "RUCC_2023"]].drop_duplicates(subset=["FIPS"])

    courses_df = courses_df.merge(rucc_df, on="FIPS", how="left")

    courses_df["county_type"] = np.where(
        courses_df["RUCC_2023"].isin([1, 2, 3]), "Urban",
        np.where(courses_df["RUCC_2023"].between(4, 9), "Rural", None)
    )

    courses_df["Baseline_Value_Per_Acre"] = np.where(
        courses_df["county_type"] == "Urban",  courses_df["FHFA_Res_Value_Per_Acre"],
        np.where(
            courses_df["county_type"] == "Rural", courses_df["USDA_Ag_Value_Per_Acre"],
            np.nan
        )
    )

    urban        = (courses_df["county_type"] == "Urban").sum()
    rural        = (courses_df["county_type"] == "Rural").sum()
    unclassified = courses_df["county_type"].isna().sum()
    missing_base = courses_df["Baseline_Value_Per_Acre"].isna().sum()
    bv           = courses_df["Baseline_Value_Per_Acre"].dropna()

    print("\n=== OUTPUT STATISTICS ===")
    print(f"  Urban courses:            {urban:,}")
    print(f"  Rural courses:            {rural:,}")
    print(f"  Unclassified (no RUCC):   {unclassified:,}")
    print(f"  Missing Baseline value:   {missing_base:,}  (MICE imputation target)")
    print(f"\n  Baseline_Value_Per_Acre summary:")
    print(f"    Min:    ${bv.min():>14,.2f}")
    print(f"    Median: ${bv.median():>14,.2f}")
    print(f"    Mean:   ${bv.mean():>14,.2f}")
    print(f"    Max:    ${bv.max():>14,.2f}")

    courses_df.to_csv(OUT_CSV, index=False)
    print(f"\n  [OK] Saved -> {OUT_CSV}")


if __name__ == "__main__":
    main()
