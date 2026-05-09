# Purpose: Diagnostic merge of Step 2 TMKs against the Honolulu cadastral CSV
#          to verify TMK format compatibility before Step 5 geographic analysis.
# Inputs:  Bulk Tests/python/Target_Golf_Parcels_List.csv             (Step 2 output)
#          00 - Data Sources/Honolulu/All_Parcels_-4613852522541990741.csv
#          00 - Data Sources/Honolulu/Cadastral_2020_8454252231025374231.csv
# Outputs: (console diagnostic output only)


# === 1. IMPORTS ===

import pathlib
import re
import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR        = pathlib.Path(__file__).parent
WORK_DIR          = SCRIPT_DIR.parents[2]
HONOLULU_DATA_DIR = WORK_DIR / "00 - Data Sources" / "Honolulu"
TMK_LIST_PATH     = SCRIPT_DIR / "Target_Golf_Parcels_List.csv"

TAX_CSV_CANDIDATES = [
    HONOLULU_DATA_DIR / "All_Parcels_-4613852522541990741.csv",
    HONOLULU_DATA_DIR / "Cadastral_2020_8454252231025374231.csv",
]


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

def main():
    print("\n" + "=" * 70)
    print("Phase 5 - Step 4: Tax Assessment Merge (Diagnostic)")
    print("=" * 70 + "\n")

    if not TMK_LIST_PATH.exists():
        print(f"[FATAL] TMK list not found. Run Step 2 first.\n  {TMK_LIST_PATH}")
        raise SystemExit(1)

    tmk_df = pd.read_csv(TMK_LIST_PATH)
    tmk_df.rename(columns={tmk_df.columns[0]: "TMK"}, inplace=True)
    tmk_df["TMK_clean"] = tmk_df["TMK"].astype(str).str.replace(r"[^0-9]", "", regex=True)

    tax_file_to_use = next((p for p in TAX_CSV_CANDIDATES if p.exists()), None)
    if tax_file_to_use is None:
        candidates = "\n  ".join(str(p) for p in TAX_CSV_CANDIDATES)
        print(f"[FATAL] No Honolulu cadastral CSV found. Expected:\n  {candidates}")
        raise SystemExit(1)

    tax_data = pd.read_csv(tax_file_to_use)

    print("--- DIAGNOSTIC INFO ---")
    print("All Columns in Honolulu CSV:")
    print(list(tax_data.columns))

    tmk_col = next(
        (c for c in tax_data.columns if re.search(r"(?i)^tmk$|parcel_id|tax_map_key|pin", c)),
        None,
    )
    if tmk_col is None:
        print("[FATAL] No TMK column identified in cadastral CSV.")
        raise SystemExit(1)

    tax_data["TMK_clean"] = tax_data[tmk_col].astype(str).str.replace(r"[^0-9]", "", regex=True)

    print("\nFirst 5 TMKs from Step 2 (Target Golf Courses):")
    print(tmk_df["TMK_clean"].head().tolist())

    print("\nFirst 5 TMKs from Honolulu CSV:")
    print(tax_data["TMK_clean"].head().tolist())
    print("-----------------------\n")

    step2_lens = tmk_df["TMK_clean"].str.len()
    csv_lens   = tax_data["TMK_clean"].dropna().str.len()

    # [AUTO-FIX] Honolulu TMK digit-length mismatch:
    #   8-digit format = Z S PPP QQQ  (3-digit parcel field)
    #   9-digit format = Z S PPP QQQQ (4-digit parcel field, trailing 0 for non-CPR parcels)
    #   Conversion: append '0' to the shorter set to align parcel fields.
    # [REVIEW NEEDED] R version incorrectly prepended '1' for this case; corrected here.
    if (step2_lens == 8).all() and (csv_lens == 9).all():
        print("[AUTO-FIX] Step 2 TMKs are 8-digit; appending '0' to match 9-digit CSV format...")
        tmk_df["TMK_clean"] = tmk_df["TMK_clean"] + "0"
    elif (step2_lens == 9).all() and (csv_lens == 8).all():
        print("[AUTO-FIX] CSV TMKs are 8-digit; appending '0' to match 9-digit Step 2 format...")
        tax_data["TMK_clean"] = tax_data["TMK_clean"] + "0"

    merged_data   = tmk_df.merge(tax_data, on="TMK_clean", how="inner")
    matched_count = len(merged_data)

    print(
        f"  Successfully matched {matched_count} out of {len(tmk_df)} TMKs "
        f"({matched_count / len(tmk_df) * 100:.1f}%)."
    )

    if matched_count > 0:
        print("\n[SUCCESS] The TMKs are now matching! Please paste this output back "
              "so I can see the column names and write the final Step 5 script.")
    else:
        print("\n[FAIL] Still 0 matches. Please paste this output back "
              "so I can analyze the TMK formats.")


if __name__ == "__main__":
    main()
