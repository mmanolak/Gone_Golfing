# Purpose: Match OSM golf-course polygons to Phase 1 baseline points via
#          spatial intersect (point-in-polygon) then 500 m nearest-neighbour
#          fallback using ArchGDAL.
# Inputs:  Phase 1 Parsing/Jl_Phase1_Baseline_Golf_Valuation.csv
#          Bulk Tests/Julia/Jl_Phase2_OSM_Golf_Polygons.gpkg
# Outputs: Bulk Tests/Julia/Jl_Phase2_Acreage_Matched.csv


# === 1. LIBRARIES ===

using CSV, DataFrames, GeoDataFrames, ArchGDAL, Statistics


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR = @__DIR__
const PHASE1_CSV = joinpath(SCRIPT_DIR, "..", "..", "..",
                            "Phase 1 Parsing", "Jl_Phase1_Baseline_Golf_Valuation.csv")
const OSM_GPKG   = joinpath(SCRIPT_DIR, "Jl_Phase2_OSM_Golf_Polygons.gpkg")
const OUT_CSV    = joinpath(SCRIPT_DIR, "Jl_Phase2_Acreage_Matched.csv")

const MAX_NEAREST_M = 500.0


# === 3. FUNCTIONS ===

function format_number(n::Integer)
    s   = string(n)
    length(s) <= 3 && return s
    result = ""
    for (i, c) in enumerate(reverse(s))
        if i > 1 && (i - 1) % 3 == 0
            result *= ","
        end
        result *= c
    end
    return reverse(result)
end

function format_decimal(n::Real, digits::Int = 1)
    (ismissing(n) || isnan(n)) && return "NaN"
    s = string(round(n; digits = digits))
    occursin('.', s) || (s *= ".0")
    parts    = split(s, '.')
    int_part = format_number(parse(Int, parts[1]))
    return int_part * "." * parts[2]
end


# === 4. EXECUTION ===

function main()
    println("=" ^ 80)
    println("Phase 2 - Step 2: Match OSM Polygons to Golf Courses")
    println("Script: 02_MatchOSM.jl")
    println("=" ^ 80)

    for path in (PHASE1_CSV, OSM_GPKG)
        isfile(path) || error("Input file not found: $path")
    end

    # 1. Load Phase 1 points
    println("\n 1  Loading Phase 1 baseline dataset")
    courses_df = CSV.read(PHASE1_CSV, DataFrame)
    courses_df = dropmissing(courses_df, [:Longitude, :Latitude])
    original_n = nrow(courses_df)
    println("    Phase 1 rows: $(format_number(original_n))")

    println("    Projecting coordinates to EPSG:5070...")
    source_crs = ArchGDAL.importPROJ4("+proj=longlat +datum=WGS84 +no_defs")
    target_crs = ArchGDAL.importPROJ4(
        "+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 " *
        "+x_0=0 +y_0=0 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
    )

    pt_geoms = Vector{ArchGDAL.IGeometry}(undef, nrow(courses_df))
    ArchGDAL.createcoordtrans(source_crs, target_crs) do transform  # [METHODOLOGY] EPSG:5070 — equal-area CRS
        for i in 1:nrow(courses_df)
            pt = ArchGDAL.createpoint(courses_df.Longitude[i], courses_df.Latitude[i])
            ArchGDAL.transform!(pt, transform)
            pt_geoms[i] = pt
        end
    end

    # 2. Load OSM polygons
    println("\n 2  Loading OSM golf polygons from GPKG")
    osm_golf_geo = GeoDataFrames.read(OSM_GPKG)  # [METHODOLOGY] read OSM GeoPackage
    poly_geoms   = osm_golf_geo.geometry
    poly_acres   = osm_golf_geo.osm_acreage
    println("    OSM polygons loaded: $(format_number(nrow(osm_golf_geo)))")

    println("    Pre-computing bounding boxes for $(format_number(nrow(osm_golf_geo))) polygons...")
    poly_envelopes = ArchGDAL.envelope.(poly_geoms)

    # 3. Spatial matching: intersects + nearest-neighbor fallback
    println("\n 3a Spatial join (intersects) with 500 m fallback")
    println("    Using $(Threads.nthreads()) threads")

    acreage_results = Vector{Union{Float64, Missing}}(missing, nrow(courses_df))
    fallback_flags  = fill(false, nrow(courses_df))

    Threads.@threads for i in 1:nrow(courses_df)  # [METHODOLOGY] point-in-polygon primary match
        pt          = pt_geoms[i]
        px          = ArchGDAL.getx(pt, 0)
        py          = ArchGDAL.gety(pt, 0)
        match_found = false

        for j in 1:nrow(osm_golf_geo)
            env = poly_envelopes[j]
            if px >= env.MinX && px <= env.MaxX && py >= env.MinY && py <= env.MaxY
                if ArchGDAL.intersects(pt, poly_geoms[j])
                    acreage_results[i] = poly_acres[j]
                    match_found = true
                    break
                end
            end
        end

        if !match_found  # [METHODOLOGY] nearest-feature fallback for unmatched courses
            min_dist = Inf
            best_idx = 0
            for j in 1:nrow(osm_golf_geo)
                env = poly_envelopes[j]
                if px >= (env.MinX - MAX_NEAREST_M) && px <= (env.MaxX + MAX_NEAREST_M) &&
                   py >= (env.MinY - MAX_NEAREST_M) && py <= (env.MaxY + MAX_NEAREST_M)
                    dist = ArchGDAL.distance(pt, poly_geoms[j])
                    if dist <= MAX_NEAREST_M && dist < min_dist
                        min_dist = dist
                        best_idx = j
                    end
                end
            end
            if best_idx > 0
                acreage_results[i] = poly_acres[best_idx]
                fallback_flags[i]  = true
            end
        end
    end

    courses_df.osm_acreage = acreage_results

    # 4. Final stats
    has_acre_mask = .!ismissing.(courses_df.osm_acreage)
    has_acre      = sum(has_acre_mask)
    miss_acre     = sum(ismissing.(courses_df.osm_acreage))
    recovered     = sum(fallback_flags)

    println("\n=== OUTPUT STATISTICS ===")
    println("  Total courses:               $(format_number(original_n))")
    println("  Direct intersect hits:       $(format_number(has_acre - recovered))")
    println("  Recovered via nearest:       $(format_number(recovered))")
    println("  Matched with osm_acreage:    $(format_number(has_acre)) ($(round(100 * has_acre / original_n, digits = 1))%)")
    println("  Missing osm_acreage:         $(format_number(miss_acre))  (MICE target)")

    ac = courses_df.osm_acreage[has_acre_mask]
    if length(ac) > 0
        println("\n  osm_acreage summary (matched only):")
        println("    Min:    $(format_decimal(minimum(ac))) acres")
        println("    Median: $(format_decimal(median(ac))) acres")
        println("    Mean:   $(format_decimal(mean(ac))) acres")
        println("    Max:    $(format_decimal(maximum(ac))) acres")
    end

    # 5. Save
    CSV.write(OUT_CSV, courses_df)
    println("\n  [OK] Saved -> $OUT_CSV")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
