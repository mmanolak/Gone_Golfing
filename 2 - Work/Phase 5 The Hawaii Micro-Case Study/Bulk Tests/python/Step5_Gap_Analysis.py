# Purpose: Merge Step 2 TMKs with the Honolulu cadastral CSV to extract TMK
#          zones and map each zone to its official Oahu geographic district.
# Inputs:  Bulk Tests/python/Target_Golf_Parcels_List.csv               (Step 2 output)
#          00 - Data Sources/Honolulu/All_Parcels_-4613852522541990741.csv
# Outputs: Bulk Tests/python/Phase5_Step5_Geographic_Breakdown.csv


# === 1. IMPORTS ===

import pathlib
import re
import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR        = pathlib.Path(__file__).parent
WORK_DIR          = SCRIPT_DIR.parents[2]
HONOLULU_DATA_DIR = WORK_DIR / "00 - Data Sources" / "Honolulu"
TMK_LIST_PATH     = SCRIPT_DIR / "Target_Golf_Parcels_List.csv"
TAX_CSV_PATH      = HONOLULU_DATA_DIR / "All_Parcels_-4613852522541990741.csv"
OUT_CSV           = SCRIPT_DIR / "Phase5_Step5_Geographic_Breakdown.csv"

DISTRICT_MAP = {
    "1": "Honolulu (Urban Core)",
    "2": "Honolulu (East/Anomalies)",
    "3": "Honolulu (Anomalies)",
    "4": "Koolaupoko (Kailua/Kaneohe)",
    "5": "Koolauloa (North/East)",
    "6": "Waialua (North Shore)",
    "7": "Wahiawa (Central)",
    "8": "Waianae (West)",
    "9": "Ewa (Kapolei/Pearl City)",
}


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

def main():
    print("\n" + "=" * 70)
    print("Phase 5 - Step 5: Geographic Concentration Breakdown")
    print("=" * 70 + "\n")

    if not TMK_LIST_PATH.exists():
        print(f"[FATAL] TMK list not found. Run Step 2 first.\n  {TMK_LIST_PATH}")
        raise SystemExit(1)
    if not TAX_CSV_PATH.exists():
        print(f"[FATAL] Cadastral CSV not found:\n  {TAX_CSV_PATH}")
        raise SystemExit(1)

    tmk_df = pd.read_csv(TMK_LIST_PATH)
    tmk_df.rename(columns={tmk_df.columns[0]: "TMK"}, inplace=True)
    tmk_df["TMK_clean"] = tmk_df["TMK"].astype(str).str.replace(r"[^0-9]", "", regex=True)

    tax_data = pd.read_csv(TAX_CSV_PATH)
    tmk_col  = next(
        (c for c in tax_data.columns if re.search(r"(?i)^tmk$", c)),
        None,
    )
    if tmk_col is None:
        print("[FATAL] No TMK column identified in cadastral CSV.")
        print("Available columns:", list(tax_data.columns))
        raise SystemExit(1)

    tax_data["TMK_clean"] = tax_data[tmk_col].astype(str).str.replace(r"[^0-9]", "", regex=True)

    step2_lens = tmk_df["TMK_clean"].str.len()
    csv_lens   = tax_data["TMK_clean"].dropna().str.len()

    # 8-digit format = Z S PPP QQQ  (3-digit parcel field)
    # 9-digit format = Z S PPP QQQQ (4-digit parcel field, trailing 0 for non-CPR parcels)
    if (step2_lens == 8).all() and (csv_lens == 9).all():
        tmk_df["TMK_clean"] = tmk_df["TMK_clean"] + "0"
    elif (step2_lens == 9).all() and (csv_lens == 8).all():
        tax_data["TMK_clean"] = tax_data["TMK_clean"] + "0"

    merged_data = tmk_df.merge(tax_data, on="TMK_clean", how="inner")

    merged_data["Zone_Code"] = merged_data["Zone"].astype(str)
    merged_data["District_Name"] = merged_data["Zone_Code"].map(DISTRICT_MAP).fillna(
        "Zone " + merged_data["Zone_Code"]
    )

    geo_summary = (
        merged_data
        .groupby(["Zone_Code", "District_Name"], as_index=False)
        .agg(Parcel_Count=("Zone_Code", "count"))
        .assign(Pct_of_Total_Parcels=lambda df: df["Parcel_Count"] / df["Parcel_Count"].sum() * 100)
        .sort_values("Parcel_Count", ascending=False)
        .reset_index(drop=True)
    )

    print(f"{'Zone':<5} {'Geographic District':<35} {'Parcel Count':<15} {'% of Parcels':<15}")
    print("-" * 70)
    for _, row in geo_summary.iterrows():
        print(
            f"{row['Zone_Code']:<5} {row['District_Name']:<35} "
            f"{int(row['Parcel_Count']):<15} {row['Pct_of_Total_Parcels']:.1f}%"
        )
    print("-" * 70)
    print(f"{'':5} {'TOTAL':<35} {int(geo_summary['Parcel_Count'].sum()):<15} 100.0%")
    print("-" * 70)

    geo_summary.to_csv(OUT_CSV, index=False)
    print(f"\n[+] Geographic Breakdown saved -> {OUT_CSV.name}")
    print("\n[DONE] Step 5 Complete. Phase 5 is fully finished!")


if __name__ == "__main__":
    main()
