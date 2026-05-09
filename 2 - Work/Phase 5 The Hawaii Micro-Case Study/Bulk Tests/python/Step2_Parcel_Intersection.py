# Purpose: Intersect Oahu OSM golf polygons with Honolulu parcel cadastre to
#          extract TMK identifiers and total legal footprint area.
# Inputs:  Bulk Tests/python/Target_Golf_Polygons.gpkg        (Step 1 output)
#          Bulk Tests/python/Honolulu_Parcels_Reprojected.gpkg (Step 1 output)
# Outputs: Bulk Tests/python/Target_Golf_Parcels_List.csv


# === 1. IMPORTS ===

import pathlib
import geopandas as gpd
import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR       = pathlib.Path(__file__).parent
TARGET_GOLF_PATH = SCRIPT_DIR / "Target_Golf_Polygons.gpkg"
PARCELS_PATH     = SCRIPT_DIR / "Honolulu_Parcels_Reprojected.gpkg"
OUT_CSV          = SCRIPT_DIR / "Target_Golf_Parcels_List.csv"

TMK_CANDIDATES = [
    "TMK", "PARCEL_ID", "Parcel_ID", "parcel_id", "TAX_MAP_KEY",
    "Tax_Map_Key", "tax_map_key", "MAPKEY", "mapkey", "tmk",
]


# === 3. EXECUTION ===

def main():
    if not TARGET_GOLF_PATH.exists():
        print("[FATAL] Target Golf Polygons not found. Run Step 1.")
        raise SystemExit(1)
    if not PARCELS_PATH.exists():
        print("[FATAL] Reprojected Parcels not found. Run Step 1.")
        raise SystemExit(1)

    print("Phase 5 - Step 2: Parcel Intersection")
    print(f"Loading datasets from: {SCRIPT_DIR}")

    # [METHODOLOGY] gpd.read_file — spatial read of Step 1 OSM golf polygons
    target_golf_geo = gpd.read_file(TARGET_GOLF_PATH)
    # [METHODOLOGY] gpd.read_file — spatial read of Step 1 reprojected parcel cadastre
    parcels_geo     = gpd.read_file(PARCELS_PATH)

    print(f"  -> Loaded {len(target_golf_geo)} target golf polygons.")
    print(f"  -> Loaded {len(parcels_geo)} parcel features.")

    print("\nPerforming spatial intersection (this may take a moment)...")
    # [METHODOLOGY] gpd.overlay(how='intersection') — cookie-cutter of Phase 2 OSM polygons
    #               over the Phase 5 legal cadastre to isolate golf-course parcel fragments
    parcel_intersection_geo = gpd.overlay(target_golf_geo, parcels_geo, how="intersection")

    print(f"  -> Intersection complete: {len(parcel_intersection_geo)} parcel fragments found.")

    print("\nExtracting unique TMK identifiers...")

    found_column = None
    for col in TMK_CANDIDATES:
        if col in parcel_intersection_geo.columns:
            found_column = col
            break

    if found_column is None:
        print("\n[WARNING] Standard TMK column not found. Available columns:")
        print(list(parcel_intersection_geo.columns))
        print("[FATAL] No TMK column identified.")
        raise SystemExit(1)

    raw_tmks          = parcel_intersection_geo[found_column].dropna().astype(str).unique()
    unique_tmk_sorted = sorted(raw_tmks)

    print(f"  -> Found {len(unique_tmk_sorted)} unique TMKs across the {len(target_golf_geo)} golf courses.")

    tmk_df = pd.DataFrame({"TMK": unique_tmk_sorted})
    tmk_df.to_csv(OUT_CSV, index=False)

    # [METHODOLOGY] .geometry.area — compute legal footprint area from intersection geometry
    total_area_m2   = parcel_intersection_geo.geometry.area.sum()
    total_acres     = total_area_m2 / 4046.86
    formatted_acres = f"{total_acres:,.2f}"

    print("\n" + "=" * 60)
    print("PARCEL INTERSECTION COMPLETE")
    print("=" * 60)
    print(f"  Total Targeted Courses : {len(target_golf_geo)}")
    print(f"  Total Unique TMKs      : {len(unique_tmk_sorted)}")
    print(f"  Total Legal Footprint  : {formatted_acres} Acres")
    print("-" * 60)
    print(f"[+] Exported TMK List (CSV) : {OUT_CSV.as_posix()}")
    print("\n[DONE] Step 2 Complete.")


if __name__ == "__main__":
    main()
