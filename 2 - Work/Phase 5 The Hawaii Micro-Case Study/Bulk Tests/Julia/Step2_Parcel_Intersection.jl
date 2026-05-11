# Purpose: Intersect Oahu OSM golf polygons with Honolulu parcel cadastre to
#          extract TMK identifiers and total legal footprint area.
# Inputs:  Bulk Tests/Julia/Target_Golf_Polygons.gpkg        (Step 1 output)
#          Bulk Tests/Julia/Honolulu_Parcels_Reprojected.gpkg (Step 1 output)
# Outputs: Bulk Tests/Julia/Target_Golf_Parcels_List.csv


# === 1. USING ===

using GeoDataFrames
using ArchGDAL
using DataFrames
using CSV
using Printf


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR       = @__DIR__
const TARGET_GOLF_PATH = joinpath(SCRIPT_DIR, "Target_Golf_Polygons.gpkg")
const PARCELS_PATH     = joinpath(SCRIPT_DIR, "Honolulu_Parcels_Reprojected.gpkg")
const OUT_CSV          = joinpath(SCRIPT_DIR, "Target_Golf_Parcels_List.csv")

const TMK_CANDIDATES = [
    "TMK", "PARCEL_ID", "Parcel_ID", "parcel_id", "TAX_MAP_KEY",
    "Tax_Map_Key", "tax_map_key", "MAPKEY", "mapkey", "tmk",
]


# === 3. FUNCTIONS ===

function find_tmk_column(df::DataFrame)
    for candidate in TMK_CANDIDATES
        candidate in names(df) && return candidate
    end
    return nothing
end


# === 4. EXECUTION ===

function main()
    println("Phase 5 - Step 2: Parcel Intersection")
    println("Loading datasets from: $SCRIPT_DIR")

    isfile(TARGET_GOLF_PATH) || error("[FATAL] Target Golf Polygons not found. Run Step 1.")
    isfile(PARCELS_PATH)     || error("[FATAL] Reprojected Parcels not found. Run Step 1.")

    # [METHODOLOGY] GeoDataFrames.read — spatial read of Step 1 OSM golf polygons
    target_golf_geo = GeoDataFrames.read(TARGET_GOLF_PATH)
    # [METHODOLOGY] GeoDataFrames.read — spatial read of Step 1 reprojected parcel cadastre
    parcels_geo     = GeoDataFrames.read(PARCELS_PATH)

    println("  -> Loaded $(nrow(target_golf_geo)) target golf polygons.")
    println("  -> Loaded $(nrow(parcels_geo)) parcel features.")
    println("\nPerforming spatial intersection (this may take a moment)...")

    result_tmks  = String[]
    result_geoms = ArchGDAL.IGeometry[]

    # [METHODOLOGY] ArchGDAL.intersection — cookie-cutter of Phase 2 OSM polygons
    #               over the Phase 5 legal cadastre to isolate golf-course parcel fragments
    for i in 1:nrow(target_golf_geo)
        g_geom = target_golf_geo.geometry[i]
        for j in 1:nrow(parcels_geo)
            p_geom = parcels_geo.geometry[j]
            ArchGDAL.intersects(g_geom, p_geom) || continue
            isect = ArchGDAL.intersection(g_geom, p_geom)
            ArchGDAL.isempty(isect) && continue
            ArchGDAL.geomarea(isect) ≈ 0.0 && continue
            # TMK column discovery deferred to first successful intersection
            if isempty(result_tmks) && isnothing(find_tmk_column(parcels_geo))
                println("\n[WARNING] Standard TMK column not found. Available columns:")
                println(names(parcels_geo))
                error("[FATAL] No TMK column identified.")
            end
            tmk_col = find_tmk_column(parcels_geo)
            push!(result_tmks, string(parcels_geo[j, tmk_col]))
            push!(result_geoms, isect)
        end
    end

    println("  -> Intersection complete: $(length(result_geoms)) parcel fragments found.")

    if isempty(result_tmks)
        println("\n[WARNING] No intersections found.")
        error("[FATAL] No parcel fragments identified.")
    end

    println("\nExtracting unique TMK identifiers...")
    unique_tmk_sorted = sort(unique(result_tmks))
    println("  -> Found $(length(unique_tmk_sorted)) unique TMKs across the $(nrow(target_golf_geo)) golf courses.")

    tmk_df = DataFrame(TMK = unique_tmk_sorted)
    CSV.write(OUT_CSV, tmk_df)

    # [METHODOLOGY] ArchGDAL.geomarea — compute legal footprint area from intersection geometry
    total_area_m2 = sum(ArchGDAL.geomarea(g) for g in result_geoms)
    total_acres   = total_area_m2 / 4046.86

    println("\n" * "=" ^ 60)
    println("PARCEL INTERSECTION COMPLETE")
    println("=" ^ 60)
    println("  Total Targeted Courses : $(nrow(target_golf_geo))")
    println("  Total Unique TMKs      : $(length(unique_tmk_sorted))")
    @printf("  Total Legal Footprint  : %s Acres\n", replace(@sprintf("%.2f", total_acres), r"(?<=\d)(?=(\d{3})+\.)" => ","))
    println("-" ^ 60)
    println("[+] Exported TMK List (CSV) : $OUT_CSV")
    println("\n[DONE] Step 2 Complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
