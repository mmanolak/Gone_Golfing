# Purpose: Extract all Oahu OSM golf polygons and calculate the point-to-polygon
#          match rate between Phase 1 baseline points and Phase 2 polygons.
# Inputs:  Phase 1 Parsing/Data/Julia/Jl_Phase1_Baseline_Golf_Valuation.csv
#          Phase 2 Spatial Polygons and True Acreage/Data/Julia/Jl_Phase2_OSM_Golf_Polygons.gpkg
#          00 - Data Sources/Honolulu/All_Parcels_6378200148342636690.gpkg
# Outputs: Bulk Tests/Julia/Target_Golf_Polygons.gpkg
#          Bulk Tests/Julia/Honolulu_Parcels_Reprojected.gpkg


# === 1. USING ===

using GeoDataFrames
using ArchGDAL
using DataFrames
using CSV
using Printf


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR        = @__DIR__
const WORK_DIR          = normpath(joinpath(@__DIR__, "..", "..", ".."))
const HONOLULU_DATA_DIR = joinpath(WORK_DIR, "00 - Data Sources", "Honolulu")

const PHASE1_IN  = joinpath(
    WORK_DIR,
    "Phase 1 Parsing", "Data", "Julia",
    "Jl_Phase1_Baseline_Golf_Valuation.csv",
)
const OSM_IN     = joinpath(
    WORK_DIR,
    "Phase 2 Spatial Polygons and True Acreage", "Data", "Julia",
    "Jl_Phase2_OSM_Golf_Polygons.gpkg",
)
const PARCELS_IN      = joinpath(HONOLULU_DATA_DIR, "All_Parcels_6378200148342636690.gpkg")
const TARGET_GOLF_OUT = joinpath(SCRIPT_DIR, "Target_Golf_Polygons.gpkg")
const PARCELS_OUT     = joinpath(SCRIPT_DIR, "Honolulu_Parcels_Reprojected.gpkg")

const OAHU_LON_MIN = -158.5
const OAHU_LON_MAX = -157.6
const OAHU_LAT_MIN =  21.2
const OAHU_LAT_MAX =  21.9


# === 3. FUNCTIONS ===

function in_oahu(lon, lat)
    return OAHU_LON_MIN <= lon <= OAHU_LON_MAX && OAHU_LAT_MIN <= lat <= OAHU_LAT_MAX
end


# === 4. EXECUTION ===

function main()
    println("\n" * "=" ^ 60)
    println("METHODOLOGICAL ERROR ANALYSIS (OAHU MICRO-CASE STUDY)")
    println("=" ^ 60)

    for path in [PHASE1_IN, OSM_IN, PARCELS_IN]
        isfile(path) || error("[FATAL] Input file not found:\n  $path")
    end

    println("\nLoading datasets...")
    baseline_df  = CSV.read(PHASE1_IN, DataFrame)
    # [METHODOLOGY] GeoDataFrames.read — spatial read of Phase 2 OSM golf polygons
    osm_golf_geo = GeoDataFrames.read(OSM_IN)
    # [METHODOLOGY] GeoDataFrames.read — spatial read of Honolulu cadastral parcel layer
    parcels_geo  = GeoDataFrames.read(PARCELS_IN)
    # Honolulu cadastral GPKG stores geometry as "SHAPE"; normalize to "geometry"
    "SHAPE" in names(parcels_geo) && rename!(parcels_geo, :SHAPE => :geometry)

    osm_crs     = ArchGDAL.getspatialref(osm_golf_geo.geometry[1])
    # importPROJ4 guarantees traditional lon/lat (x=lon, y=lat) axis order;
    # importEPSG(4326) in GDAL 3.x returns lat/lon which would silently swap axes.
    wgs84       = ArchGDAL.importPROJ4("+proj=longlat +datum=WGS84 +no_defs")
    parcels_crs = ArchGDAL.getspatialref(parcels_geo.geometry[1])

    println("Extracting all OSM polygons within Oahu...")
    # [METHODOLOGY] centroid-in-bbox — filter OSM golf polygons to Honolulu county extents;
    #               replaces pygris county download used in the R/Python versions.
    #               createcoordtrans + transform! is the correct ArchGDAL.jl API for reprojection.
    oahu_mask = ArchGDAL.createcoordtrans(osm_crs, wgs84) do t
        [begin
            c = ArchGDAL.centroid(g)
            ArchGDAL.transform!(c, t)
            in_oahu(ArchGDAL.getx(c, 0), ArchGDAL.gety(c, 0))
        end for g in osm_golf_geo.geometry]
    end
    oahu_golf_geo = osm_golf_geo[oahu_mask, :]

    if nrow(oahu_golf_geo) == 0
        error("[FATAL] No OSM polygons found on Oahu.")
    end

    oahu_baseline = filter(baseline_df) do row
        (!ismissing(row.County_Name) && row.County_Name == "Honolulu") ||
        (!ismissing(row.FIPS)        && row.FIPS        == 15003)
    end

    n_total     = nrow(oahu_baseline)
    hit_results = fill(false, n_total)

    # [METHODOLOGY] createcoordtrans WGS84 → OSM CRS — align Phase 1 lat/lon points to OSM CRS
    #               for point-in-polygon check; mismatch rate quantifies Phase 1-to-Phase 2
    #               representational error
    ArchGDAL.createcoordtrans(wgs84, osm_crs) do t
        for i in 1:n_total
            # [METHODOLOGY] ArchGDAL.createpoint — convert Phase 1 lat/lon to spatial point
            pt = ArchGDAL.createpoint(oahu_baseline.Longitude[i], oahu_baseline.Latitude[i])
            ArchGDAL.transform!(pt, t)
            # [METHODOLOGY] ArchGDAL.intersects — check if point falls within an OSM polygon
            hit_results[i] = any(
                j -> ArchGDAL.intersects(pt, oahu_golf_geo.geometry[j]),
                1:nrow(oahu_golf_geo),
            )
        end
    end

    hits   = count(hit_results)
    misses = n_total - hits

    println("  Phase 1 Baseline Total (Points) : $n_total courses")
    println("  Phase 2 OSM Total (Polygons)    : $(nrow(oahu_golf_geo)) courses")
    println("  " * "-" ^ 50)
    println("  Points hitting a polygon        : $hits")
    println("  Points missing a polygon        : $misses")
    @printf("  Direct Point Match Rate         : %.1f%%\n", hits / n_total * 100)
    println("=" ^ 60)

    # Step 2 only needs geometry + tmk; dropping the other 35 columns avoids all-Missing
    # columns that GeoDataFrames.write can't convert to OGR field types.
    select!(parcels_geo, [:geometry, :tmk])

    println("\nReprojecting parcels to match OSM CRS...")
    # [METHODOLOGY] createcoordtrans parcel CRS → OSM CRS — in-place transform for Step 2 overlay
    ArchGDAL.createcoordtrans(parcels_crs, osm_crs) do t
        for g in parcels_geo.geometry
            ArchGDAL.transform!(g, t)
        end
    end

    println("Exporting geometries to: $SCRIPT_DIR")
    isfile(TARGET_GOLF_OUT) && rm(TARGET_GOLF_OUT)
    isfile(PARCELS_OUT)     && rm(PARCELS_OUT)
    # [METHODOLOGY] GeoDataFrames.write — persist Oahu OSM golf polygons for Step 2 parcel intersection
    GeoDataFrames.write(TARGET_GOLF_OUT, oahu_golf_geo; layer_name = "golf_courses")
    # [METHODOLOGY] GeoDataFrames.write — persist reprojected parcel cadastre for Step 2.
    # geometrycolumn must be specified explicitly: GeoDataFrames retains the original column
    # name (:SHAPE) in internal metadata even after we rename the column to :geometry.
    GeoDataFrames.write(PARCELS_OUT, parcels_geo; layer_name = "parcels", geometrycolumn = :geometry)

    println("\n[DONE] Step 1 Complete. Ready for Step 2.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
