# Purpose: Extract all Oahu OSM golf polygons and calculate the point-to-polygon
#          match rate between Phase 1 baseline points and Phase 2 polygons.
# Inputs:  Phase 1 Parsing/Data/Python/Py_Phase1_Baseline_Golf_Valuation.csv
#          Phase 2 Spatial Polygons and True Acreage/Data/Python/Py_Phase2_OSM_Golf_Polygons.gpkg
#          00 - Data Sources/Honolulu/All_Parcels_6378200148342636690.gpkg
# Outputs: Bulk Tests/python/Target_Golf_Polygons.gpkg
#          Bulk Tests/python/Honolulu_Parcels_Reprojected.gpkg


# === 1. IMPORTS ===

import pandas as pd
import geopandas as gpd
import pygris
from pathlib import Path


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR      = Path(__file__).parent
WORK_DIR        = SCRIPT_DIR.parents[2]

PHASE1_IN       = (
    WORK_DIR
    / "Phase 1 Parsing"
    / "Data"
    / "Python"
    / "Py_Phase1_Baseline_Golf_Valuation.csv"
)
OSM_IN          = (
    WORK_DIR
    / "Phase 2 Spatial Polygons and True Acreage"
    / "Data"
    / "Python"
    / "Py_Phase2_OSM_Golf_Polygons.gpkg"
)
PARCELS_IN      = (
    WORK_DIR
    / "00 - Data Sources"
    / "Honolulu"
    / "All_Parcels_6378200148342636690.gpkg"
)
TARGET_GOLF_OUT = SCRIPT_DIR / "Target_Golf_Polygons.gpkg"
PARCELS_OUT     = SCRIPT_DIR / "Honolulu_Parcels_Reprojected.gpkg"


# === 3. EXECUTION ===

def main():
    for path in [PHASE1_IN, OSM_IN, PARCELS_IN]:
        if not path.exists():
            print(f"[FATAL] Input file not found:\n  {path}")
            raise SystemExit(1)

    print("Loading datasets...")
    baseline_df  = pd.read_csv(PHASE1_IN)
    # [METHODOLOGY] gpd.read_file — spatial read of Phase 2 OSM golf polygons
    osm_golf_geo = gpd.read_file(OSM_IN)
    # [METHODOLOGY] gpd.read_file — spatial read of Honolulu cadastral parcel layer
    parcels_geo  = gpd.read_file(PARCELS_IN)

    print("Downloading Oahu boundary...")
    oahu_boundary_geo = (
        pygris.counties(state="HI", cb=True)
        .query("NAME == 'Honolulu'")
        # [METHODOLOGY] .to_crs — reproject county boundary to match OSM CRS
        .to_crs(osm_golf_geo.crs)
    )

    print("Extracting all OSM polygons within Oahu...")
    boundary_union = oahu_boundary_geo.geometry.union_all()
    # [METHODOLOGY] .intersects — spatial subset of all OSM golf polygons to Honolulu county
    oahu_golf_geo = osm_golf_geo[osm_golf_geo.geometry.intersects(boundary_union)].copy()
    if len(oahu_golf_geo) == 0:
        print("[FATAL] No OSM polygons found on Oahu.")
        raise SystemExit(1)

    oahu_mask = (
        (baseline_df["County_Name"] == "Honolulu") | (baseline_df["FIPS"] == 15003)
    )
    # [METHODOLOGY] gpd.GeoDataFrame — convert Phase 1 tabular baseline to spatial points
    oahu_baseline_geo = gpd.GeoDataFrame(
        baseline_df[oahu_mask].copy(),
        geometry=gpd.points_from_xy(
            baseline_df.loc[oahu_mask, "Longitude"],
            baseline_df.loc[oahu_mask, "Latitude"],
        ),
        crs=4326,
    )
    # [METHODOLOGY] .to_crs — reproject Phase 1 points to match OSM CRS
    oahu_baseline_geo = oahu_baseline_geo.to_crs(osm_golf_geo.crs)

    # [METHODOLOGY] gpd.sjoin — check which Phase 1 points fall within an OSM polygon;
    #               mismatch rate quantifies Phase 1-to-Phase 2 representational error
    joined    = gpd.sjoin(
        oahu_baseline_geo, oahu_golf_geo[["geometry"]], how="left", predicate="intersects"
    )
    hit_index = set(joined.loc[joined["index_right"].notna()].index)
    hits      = len(hit_index)
    misses    = len(oahu_baseline_geo) - hits

    print("\n" + "=" * 60)
    print("METHODOLOGICAL ERROR ANALYSIS (OAHU MICRO-CASE STUDY)")
    print("=" * 60)
    print(f"  Phase 1 Baseline Total (Points) : {len(oahu_baseline_geo):d} courses")
    print(f"  Phase 2 OSM Total (Polygons)    : {len(oahu_golf_geo):d} courses")
    print("  " + "-" * 50)
    print(f"  Points hitting a polygon        : {hits:d}")
    print(f"  Points missing a polygon        : {misses:d}")
    print(f"  Direct Point Match Rate         : {hits / len(oahu_baseline_geo) * 100:.1f}%")
    print("=" * 60 + "\n")

    if oahu_golf_geo.crs != parcels_geo.crs:
        print("Reprojecting parcels to match OSM CRS...")
        # [METHODOLOGY] .to_crs — align parcel CRS to OSM CRS for Step 2 overlay
        parcels_geo = parcels_geo.to_crs(oahu_golf_geo.crs)

    print(f"Exporting geometries to: {SCRIPT_DIR}")
    # [METHODOLOGY] .to_file — persist Oahu OSM golf polygons for Step 2 parcel intersection
    oahu_golf_geo.to_file(TARGET_GOLF_OUT, driver="GPKG")
    # [METHODOLOGY] .to_file — persist reprojected parcel cadastre for Step 2
    parcels_geo.to_file(PARCELS_OUT, driver="GPKG")

    print("\n[DONE] Step 1 Complete. Ready for Step 2.")


if __name__ == "__main__":
    main()
