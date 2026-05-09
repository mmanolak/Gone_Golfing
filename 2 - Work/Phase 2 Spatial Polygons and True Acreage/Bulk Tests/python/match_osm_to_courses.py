# Purpose: Match OSM golf-course polygons to Phase 1 baseline points via
#          spatial intersect then 500 m nearest-neighbour fallback.
# Inputs:  Phase 1 Parsing/Bulk Tests/python/Py_Phase1_Baseline_Golf_Valuation.csv
#          Bulk Tests/python/Py_Phase2_OSM_Golf_Polygons.gpkg
# Outputs: Bulk Tests/python/Py_Phase2_Acreage_Matched.csv


# === 1. LIBRARIES ===

from pathlib import Path
import pandas as pd
import geopandas as gpd


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = Path(__file__).parent
PHASE1_CSV = (SCRIPT_DIR.parent.parent.parent
              / "Phase 1 Parsing" / "Bulk Tests" / "python"
              / "Py_Phase1_Baseline_Golf_Valuation.csv")
OSM_GPKG   = SCRIPT_DIR / "Py_Phase2_OSM_Golf_Polygons.gpkg"
OUT_CSV    = SCRIPT_DIR / "Py_Phase2_Acreage_Matched.csv"

MAX_NEAREST_M = 500


# === 3. FUNCTIONS ===

def main():
    for path in (PHASE1_CSV, OSM_GPKG):
        if not path.exists():
            raise FileNotFoundError(f"Input file not found: {path}")

    # 1. Load Phase 1 points
    print("-1  Loading Phase 1 baseline dataset")
    courses_df  = pd.read_csv(PHASE1_CSV)
    courses_df  = courses_df.dropna(subset=["Longitude", "Latitude"])
    courses_geo = gpd.GeoDataFrame(
        courses_df,
        geometry=gpd.points_from_xy(courses_df["Longitude"], courses_df["Latitude"]),
        crs="EPSG:4326",
    ).to_crs(epsg=5070)  # [METHODOLOGY] EPSG:5070 — equal-area CRS for distance accuracy
    print(f"    Phase 1 rows: {len(courses_geo):,}")

    # 2. Load OSM polygons (already in EPSG:5070)
    print("-2  Loading OSM golf polygons")
    osm_golf_geo = gpd.read_file(str(OSM_GPKG))  # [METHODOLOGY] read from OSM GeoPackage
    if osm_golf_geo.crs.to_epsg() != 5070:
        osm_golf_geo = osm_golf_geo.to_crs(epsg=5070)  # [METHODOLOGY]
    print(f"    OSM polygons: {len(osm_golf_geo):,}")

    # 3a. Primary join: intersects
    print("-3a Spatial join (intersects)")
    courses_geo = gpd.sjoin(  # [METHODOLOGY] point-in-polygon primary match
        courses_geo,
        osm_golf_geo[["osm_acreage", "geometry"]],
        how="left",
        predicate="intersects",
    )
    if "index_right" in courses_geo.columns:
        courses_geo.drop(columns=["index_right"], inplace=True)

    matched_mask = courses_geo["osm_acreage"].notna()
    n_hit  = matched_mask.sum()
    n_miss = (~matched_mask).sum()
    print(f"    Direct intersect hits:   {n_hit:,}")
    print(f"    Misses (need fallback):  {n_miss:,}")

    # 3b. Fallback: nearest within 500 m
    if n_miss > 0:
        print(f"-3b Nearest-neighbor fallback (max {MAX_NEAREST_M} m)")
        miss_geo = courses_geo.loc[courses_geo["osm_acreage"].isna()].copy()

        nearest = gpd.sjoin_nearest(  # [METHODOLOGY] nearest-feature fallback for unmatched courses
            miss_geo[["geometry"]],
            osm_golf_geo[["osm_acreage", "geometry"]],
            how="left",
            max_distance=MAX_NEAREST_M,
            distance_col="_dist",
        )
        nearest = nearest[~nearest.index.duplicated(keep="first")]
        courses_geo.loc[nearest.index, "osm_acreage"] = nearest["osm_acreage"].values

        n_recovered = nearest["osm_acreage"].notna().sum()
        print(f"    Recovered via nearest:   {n_recovered:,}")

    # 4. De-duplicate (a point inside overlapping polygons creates dupes)
    courses_geo = courses_geo[~courses_geo.index.duplicated(keep="first")]

    # 5. Final counts
    total     = len(courses_geo)
    has_acre  = courses_geo["osm_acreage"].notna().sum()
    miss_acre = courses_geo["osm_acreage"].isna().sum()

    print(f"\n=== OUTPUT STATISTICS ===")
    print(f"  Total courses:               {total:,}")
    print(f"  Matched with osm_acreage:    {has_acre:,}  ({has_acre/total:.1%})")
    print(f"  Missing osm_acreage:         {miss_acre:,}  (MICE target)")

    ac = courses_geo["osm_acreage"].dropna()
    print(f"\n  osm_acreage summary (matched only):")
    print(f"    Min:    {ac.min():>10,.1f} acres")
    print(f"    Median: {ac.median():>10,.1f} acres")
    print(f"    Mean:   {ac.mean():>10,.1f} acres")
    print(f"    Max:    {ac.max():>10,.1f} acres")

    # 6. Drop geometry, save
    out = courses_geo.drop(columns=["geometry"])
    out.to_csv(str(OUT_CSV), index=False)
    print(f"\n  [OK] Saved -> {OUT_CSV}")


# === 4. EXECUTION ===

if __name__ == "__main__":
    main()
