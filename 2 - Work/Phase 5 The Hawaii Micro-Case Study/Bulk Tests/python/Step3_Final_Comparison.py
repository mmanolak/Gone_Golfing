# Purpose: Cross-reference Oahu golf TMKs against official parcel cadastre and
#          Phase 4 MICE-pooled opportunity cost estimates; apply spatial
#          deduplication and Rubin's Rules to produce the final comparison table.
# Inputs:  Bulk Tests/python/Target_Golf_Parcels_List.csv      (Step 2 output)
#          Bulk Tests/python/Honolulu_Parcels_Reprojected.gpkg  (Step 1 output)
#          Bulk Tests/python/Target_Golf_Polygons.gpkg          (Step 1 output)
#          Phase 4 Econometric Modeling/Data/Python/Py_Regression_Results.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/Python/Py_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/python/Phase5_Oahu_Comparison.csv


# === 1. IMPORTS ===

import pathlib
import numpy as np
import pandas as pd
import geopandas as gpd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = pathlib.Path(__file__).parent
WORK_DIR   = SCRIPT_DIR.parents[2]

TMK_LIST_PATH  = SCRIPT_DIR / "Target_Golf_Parcels_List.csv"
PARCELS_GPKG   = SCRIPT_DIR / "Honolulu_Parcels_Reprojected.gpkg"
OSM_POLYS_PATH = SCRIPT_DIR / "Target_Golf_Polygons.gpkg"
OUT_CSV        = SCRIPT_DIR / "Phase5_Oahu_Comparison.csv"

PHASE3_DATA_DIR = (
    WORK_DIR / "Phase 3 Economic Merge and MICE Imputation" / "Data" / "Python"
)
IMPUTED_PATHS = [
    PHASE3_DATA_DIR / f"Py_Imputed_Dataset_{i}.csv" for i in range(1, 6)
]
PHASE4_DATA_DIR = WORK_DIR / "Phase 4 Econometric Modeling" / "Data" / "Python"
REGRESSION_CSV  = PHASE4_DATA_DIR / "Py_Regression_Results.csv"

# Hardcoded OSM-derived footprint from Step 2 geometry (acres)
OSM_DERIVED_ACRES = 8342.28

M = 5  # number of MICE imputations

OAHU_LAT_MIN, OAHU_LAT_MAX =  21.2,   21.9
OAHU_LON_MIN, OAHU_LON_MAX = -158.5, -157.6

TAX_ROLL_CANDIDATES = [
    WORK_DIR / "00 - Data Sources" / "Honolulu" / "tax_assessment.csv",
    SCRIPT_DIR / "tax_assessment.csv",
    SCRIPT_DIR / "Honolulu_Tax_Roll.csv",
]


# === 3. FUNCTIONS ===

def add_row(rows, metric, value):
    rows.append({"Metric": metric, "Value": str(value)})


# === 4. EXECUTION ===

def main():
    print("\n" + "=" * 70)
    print("Phase 5 - Step 3: Economic Validation")
    print("=" * 70)
    print(f"\n  Script dir    : {SCRIPT_DIR}")
    print(f"  Work dir      : {WORK_DIR}")
    print(f"  TMK list      : {TMK_LIST_PATH}")
    print(f"  Parcels GPKG  : {PARCELS_GPKG}")
    print(f"  OSM Polygons  : {OSM_POLYS_PATH}")
    print(f"  Phase 3 dir   : {PHASE3_DATA_DIR}")
    print(f"  Phase 4 dir   : {PHASE4_DATA_DIR}")
    print(f"  Output        : {OUT_CSV}\n")

    required = {
        "TMK list (Step 2 output)"     : TMK_LIST_PATH,
        "Parcels GPKG (Step 1 output)" : PARCELS_GPKG,
        "OSM Polygons (Step 1 output)" : OSM_POLYS_PATH,
        "Phase 4 regression CSV"       : REGRESSION_CSV,
    }
    for label, path in required.items():
        if not path.exists():
            print(f"[FATAL] {label} not found:\n  {path}")
            raise SystemExit(1)

    missing_imp = [p for p in IMPUTED_PATHS if not p.exists()]
    if missing_imp:
        print("[FATAL] Phase 3 imputed datasets not found:")
        for p in missing_imp:
            print(f"  {p}")
        raise SystemExit(1)

    # ---- Step 1: Load TMK list ----
    print("-" * 70)
    print("[Step 1] Loading TMK list from Step 2...")
    print("-" * 70)

    tmk_df = pd.read_csv(TMK_LIST_PATH)
    tmk_df.rename(columns={tmk_df.columns[0]: "tmk"}, inplace=True)
    tmk_df["tmk"] = tmk_df["tmk"].astype(str)
    print(f"  Loaded {len(tmk_df)} TMKs.")

    # ---- Step 2: Load parcel attributes and join ----
    print("-" * 70)
    print("[Step 2] Loading parcel attributes from cadastre GPKG...")
    print("-" * 70)

    # [METHODOLOGY] gpd.read_file — spatial read of Step 1 parcel cadastre for attribute join
    parcels_attr = gpd.read_file(PARCELS_GPKG).drop(columns="geometry")

    if "tmk" in parcels_attr.columns:
        parcels_attr["tmk"] = parcels_attr["tmk"].astype(str)
    else:
        tmk_candidates = ["TMK", "tmk8num", "tmk9num", "taxpin", "parcel_uid"]
        found = next((c for c in tmk_candidates if c in parcels_attr.columns), None)
        if found is None:
            print("[FATAL] Cannot find a TMK join column in parcels GPKG.")
            raise SystemExit(1)
        parcels_attr = parcels_attr.rename(columns={found: "tmk"})
        parcels_attr["tmk"] = parcels_attr["tmk"].astype(str)

    matched_parcels = tmk_df.merge(parcels_attr, on="tmk", how="inner")
    print(f"  TMKs from Step 2:      {len(tmk_df)}")
    print(f"  Matched in cadastre:   {len(matched_parcels)}")

    area_col = None
    for candidate in ["dpp_approved_area_acres", "dpp_stated_area", "rpa_stated_area"]:
        if candidate in matched_parcels.columns and matched_parcels[candidate].notna().any():
            area_col = candidate
            break

    if area_col:
        official_area_acres = matched_parcels[area_col].sum(skipna=True)
        print(f"\n  Official area column used : {area_col}")
        print(f"  Total official area       : {official_area_acres:,.2f} acres")
    else:
        official_area_acres = float("nan")

    print(f"\n  OSM-derived legal footprint (Step 2 geometry): {OSM_DERIVED_ACRES:,.2f} acres")

    # ---- Step 3: Tax assessment roll (optional) ----
    print("-" * 70)
    print("[Step 3] Tax assessment roll (optional)...")
    print("-" * 70)

    tax_roll_df  = None
    assessed_val = float("nan")

    tax_roll_path = next((p for p in TAX_ROLL_CANDIDATES if p.exists()), None)
    if tax_roll_path:
        tax_roll_df = pd.read_csv(tax_roll_path)
        print(f"  Loaded {len(tax_roll_df):,} tax records.")
    else:
        print("  Skipping tax assessment; dollar comparison will use model values only.")

    if tax_roll_df is not None:
        tax_tmk_col = next(
            (c for c in ["tmk", "TMK", "TAX_MAP_KEY", "parcel_id"] if c in tax_roll_df.columns),
            None,
        )
        val_col = next(
            (c for c in ["assessed_land_value", "ASSESSED_LAND_VALUE", "land_value",
                          "total_assessed_value"] if c in tax_roll_df.columns),
            None,
        )
        if tax_tmk_col and val_col:
            tax_roll_df[tax_tmk_col] = tax_roll_df[tax_tmk_col].astype(str)
            tax_matched  = tmk_df.merge(tax_roll_df, left_on="tmk", right_on=tax_tmk_col, how="inner")
            assessed_val = tax_matched[val_col].sum(skipna=True)
            print(f"\n  Total assessed value:   ${assessed_val:,.2f}")

    # ---- Step 4: Load Phase 4 model output & Spatial Deduplication ----
    print("-" * 70)
    print("[Step 4] Loading Phase 4 model output & Spatial Deduplication...")
    print("-" * 70)

    oahu_estimates = []
    for i, path in enumerate(IMPUTED_PATHS, start=1):
        df_i = pd.read_csv(path)
        # [METHODOLOGY] lat/lon bounding box — Oahu extents used to pre-filter national
        #               dataset before spatial deduplication; bounds from island geography
        oahu_mask = (
            df_i["Longitude"].notna() & df_i["Latitude"].notna() &
            (df_i["Latitude"]  >= OAHU_LAT_MIN) & (df_i["Latitude"]  <= OAHU_LAT_MAX) &
            (df_i["Longitude"] >= OAHU_LON_MIN) & (df_i["Longitude"] <= OAHU_LON_MAX)
        )
        df_oahu = df_i[oahu_mask].copy()
        df_oahu["Total_Opportunity_Cost"] = df_oahu["osm_acreage"] * df_oahu["Baseline_Value_Per_Acre"]
        df_oahu["imputation"] = i
        oahu_estimates.append(df_oahu)

    oahu_all = pd.concat(oahu_estimates, ignore_index=True)
    sizes    = ", ".join(str(len(d)) for d in oahu_estimates)
    print(f"  Oahu courses before deduplication (per imputation): {sizes}")

    print("\n  Applying Spatial Deduplication using true OSM Polygons...")

    # [METHODOLOGY] gpd.read_file — spatial read of Oahu golf polygons for deduplication
    osm_polys_geo = gpd.read_file(OSM_POLYS_PATH)
    osm_polys_geo["poly_id"] = range(1, len(osm_polys_geo) + 1)

    unique_courses = (
        oahu_all.groupby(["Longitude", "Latitude"])
        .agg(Holes=("Holes", "max"))
        .reset_index()
    )

    # [METHODOLOGY] gpd.GeoDataFrame — convert deduplicated course coordinates to spatial points
    courses_geo = gpd.GeoDataFrame(
        unique_courses,
        geometry=gpd.points_from_xy(unique_courses["Longitude"], unique_courses["Latitude"]),
        crs=4326,
    )
    # [METHODOLOGY] .to_crs — reproject course points to match OSM CRS
    courses_geo = courses_geo.to_crs(osm_polys_geo.crs)

    # [METHODOLOGY] gpd.sjoin_nearest — nearest-neighbor match to OSM polygons;
    #               mirrors Phase 2's fallback matching logic
    joined_nearest = gpd.sjoin_nearest(
        courses_geo.reset_index(drop=True),
        osm_polys_geo[["poly_id", "geometry"]],
        how="left",
        distance_col="nearest_dist",
    ).drop_duplicates(subset=courses_geo.index.name or courses_geo.reset_index().index.name
                      if False else None).groupby(level=0).first()

    # [METHODOLOGY] 500 m cap — only assign a polygon if within 500 m of the point;
    #               threshold mirrors Phase 2 spatial tolerance for point-to-polygon matching
    assigned_poly = np.where(
        joined_nearest["nearest_dist"] <= 500,
        joined_nearest["poly_id"],
        np.nan,
    )

    group_ids = [
        f"orphan_{i}" if np.isnan(p) else str(int(p))
        for i, p in enumerate(assigned_poly)
    ]

    dedup_df = unique_courses.copy()
    dedup_df["group_id"] = group_ids
    dedup_df["Holes"]    = joined_nearest["Holes"].values

    master_keep_list = (
        dedup_df
        .sort_values(["group_id", "Holes"], ascending=[True, False])
        .drop_duplicates(subset=["group_id"])
        [["Longitude", "Latitude", "Holes"]]
        .reset_index(drop=True)
    )

    print(f"  Unique Oahu courses after spatial deduplication: {len(master_keep_list)}")

    oahu_deduped_list = []
    for i in range(1, M + 1):
        df_i = oahu_all[oahu_all["imputation"] == i].merge(
            master_keep_list, on=["Longitude", "Latitude", "Holes"], how="inner"
        )
        oahu_deduped_list.append(df_i)

    oahu_per_course = (
        pd.concat(oahu_deduped_list, ignore_index=True)
        .groupby(["Longitude", "Latitude"])
        .agg(
            n_imputations         = ("imputation",            "count"),
            mean_final_acreage    = ("osm_acreage",           "mean"),
            mean_baseline_val     = ("Baseline_Value_Per_Acre","mean"),
            mean_opportunity_cost = ("Total_Opportunity_Cost", "mean"),
            Holes                 = ("Holes",                 "first"),
            **({
                "county_type": ("county_type", "first")
            } if "county_type" in oahu_all.columns else {}),
        )
        .reset_index()
        .sort_values("Longitude")
    )

    # [METHODOLOGY] Rubin's Rules — pooling across M imputations; simplified formula
    #               using total-level aggregates (see Phase 4 for full coefficient pooling)
    oahu_agg_dedup = [d["Total_Opportunity_Cost"].sum() for d in oahu_deduped_list]
    q_bar = np.mean(oahu_agg_dedup)
    v_w   = np.mean([d["Total_Opportunity_Cost"].var(ddof=1) for d in oahu_deduped_list])
    v_b   = np.var(oahu_agg_dedup, ddof=1)
    v_t   = v_w + v_b + v_b / M
    se    = np.sqrt(v_t)
    ci_lo = q_bar - 1.96 * se
    ci_hi = q_bar + 1.96 * se

    print(
        f"\nDeduplicated Pooled Oahu Opportunity Cost: "
        f"${q_bar/1e9:.3f}B (95% CI: ${ci_lo/1e9:.3f}B - ${ci_hi/1e9:.3f}B)"
    )

    # ---- Step 5: Build comparison table ----
    print("-" * 70)
    print("[Step 5] Building comparison table...")
    print("-" * 70)

    rows = []
    add_row(rows, "Total Golf Courses (Oahu, OSM polygons)", len(osm_polys_geo))
    add_row(rows, "Total Unique TMKs (Step 2)",             f"{len(tmk_df):,}")
    add_row(rows, "TMKs Matched in Cadastre",               f"{len(matched_parcels):,}")
    add_row(rows, "OSM-Derived Legal Footprint (acres)",    f"{OSM_DERIVED_ACRES:,.2f}")

    for i, val in enumerate(oahu_agg_dedup, start=1):
        add_row(rows, f"Oahu Opportunity Cost - Imputation {i} ($B)", f"{val/1e9:.3f}")

    add_row(rows, "Pooled Oahu Opportunity Cost - q_bar ($B)", f"{q_bar/1e9:.3f}")
    add_row(rows, "Standard Error ($B)",                        f"{se/1e9:.3f}")
    add_row(rows, "95% CI Lower ($B)",                          f"{ci_lo/1e9:.3f}")
    add_row(rows, "95% CI Upper ($B)",                          f"{ci_hi/1e9:.3f}")

    if not np.isnan(assessed_val) and assessed_val > 0:
        add_row(rows, "Total Official Assessed Value ($B)", f"{assessed_val/1e9:.3f}")
        gap_ratio = q_bar / assessed_val
        add_row(rows, "Gap Ratio (Modelled / Assessed)",    f"{gap_ratio:.4f}")

    # ---- Step 6: Print and save ----
    comparison_df = pd.DataFrame(rows)

    print("=" * 70)
    print("PHASE 5 ECONOMIC VALIDATION - RESULTS")
    print("=" * 70)
    for _, row in comparison_df.iterrows():
        print(f"  {row['Metric']:<55} {row['Value']}")
    print("=" * 70)

    comparison_df.to_csv(OUT_CSV, index=False)
    print(f"\n[+] Comparison table saved -> {OUT_CSV.as_posix()}")

    print(
        f"\nPer-Course Summary ({len(oahu_per_course)} Oahu courses, "
        f"averaged across {M} imputations):"
    )
    print(f"  {'Latitude':<12} {'Longitude':<12} {'Holes':<10} {'Mean Acreage':<18} Mean Opp. Cost ($M)")
    print("-" * 70)
    for _, r in oahu_per_course.iterrows():
        print(
            f"  {r['Latitude']:<12.4f} {r['Longitude']:<12.4f} "
            f"{str(r['Holes']):<10} {r['mean_final_acreage']:<18.1f} "
            f"${r['mean_opportunity_cost']/1e6:.2f}M"
        )

    print("\n[DONE] Step 3 Complete.")


if __name__ == "__main__":
    main()
