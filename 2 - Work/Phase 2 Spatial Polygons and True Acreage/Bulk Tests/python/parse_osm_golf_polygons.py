# Purpose: Stream golf-course polygons from the 11 GB OSM PBF file using
#          pyosmium's C++ handler, reproject to EPSG:5070, compute true
#          acreage, and filter by plausibility bounds.
# Inputs:  00 - Data Sources/Original Data/us-260413.osm.pbf
# Outputs: Bulk Tests/python/Py_Phase2_OSM_Golf_Polygons.gpkg


# === 1. LIBRARIES ===

import time
from pathlib import Path
import geopandas as gpd
import pandas as pd
import shapely.wkb as wkblib
import osmium


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = Path(__file__).parent
PBF_FILE   = SCRIPT_DIR.parent.parent.parent / "00 - Data Sources" / "Original Data" / "us-260413.osm.pbf"
OUT_GPKG   = SCRIPT_DIR / "Py_Phase2_OSM_Golf_Polygons.gpkg"

MIN_ACRES     = 5
MAX_ACRES     = 1500
SQ_M_PER_ACRE = 4046.8564224


# === 3. FUNCTIONS ===

class GolfCourseHandler(osmium.SimpleHandler):
    """Stream through every OSM area; keep only leisure=golf_course."""

    def __init__(self):
        super().__init__()
        self.wkb_fab = osmium.geom.WKBFactory()
        self.records = []
        self.errors  = 0

    def area(self, a):
        if a.tags.get("leisure") != "golf_course":
            return
        try:
            wkb  = self.wkb_fab.create_multipolygon(a)
            geom = wkblib.loads(wkb, hex=True)
            self.records.append({
                "osm_id":   a.id,
                "name":     a.tags.get("name", "Unknown"),
                "geometry": geom,
            })
        except Exception:
            self.errors += 1


def main():
    if not PBF_FILE.exists():
        raise FileNotFoundError(f"PBF file not found: {PBF_FILE}")

    # 1. Stream the PBF
    print("1  Streaming 11 GB PBF through pyosmium handler")
    print(f"    File: {PBF_FILE}")
    t0 = time.time()

    handler = GolfCourseHandler()
    handler.apply_file(str(PBF_FILE), locations=True)

    elapsed = time.time() - t0
    print(f"    Done in {elapsed/60:.1f} minutes.")
    print(f"    Raw polygons captured: {len(handler.records):,}")
    print(f"    Geometry build errors: {handler.errors}")

    if not handler.records:
        print("    ERROR: No polygons extracted. Aborting.")
        return

    # 2. Build GeoDataFrame in EPSG:4326 then reproject
    print("2  Building GeoDataFrame & reprojecting to EPSG:5070")
    osm_golf_geo = gpd.GeoDataFrame(handler.records, crs="EPSG:4326")
    osm_golf_geo = osm_golf_geo.to_crs(epsg=5070)  # [METHODOLOGY] EPSG:5070 — equal-area CRS for accurate acreage

    # 3. Calculate area & convert to acres
    print("3  Calculating acreage")
    osm_golf_geo["osm_acreage"] = osm_golf_geo.geometry.area / SQ_M_PER_ACRE  # [METHODOLOGY]

    raw_count    = len(osm_golf_geo)
    osm_golf_geo = osm_golf_geo[
        (osm_golf_geo["osm_acreage"] >= MIN_ACRES) &
        (osm_golf_geo["osm_acreage"] <= MAX_ACRES)
    ].copy()
    filtered_count = len(osm_golf_geo)
    dropped        = raw_count - filtered_count

    # 4. Report
    print(f"\n=== OUTPUT STATISTICS ===")
    print(f"  Raw polygons before filter:   {raw_count:,}")
    print(f"  Dropped (< {MIN_ACRES} or > {MAX_ACRES} acres): {dropped:,}")
    print(f"  Final polygon count:          {filtered_count:,}")

    ac = osm_golf_geo["osm_acreage"]
    print(f"\n  osm_acreage summary:")
    print(f"    Min:    {ac.min():>10,.1f} acres")
    print(f"    Median: {ac.median():>10,.1f} acres")
    print(f"    Mean:   {ac.mean():>10,.1f} acres")
    print(f"    Max:    {ac.max():>10,.1f} acres")

    pd.set_option("display.max_columns", None)
    pd.set_option("display.width", 120)
    print(f"\n  First 5 rows:")
    print(osm_golf_geo[["osm_id", "name", "osm_acreage"]].head().to_string(index=False))

    # 5. Save
    print(f"\n4  Saving to {OUT_GPKG}")
    osm_golf_geo.to_file(str(OUT_GPKG), driver="GPKG")  # [METHODOLOGY]
    print(f"  [OK] Saved -> {OUT_GPKG}")


# === 4. EXECUTION ===

if __name__ == "__main__":
    main()
