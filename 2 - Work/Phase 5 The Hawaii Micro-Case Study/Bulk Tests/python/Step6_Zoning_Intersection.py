# Purpose: Intersect Oahu OSM golf course polygons with the Honolulu County
#          Zoning layer to quantify the percentage of golf course land occupying
#          each zoning designation (e.g., Preservation, Agriculture, Residential),
#          and the percentage of each zone class's total Honolulu footprint
#          occupied by golf courses.
# Inputs:  Bulk Tests/python/Target_Golf_Polygons.gpkg
#          00 - Data Sources/Honolulu/Zoning_-2205419429161838665.gpkg
# Outputs: Bulk Tests/python/Phase5_Step6_Zoning_Percentages.csv
#          Bulk Tests/python/Phase5_Step6_Zone_Golf_Penetration.csv


# === 1. IMPORTS ===

import pathlib

import geopandas as gpd
import pandas as pd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR          = pathlib.Path(__file__).parent
WORK_DIR            = SCRIPT_DIR.parents[2]
GOLF_GPKG           = SCRIPT_DIR / "Target_Golf_Polygons.gpkg"
ZONING_GPKG         = (
    WORK_DIR / "00 - Data Sources" / "Honolulu"
    / "Zoning_-2205419429161838665.gpkg"
)
OUT_CSV             = SCRIPT_DIR / "Phase5_Step6_Zoning_Percentages.csv"
OUT_PENETRATION_CSV = SCRIPT_DIR / "Phase5_Step6_Zone_Golf_Penetration.csv"

M2_PER_ACRE = 4046.856422


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

def main():
    print("\n" + "=" * 70)
    print("Phase 5b - Step 6: Zoning Intersection Analysis")
    print("=" * 70 + "\n")

    # -- Guard input files
    if not GOLF_GPKG.exists():
        print(f"[FATAL] Golf polygons not found:\n  {GOLF_GPKG}")
        raise SystemExit(1)
    if not ZONING_GPKG.exists():
        print(f"[FATAL] Zoning layer not found:\n  {ZONING_GPKG}")
        raise SystemExit(1)

    # -- Load
    print("[Step 1] Loading spatial datasets...")
    golf_gdf   = gpd.read_file(GOLF_GPKG)
    zoning_gdf = gpd.read_file(ZONING_GPKG)

    print(f"  Golf polygons:  {len(golf_gdf):,} features  (CRS: EPSG {golf_gdf.crs.to_epsg()})")
    print(f"  Zoning layer:   {len(zoning_gdf):,} features  (CRS: EPSG {zoning_gdf.crs.to_epsg()})")

    # [METHODOLOGY] Both layers must share the same CRS before intersection.
    #               Golf polygons are in EPSG 5070 (NAD83 / Conus Albers, metres);
    #               the Honolulu zoning layer is in EPSG 3760 (NAD83(HARN) / Hawaii
    #               zone 3, ftUS). Zoning is reprojected to match the golf layer so
    #               .geometry.area returns m², which convert to acres via 4,046.856422 m²/ac.
    if zoning_gdf.crs != golf_gdf.crs:
        print(
            f"\n[Step 2] Reprojecting zoning from EPSG {zoning_gdf.crs.to_epsg()}"
            f" -> EPSG {golf_gdf.crs.to_epsg()}..."
        )
        zoning_gdf = zoning_gdf.to_crs(golf_gdf.crs)
        print("  Reprojection complete.")

    # -- County-wide acreage per zone class (denominator for penetration rate)
    county_zone_acres = (
        zoning_gdf
        .assign(zone_total_acres=zoning_gdf.geometry.area / M2_PER_ACRE)
        .groupby("zone_class", as_index=False)["zone_total_acres"]
        .sum()
        .rename(columns={"zone_total_acres": "county_total_acres"})
    )

    # [METHODOLOGY] gpd.overlay(how='intersection') clips the zoning polygons to
    #               the exact boundary of each golf course polygon, producing
    #               fragment geometries whose combined area quantifies which zoning
    #               classes overlap the golf course footprint (Pebesma 2018).
    print("\n[Step 3] Performing spatial intersection (golf courses ∩ zoning)...")

    golf_sub   = golf_gdf[[golf_gdf.geometry.name]]
    zoning_sub = zoning_gdf[["zone_class", "zoning_description", zoning_gdf.geometry.name]]

    intersection_gdf = gpd.overlay(
        golf_sub, zoning_sub, how="intersection", keep_geom_type=False
    )
    print(f"  Intersection produced {len(intersection_gdf):,} fragments.")

    # -- Area calculation (m² -> acres)
    print("\n[Step 4] Calculating fragment areas in acres...")

    intersection_gdf["area_acres"] = intersection_gdf.geometry.area / M2_PER_ACRE
    total_golf_acres = intersection_gdf["area_acres"].sum()

    print(f"  Total intersected golf footprint: {total_golf_acres:.1f} acres")

    # -- Summarise by zoning class
    zone_summary = (
        intersection_gdf
        .groupby(["zone_class", "zoning_description"], as_index=False)
        .agg(acres=("area_acres", "sum"), fragments=("area_acres", "count"))
        .assign(pct_of_total=lambda df: df["acres"] / total_golf_acres * 100)
        .sort_values("acres", ascending=False)
        .reset_index(drop=True)
    )

    # -- Zone penetration: what % of each Honolulu zone class is occupied by golf
    zone_penetration = (
        zone_summary[["zone_class", "zoning_description", "acres"]]
        .rename(columns={"acres": "golf_acres"})
        .merge(county_zone_acres, on="zone_class", how="left")
        .assign(pct_zone_as_golf=lambda df: df["golf_acres"] / df["county_total_acres"] * 100)
        .sort_values("pct_zone_as_golf", ascending=False)
        .reset_index(drop=True)
    )

    # -- Console output: golf share of total zoning footprint
    print("\n" + "=" * 78)
    print("ZONING BREAKDOWN — OAHU GOLF COURSES")
    print("=" * 78)
    print(f"{'Zone Class':<12} {'Description':<40} {'Acres':>12} {'% of Total':>10}")
    print("-" * 78)

    for _, row in zone_summary.iterrows():
        print(
            f"{row['zone_class']:<12} {str(row['zoning_description'])[:40]:<40} "
            f"{row['acres']:>12.1f} {row['pct_of_total']:>9.1f}%"
        )

    print("-" * 78)
    print(f"{'':12} {'TOTAL':<40} {total_golf_acres:>12.1f} {'100.0':>9}%")
    print("=" * 78)

    # -- Console output: zone penetration (zone-centric denominator)
    print("\n" + "=" * 88)
    print("ZONE PENETRATION — % OF EACH HONOLULU ZONE CLASS THAT IS GOLF COURSE")
    print("=" * 88)
    print(
        f"{'Zone Class':<12} {'Description':<35} "
        f"{'Zone Total (ac)':>16} {'Golf (ac)':>12} {'% Golf':>10}"
    )
    print("-" * 88)

    for _, row in zone_penetration.iterrows():
        print(
            f"{row['zone_class']:<12} {str(row['zoning_description'])[:35]:<35} "
            f"{row['county_total_acres']:>16.1f} {row['golf_acres']:>12.1f} "
            f"{row['pct_zone_as_golf']:>9.3f}%"
        )

    print("=" * 88)

    # -- Save
    zone_summary.to_csv(OUT_CSV, index=False)
    print(f"\n[+] Zoning percentages saved  -> {OUT_CSV.name}")

    zone_penetration.to_csv(OUT_PENETRATION_CSV, index=False)
    print(f"[+] Zone penetration saved    -> {OUT_PENETRATION_CSV.name}")
    print("\n[DONE] Step 6 Complete.")


if __name__ == "__main__":
    main()
