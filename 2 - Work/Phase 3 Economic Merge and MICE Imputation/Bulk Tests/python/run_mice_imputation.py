# Purpose: Run MICE imputation (m=5, LightGBM Random Forest) on the Phase 2
#          acreage-matched dataset to fill missing osm_acreage and
#          Baseline_Value_Per_Acre values.
# Inputs:  Phase 2 Spatial Polygons and True Acreage/
#            Py_Phase2_Acreage_Matched.csv
# Outputs: Bulk Tests/python/Py_Imputed_Dataset_{1..5}.csv


# === 1. LIBRARIES ===

import multiprocessing
import pathlib

import miceforest as mf
import numpy as np
import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = pathlib.Path(__file__).parent
INPUT_CSV  = (
    SCRIPT_DIR.parents[2]
    / "Phase 2 Spatial Polygons and True Acreage"
    / "Py_Phase2_Acreage_Matched.csv"
)
OUT_DIR = SCRIPT_DIR

M             = 5
IMPUTE_COLS   = ["osm_acreage", "Baseline_Value_Per_Acre"]
PREDICTOR_COLS = ["Holes", "Course_Type", "county_type", "Longitude", "Latitude"]

# Reserve one core for the OS; caps at 23 on a 24-thread 3900XT
N_CORES = max(1, multiprocessing.cpu_count() - 1)


# === 3. FUNCTIONS ===

def run_imputation(input_csv, out_dir, m_datasets=5):
    # 1. Load ----------------------------------------------------------------
    print("--- 1  Loading Phase 2 acreage-matched dataset ---")

    if not input_csv.exists():
        raise FileNotFoundError(f"Input file not found: {input_csv}")

    acreage_df = pd.read_csv(input_csv)
    print(f"    Rows: {len(acreage_df):,}")
    print(
        f"    Missing osm_acreage:            "
        f"{acreage_df['osm_acreage'].isna().sum():,}"
    )
    print(
        f"    Missing Baseline_Value_Per_Acre: "
        f"{acreage_df['Baseline_Value_Per_Acre'].isna().sum():,}"
    )

    # 2. Prepare -------------------------------------------------------------
    print("--- 2  Preparing imputation frame ---")

    acreage_df["Holes"]       = pd.to_numeric(acreage_df["Holes"], errors="coerce")
    acreage_df["Course_Type"] = acreage_df["Course_Type"].astype("category")
    acreage_df["county_type"] = acreage_df["county_type"].astype("category")

    model_cols = PREDICTOR_COLS + IMPUTE_COLS
    imp_df = acreage_df[model_cols].copy()

    # 3. Run miceforest -------------------------------------------------------
    print(
        f"--- 3  Running miceforest "
        f"(m={m_datasets}, LightGBM backend, n_jobs={N_CORES}) ---"
    )
    # [METHODOLOGY] miceforest MICE — LightGBM Random Forest, m=5 datasets,
    #               random_state=42 for reproducibility (Van Buuren 2018)
    imputed_list = mf.ImputationKernel(
        data=imp_df,
        num_datasets=m_datasets,
        random_state=42,
    )
    # [METHODOLOGY] 5 iterations is standard; n_jobs parallelises LightGBM trees
    imputed_list.mice(iterations=5, verbose=True, n_jobs=N_CORES)

    # 4. Extract & save each imputed dataset ---------------------------------
    print(f"\n--- 4  Saving {m_datasets} imputed datasets ---")
    for i in range(m_datasets):
        completed = imputed_list.complete_data(dataset=i)

        completed["osm_acreage"] = completed["osm_acreage"].clip(lower=0)
        completed["Baseline_Value_Per_Acre"] = (
            completed["Baseline_Value_Per_Acre"].clip(lower=0)
        )

        out = acreage_df.copy()
        out["osm_acreage"] = completed["osm_acreage"].values
        out["Baseline_Value_Per_Acre"] = completed["Baseline_Value_Per_Acre"].values

        fname = out_dir / f"Py_Imputed_Dataset_{i + 1}.csv"
        out.to_csv(fname, index=False)
        print(f"    [OK] {fname}")

    # 5. Verification report (Dataset 1) -------------------------------------
    ds1 = pd.read_csv(out_dir / "Py_Imputed_Dataset_1.csv")

    print("\n=== IMPUTATION VERIFICATION (Dataset 1) ===")
    print(f"  Method: miceforest v{mf.__version__} (LightGBM Random Forest)")
    print(f"  Datasets generated:     {m_datasets}")
    print(f"  Iterations per dataset: 5")

    for col in IMPUTE_COLS:
        s = ds1[col]
        print(f"\n  {col}:")
        print(f"    Missing:  {s.isna().sum()}")
        print(f"    Min:      {s.min():>14,.2f}")
        print(f"    Median:   {s.median():>14,.2f}")
        print(f"    Mean:     {s.mean():>14,.2f}")
        print(f"    Max:      {s.max():>14,.2f}")
        print(f"    Negative: {(s < 0).sum()}")


# === 4. EXECUTION ===

if __name__ == "__main__":
    run_imputation(INPUT_CSV, OUT_DIR, M)
