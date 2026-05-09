# Purpose: Parse raw USA golf course CSV via regex into structured fields,
#          spatially join to 2022 US county boundaries via point-in-polygon,
#          and save the enriched dataset.
# Inputs:  00 - Data Sources/Original Data/Golf Courses-USA.csv
# Outputs: Bulk Tests/python/Py_Phase1_Spatial_Joined_Golf_Courses.csv


# === 1. LIBRARIES ===

import re
from pathlib import Path

import geopandas as gpd
import pandas as pd
from pygris import counties


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = Path(__file__).parent
ROOT_DIR   = SCRIPT_DIR.parent.parent.parent

RAW_CSV = ROOT_DIR / "00 - Data Sources" / "Original Data" / "Golf Courses-USA.csv"
OUT_CSV = SCRIPT_DIR / "Py_Phase1_Spatial_Joined_Golf_Courses.csv"


# === 3. FUNCTIONS ===

def extract_course_type(detail_str: str) -> str:
    """Classify ownership from the first parenthetical keyword in the Details field."""
    s = str(detail_str).lower()
    for label in ("public", "private", "municipal", "military", "resort"):
        if label in s:
            return label.title()
    return "Unknown"


def extract_holes(detail_str: str) -> int:
    """Return hole count from the Details field; defaults to 18 when absent."""
    m = re.search(r"\((\d+)\s*Holes?\)", str(detail_str), re.IGNORECASE)
    return int(m.group(1)) if m else 18


# === 4. EXECUTION ===

def main():
    if not RAW_CSV.exists():
        raise FileNotFoundError(f"Input file not found: {RAW_CSV}")
    courses_df = pd.read_csv(RAW_CSV, header=None,
                             names=["Longitude", "Latitude", "Course_Name", "Details"])

    courses_df["Ownership_Type"] = courses_df["Details"].apply(extract_course_type)
    courses_df["Holes"]          = courses_df["Details"].apply(extract_holes)

    courses_df  = courses_df.dropna(subset=["Longitude", "Latitude"])
    courses_geo = gpd.GeoDataFrame(
        courses_df,
        geometry=gpd.points_from_xy(courses_df["Longitude"], courses_df["Latitude"]),
        crs="EPSG:4326",
    )

    county_geo = counties(cb=True, year=2022, resolution="20m")
    county_geo = county_geo.to_crs("EPSG:4326")  # [METHODOLOGY] align CRS to WGS 84 — golf course coordinates are in EPSG:4326

    courses_geo = gpd.sjoin(  # [METHODOLOGY]
        courses_geo,
        county_geo[["GEOID", "NAME", "STATE_NAME", "geometry"]],
        how="left",
        predicate="intersects",
    )
    courses_geo = courses_geo.rename(columns={
        "GEOID":      "FIPS",
        "NAME":       "County_Name",
        "STATE_NAME": "State_Abbr",
    })
    if "index_right" in courses_geo.columns:
        courses_geo.drop(columns=["index_right"], inplace=True)

    total   = len(courses_geo)
    missing = courses_geo["FIPS"].isna().sum()

    print("\n=== OUTPUT STATISTICS ===")
    print(f"  Total rows:                {total:,}")
    print(f"  Missing FIPS (no county):  {missing}")
    print(f"\n  First 5 rows:")
    print(courses_geo[["Course_Name", "FIPS", "County_Name", "State_Abbr",
                        "Ownership_Type", "Holes"]].head().to_string(index=False))

    courses_geo.drop(columns=["geometry"]).to_csv(OUT_CSV, index=False)
    print(f"\n  [OK] Saved -> {OUT_CSV}")


if __name__ == "__main__":
    main()
