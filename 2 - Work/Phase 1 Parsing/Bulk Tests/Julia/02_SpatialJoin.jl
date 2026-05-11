# Purpose: Spatial-join parsed golf course points to 2022 US county boundaries
#          using ArchGDAL bounding-box pre-filtering and parallel point-in-polygon.
# Inputs:  Bulk Tests/Julia/Jl_Phase1_Parsed_Golf_Courses.csv
# Outputs: Bulk Tests/Julia/Jl_Phase1_Spatial_Joined_Golf_Courses.csv


# === 1. LIBRARIES ===

using CSV, DataFrames, GeoDataFrames, ArchGDAL, Downloads


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR  = @__DIR__
ROOT_DIR    = joinpath(SCRIPT_DIR, "..", "..", "..")

GOLF_IN    = joinpath(SCRIPT_DIR, "Jl_Phase1_Parsed_Golf_Courses.csv")
OUT_CSV    = joinpath(SCRIPT_DIR, "Jl_Phase1_Spatial_Joined_Golf_Courses.csv")
COUNTY_DIR = joinpath(ROOT_DIR, "00 - Data Sources", "Original Data")
COUNTY_SHP = joinpath(COUNTY_DIR, "cb_2022_us_county_20m.shp")
COUNTY_ZIP = joinpath(COUNTY_DIR, "cb_2022_us_county_20m.zip")
COUNTY_CB  = joinpath(ROOT_DIR, "00 - Data Sources", "Secondary", "cb_2022_us_county_20m.zip")


# === 3. FUNCTIONS ===

"""Format a number with comma thousands separators."""
function format_number(n::Integer)
    s = string(n)
    len = length(s)
    if len <= 3
        return s
    end
    result = ""
    for (i, c) in enumerate(reverse(s))
        if i > 1 && (i-1) % 3 == 0
            result *= ","
        end
        result *= c
    end
    return reverse(result)
end


# === 4. EXECUTION ===

function main()
    if !isfile(GOLF_IN)
        error("Input file not found: $GOLF_IN")
    end

    courses_df = CSV.read(GOLF_IN, DataFrame)
    courses_df = dropmissing(courses_df, [:Longitude, :Latitude])
    original_n = nrow(courses_df)

    # golf course coordinates are in EPSG:4326 — no CRS transform needed
    courses_df.geometry = [ArchGDAL.createpoint(row.Longitude, row.Latitude) for row in eachrow(courses_df)]
    courses_geo = courses_df

    if !isfile(COUNTY_SHP)
        if !isfile(COUNTY_ZIP)
            Downloads.download(COUNTY_CB, COUNTY_ZIP)
        end
        run(`7z x -y -o"$COUNTY_DIR" "$COUNTY_ZIP"`)
    end

    county_geo = GeoDataFrames.read(COUNTY_SHP)
    county_geo = transform(county_geo, :GEOID => ByRow(string) => :FIPS)
    county_geo = select(county_geo,
        :FIPS, :NAME => :County_Name, :STUSPS => :Tigris_State_Abbr, :geometry
    )

    county_envelopes = ArchGDAL.envelope.(county_geo.geometry)

    fips_results        = Vector{Union{String, Missing}}(missing, nrow(courses_geo))
    county_name_results = Vector{Union{String, Missing}}(missing, nrow(courses_geo))
    state_abbr_results  = Vector{Union{String, Missing}}(missing, nrow(courses_geo))

    Threads.@threads for i in 1:nrow(courses_geo)  # [METHODOLOGY]
        pt_geom = courses_geo.geometry[i]
        pt_env  = ArchGDAL.envelope(pt_geom)
        px_min, py_min, px_max, py_max = pt_env.MinX, pt_env.MinY, pt_env.MaxX, pt_env.MaxY

        for j in 1:length(county_envelopes)
            env = county_envelopes[j]
            if px_min >= env.MinX && px_max <= env.MaxX &&
               py_min >= env.MinY && py_max <= env.MaxY
                county_geom = county_geo[!, :geometry][j]
                if ArchGDAL.intersects(pt_geom, county_geom)  # [METHODOLOGY] exact point-in-polygon after bbox pre-filter
                    fips_results[i]        = county_geo[!, :FIPS][j]
                    county_name_results[i] = county_geo[!, :County_Name][j]
                    state_abbr_results[i]  = county_geo[!, :Tigris_State_Abbr][j]
                    break
                end
            end
        end
    end

    courses_geo.FIPS              = fips_results
    courses_geo.County_Name       = county_name_results
    courses_geo.Tigris_State_Abbr = state_abbr_results

    courses_df = select(courses_geo, Not(:geometry))
    courses_df.FIPS = [ismissing(val) ? "" : lpad(string(val), 5, '0') for val in courses_df.FIPS]

    missing_fips = sum(ismissing.(courses_df.FIPS))

    println("\n=== OUTPUT STATISTICS ===")
    println("  Total golf courses:       $(format_number(original_n))")
    println("  Missing FIPS (no county): $missing_fips")

    CSV.write(OUT_CSV, courses_df)
    println("\n  [OK] Saved -> $OUT_CSV")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
