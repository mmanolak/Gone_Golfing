# Purpose: Left-join USDA county ag-land values and FHFA residential land prices
#          onto spatially-joined golf course records by FIPS code.
# Inputs:  Bulk Tests/python/Py_Phase1_Spatial_Joined_Golf_Courses.csv
#          00 - Data Sources/Original Data/2022 - USDA County Data - Ag Use.csv
#          00 - Data Sources/Original Data/2024 - FHFA June 20 Land Prices.xlsx
# Outputs: Bulk Tests/python/Py_Phase1_Valuation_Joined_Golf_Courses.csv


# === 1. LIBRARIES ===

from pathlib import Path

import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = Path(__file__).parent
ROOT_DIR   = SCRIPT_DIR.parent.parent.parent
DATA_DIR   = ROOT_DIR / "00 - Data Sources" / "Original Data"

GOLF_IN = SCRIPT_DIR / "Py_Phase1_Spatial_Joined_Golf_Courses.csv"
USDA_IN = DATA_DIR   / "2022 - USDA County Data - Ag Use.csv"
FHFA_IN = DATA_DIR   / "2024 - FHFA June 20 Land Prices.xlsx"
OUT_CSV = SCRIPT_DIR / "Py_Phase1_Valuation_Joined_Golf_Courses.csv"


# === 3. FUNCTIONS ===


# === 4. EXECUTION ===

def main():
    for path in (GOLF_IN, USDA_IN, FHFA_IN):
        if not path.exists():
            raise FileNotFoundError(f"Input file not found: {path}")

    courses_df = pd.read_csv(GOLF_IN)
    courses_df["FIPS"] = (courses_df["FIPS"]
                          .astype(str)
                          .str.replace(r"\.0$", "", regex=True)
                          .str.zfill(5))

    usda_df = pd.read_csv(USDA_IN)
    usda_df = usda_df[
        usda_df["Data Item"] == "AG LAND, INCL BUILDINGS - ASSET VALUE, MEASURED IN $ / ACRE"
    ].copy()

    # Build 5-digit FIPS from separate State ANSI (2-digit) and County ANSI (3-digit) columns
    usda_df["State ANSI"]  = (usda_df["State ANSI"].astype(str)
                               .str.replace(r"\.0$", "", regex=True).str.zfill(2))
    usda_df["County ANSI"] = (usda_df["County ANSI"].astype(str)
                               .str.replace(r"\.0$", "", regex=True).str.zfill(3))
    usda_df["FIPS"] = usda_df["State ANSI"] + usda_df["County ANSI"]

    # Strip commas and coerce USDA suppression codes (e.g., "(D)") to NaN
    usda_df["USDA_Ag_Value_Per_Acre"] = pd.to_numeric(
        usda_df["Value"].astype(str).str.replace(",", ""), errors="coerce"
    )
    usda_df = (usda_df[["FIPS", "USDA_Ag_Value_Per_Acre"]]
               .dropna(subset=["USDA_Ag_Value_Per_Acre"])
               .drop_duplicates(subset=["FIPS"]))

    fhfa_df = pd.read_excel(FHFA_IN, sheet_name="Panel Counties", skiprows=1)
    fhfa_df = fhfa_df[fhfa_df["Year"] == 2022].copy()

    fhfa_df["FIPS"] = (fhfa_df["FIPS"].astype(str)
                        .str.replace(r"\.0$", "", regex=True).str.zfill(5))

    # Column name contains a literal newline in the source file
    as_is_col = "Land Value\n(Per Acre, As-Is)"
    fhfa_df = (fhfa_df[["FIPS", as_is_col]]
               .rename(columns={as_is_col: "FHFA_Res_Value_Per_Acre"})
               .drop_duplicates(subset=["FIPS"]))
    fhfa_df["FHFA_Res_Value_Per_Acre"] = pd.to_numeric(
        fhfa_df["FHFA_Res_Value_Per_Acre"], errors="coerce"
    )

    courses_df = (courses_df
                  .merge(usda_df, on="FIPS", how="left")
                  .merge(fhfa_df, on="FIPS", how="left"))

    n        = len(courses_df)
    usda_hit = courses_df["USDA_Ag_Value_Per_Acre"].notna().sum()
    fhfa_hit = courses_df["FHFA_Res_Value_Per_Acre"].notna().sum()

    print("\n=== OUTPUT STATISTICS ===")
    print(f"  Total golf courses:   {n:,}")
    print(f"  USDA match rate:      {usda_hit:,} / {n:,}  ({usda_hit/n:.2%})")
    print(f"  FHFA match rate:      {fhfa_hit:,} / {n:,}  ({fhfa_hit/n:.2%})")
    print(f"\n  First 5 rows:")
    print(courses_df[["Course_Name", "FIPS", "County_Name", "State_Abbr",
                       "USDA_Ag_Value_Per_Acre", "FHFA_Res_Value_Per_Acre"]]
          .head().to_string(index=False))

    courses_df.to_csv(OUT_CSV, index=False)
    print(f"\n  [OK] Saved -> {OUT_CSV}")


if __name__ == "__main__":
    main()
