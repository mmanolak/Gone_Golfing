# Purpose: Intersect Oahu OSM golf course polygons with the Honolulu County
#          Zoning layer to quantify the percentage of golf course land occupying
#          each zoning designation (e.g., Preservation, Agriculture, Residential),
#          and the percentage of each zone class's total Honolulu footprint
#          occupied by golf courses.
# Inputs:  Bulk Tests/Julia/Target_Golf_Polygons.gpkg
#          00 - Data Sources/Honolulu/Zoning_-2205419429161838665.gpkg
# Outputs: Bulk Tests/Julia/Phase5_Step6_Zoning_Percentages.csv
#          Bulk Tests/Julia/Phase5_Step6_Zone_Golf_Penetration.csv


# === 1. USING ===

using ArchGDAL
using GeoDataFrames
using DataFrames
using CSV
using Printf


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR  = @__DIR__
const WORK_DIR    = normpath(joinpath(@__DIR__, "..", "..", ".."))
const GOLF_GPKG   = joinpath(SCRIPT_DIR, "Target_Golf_Polygons.gpkg")
const ZONING_GPKG = joinpath(
    WORK_DIR, "00 - Data Sources", "Honolulu",
    "Zoning_-2205419429161838665.gpkg"
)
const OUT_CSV             = joinpath(SCRIPT_DIR, "Phase5_Step6_Zoning_Percentages.csv")
const OUT_PENETRATION_CSV = joinpath(SCRIPT_DIR, "Phase5_Step6_Zone_Golf_Penetration.csv")

const M2_PER_ACRE = 4046.856422
const GOLF_EPSG   = 5070   # NAD83 / Conus Albers, metres — confirmed from GeoPackage
const ZONING_EPSG = 3760   # NAD83(HARN) / Hawaii zone 3, ftUS — confirmed from GeoPackage


# === 3. FUNCTIONS ===

function reproject_geoms(geoms, src_epsg::Int, dst_epsg::Int)
    src_sr = ArchGDAL.importEPSG(src_epsg)
    dst_sr = ArchGDAL.importEPSG(dst_epsg)
    result = ArchGDAL.IGeometry[]
    ArchGDAL.createcoordtrans(src_sr, dst_sr) do coord_tf
        for g_orig in geoms
            g = ArchGDAL.clone(g_orig)
            ArchGDAL.transform!(g, coord_tf)
            push!(result, g)
        end
    end
    return result
end


# === 4. EXECUTION ===

function main()
    println("\n" * "=" ^ 70)
    println("Phase 5b - Step 6: Zoning Intersection Analysis")
    println("=" ^ 70 * "\n")

    isfile(GOLF_GPKG)   || error("[FATAL] Golf polygons not found:\n  $GOLF_GPKG")
    isfile(ZONING_GPKG) || error("[FATAL] Zoning layer not found:\n  $ZONING_GPKG")

    # -- Load
    println("[Step 1] Loading spatial datasets...")
    golf_gdf   = GeoDataFrames.read(GOLF_GPKG)
    zoning_gdf = GeoDataFrames.read(ZONING_GPKG)

    println("  Golf polygons:  $(nrow(golf_gdf)) features  (CRS: EPSG $GOLF_EPSG)")
    println("  Zoning layer:   $(nrow(zoning_gdf)) features  (CRS: EPSG $ZONING_EPSG)")

    # [METHODOLOGY] Golf polygons are in EPSG 5070 (NAD83 / Conus Albers, metres);
    #               the Honolulu zoning layer is in EPSG 3760 (NAD83(HARN) / Hawaii
    #               zone 3, ftUS). Zoning is reprojected to match the golf layer so
    #               ArchGDAL.geomarea() returns m², which convert to acres via
    #               4,046.856422 m²/ac.
    println("\n[Step 2] Reprojecting zoning from EPSG $ZONING_EPSG -> EPSG $GOLF_EPSG...")
    zoning_geoms_proj = reproject_geoms(zoning_gdf.SHAPE, ZONING_EPSG, GOLF_EPSG)
    println("  Reprojection complete.")

    # -- County-wide acreage per zone class (denominator for penetration rate)
    county_zone_acres = combine(
        groupby(
            DataFrame(
                zone_class       = string.(zoning_gdf.zone_class),
                zone_total_acres = ArchGDAL.geomarea.(zoning_geoms_proj) ./ M2_PER_ACRE,
            ),
            :zone_class
        ),
        :zone_total_acres => sum => :county_total_acres,
    )

    # [METHODOLOGY] ArchGDAL.intersection — clips the zoning polygons to the exact
    #               boundary of each golf course polygon, producing fragment geometries
    #               whose combined area quantifies which zoning classes overlap the
    #               golf course footprint (Pebesma 2018).
    println("\n[Step 3] Performing spatial intersection (golf courses ∩ zoning)...")

    frag_zone_class = String[]
    frag_zone_desc  = String[]
    frag_area_acres = Float64[]

    for i in 1:nrow(golf_gdf)
        g_geom = golf_gdf.geometry[i]
        for j in 1:nrow(zoning_gdf)
            z_geom = zoning_geoms_proj[j]
            ArchGDAL.intersects(g_geom, z_geom) || continue
            isect = ArchGDAL.intersection(g_geom, z_geom)
            ArchGDAL.isempty(isect) && continue
            area_m2 = ArchGDAL.geomarea(isect)
            area_m2 ≈ 0.0 && continue
            push!(frag_zone_class, string(zoning_gdf.zone_class[j]))
            push!(frag_zone_desc,  string(coalesce(zoning_gdf.zoning_description[j], "")))
            push!(frag_area_acres, area_m2 / M2_PER_ACRE)
        end
    end

    println("  Intersection produced $(length(frag_area_acres)) fragments.")

    println("\n[Step 4] Calculating fragment areas in acres...")
    total_golf_acres = sum(frag_area_acres)
    @printf("  Total intersected golf footprint: %.1f acres\n", total_golf_acres)

    # -- Summarise by zoning class
    frag_df = DataFrame(
        zone_class         = frag_zone_class,
        zoning_description = frag_zone_desc,
        area_acres         = frag_area_acres,
    )

    zone_summary = combine(
        groupby(frag_df, [:zone_class, :zoning_description]),
        :area_acres => sum    => :acres,
        :area_acres => length => :fragments,
    )
    zone_summary.pct_of_total = zone_summary.acres ./ total_golf_acres .* 100
    sort!(zone_summary, :acres, rev = true)

    # -- Zone penetration: what % of each Honolulu zone class is occupied by golf
    zone_penetration = leftjoin(
        rename(zone_summary[:, [:zone_class, :zoning_description, :acres]], :acres => :golf_acres),
        county_zone_acres,
        on = :zone_class,
    )
    zone_penetration.pct_zone_as_golf = (
        zone_penetration.golf_acres ./ zone_penetration.county_total_acres .* 100
    )
    sort!(zone_penetration, :pct_zone_as_golf, rev = true)

    # -- Console output: golf share of total zoning footprint
    println("\n" * "=" ^ 78)
    println("ZONING BREAKDOWN — OAHU GOLF COURSES")
    println("=" ^ 78)
    @printf("%-12s %-40s %12s %10s\n", "Zone Class", "Description", "Acres", "% of Total")
    println("-" ^ 78)

    for row in eachrow(zone_summary)
        @printf("%-12s %-40s %12.1f %9.1f%%\n",
            row.zone_class,
            first(string(coalesce(row.zoning_description, "")), 40),
            row.acres,
            row.pct_of_total,
        )
    end

    println("-" ^ 78)
    @printf("%-12s %-40s %12.1f %9s%%\n", "", "TOTAL", total_golf_acres, "100.0")
    println("=" ^ 78)

    # -- Console output: zone penetration (zone-centric denominator)
    println("\n" * "=" ^ 88)
    println("ZONE PENETRATION — % OF EACH HONOLULU ZONE CLASS THAT IS GOLF COURSE")
    println("=" ^ 88)
    @printf("%-12s %-35s %16s %12s %10s\n",
        "Zone Class", "Description", "Zone Total (ac)", "Golf (ac)", "% Golf")
    println("-" ^ 88)

    for row in eachrow(zone_penetration)
        @printf("%-12s %-35s %16.1f %12.1f %9.3f%%\n",
            row.zone_class,
            first(string(coalesce(row.zoning_description, "")), 35),
            row.county_total_acres,
            row.golf_acres,
            row.pct_zone_as_golf,
        )
    end

    println("=" ^ 88)

    # -- Save
    CSV.write(OUT_CSV, zone_summary)
    println("\n[+] Zoning percentages saved  -> $(basename(OUT_CSV))")

    CSV.write(OUT_PENETRATION_CSV, zone_penetration)
    println("[+] Zone penetration saved    -> $(basename(OUT_PENETRATION_CSV))")
    println("\n[DONE] Step 6 Complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
