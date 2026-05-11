# Purpose: Read golf-course polygons from the pyosmium GeoPackage,
#          recalculate true acreage via ArchGDAL in parallel, filter by
#          plausibility bounds, and save canonical Julia GPKG.
# Inputs:  Bulk Tests/python/Py_Phase2_OSM_Golf_Polygons.gpkg
# Outputs: Bulk Tests/Julia/Jl_Phase2_OSM_Golf_Polygons.gpkg


# === 1. LIBRARIES ===

using DataFrames, GeoDataFrames, ArchGDAL, Statistics


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR    = @__DIR__
const GPKG_IN       = joinpath(SCRIPT_DIR, "..", "python", "Py_Phase2_OSM_Golf_Polygons.gpkg")
const GPKG_OUT      = joinpath(SCRIPT_DIR, "Jl_Phase2_OSM_Golf_Polygons.gpkg")

const MIN_ACRES     = 5.0
const MAX_ACRES     = 1500.0
const SQ_M_PER_ACRE = 4046.8564224


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
    println("Phase 2 - Step 1: Parse OSM Polygons and Calculate True Acreage")
    println("Script: 01_ParseOSM.jl")
    println("=" ^ 80)

    isfile(GPKG_IN) || error("Input GPKG not found: $GPKG_IN")

    println("\n1  Loading golf-course polygons from Python GPKG")
    t0 = time()
    osm_golf_geo = GeoDataFrames.read(GPKG_IN)  # [METHODOLOGY] read from pyosmium GPKG
    raw_count    = nrow(osm_golf_geo)
    println("    Loaded: $(format_number(raw_count)) polygons in $(round(time() - t0, digits = 2))s")

    println("\n2 & 3  Calculating acreage (parallel, $(Threads.nthreads()) threads)")
    area_results = Vector{Float64}(undef, raw_count)
    Threads.@threads for i in 1:raw_count  # [METHODOLOGY] planar area in EPSG:5070
        area_results[i] = ArchGDAL.geomarea(osm_golf_geo.geometry[i]) / SQ_M_PER_ACRE
    end
    osm_golf_geo.osm_acreage = area_results

    println("\n4  Applying plausibility filter ($(MIN_ACRES)–$(MAX_ACRES) acres)")
    osm_golf_geo   = filter(
        row -> row.osm_acreage >= MIN_ACRES && row.osm_acreage <= MAX_ACRES,
        osm_golf_geo
    )
    filtered_count = nrow(osm_golf_geo)
    dropped        = raw_count - filtered_count

    println("\n=== OUTPUT STATISTICS ===")
    println("  Raw polygons before filter:   $(format_number(raw_count))")
    println("  Dropped (< $MIN_ACRES or > $MAX_ACRES acres): $(format_number(dropped))")
    println("  Final polygon count:          $(format_number(filtered_count))")

    ac = osm_golf_geo.osm_acreage
    println("\n  osm_acreage summary:")
    println("    Min:    $(format_decimal(minimum(ac))) acres")
    println("    Median: $(format_decimal(median(ac))) acres")
    println("    Mean:   $(format_decimal(mean(ac))) acres")
    println("    Max:    $(format_decimal(maximum(ac))) acres")

    println("\n  First 5 rows:")
    println(first(select(osm_golf_geo, Not(:geometry)), 5))

    println("\n5  Saving to $GPKG_OUT")
    isfile(GPKG_OUT) && rm(GPKG_OUT)
    GeoDataFrames.write(GPKG_OUT, osm_golf_geo; layer_name = "golf_courses")  # [METHODOLOGY]
    println("  [OK] Saved -> $GPKG_OUT")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
