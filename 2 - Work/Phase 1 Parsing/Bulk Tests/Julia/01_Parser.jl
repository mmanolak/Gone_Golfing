# Purpose: Parse raw USA golf course CSV via regex into structured fields,
#          deduplicate by coordinate and name, and assign stable course IDs.
# Inputs:  00 - Data Sources/Original Data/Golf Courses-USA.csv
# Outputs: Bulk Tests/Julia/Jl_Phase1_Parsed_Golf_Courses.csv


# === 1. LIBRARIES ===

using CSV, DataFrames


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR = @__DIR__
const ROOT_DIR   = joinpath(SCRIPT_DIR, "..", "..", "..")

const RAW_CSV = joinpath(ROOT_DIR, "00 - Data Sources", "Original Data", "Golf Courses-USA.csv")
const OUT_CSV = joinpath(SCRIPT_DIR, "Jl_Phase1_Parsed_Golf_Courses.csv")


# === 3. FUNCTIONS ===

function name_state_to_name(name_state::String)::String
    m = match(r"^(.+?)\s*-\s*[A-Z]{2}$", name_state)
    return isnothing(m) ? name_state : m.captures[1]
end

function name_state_to_abbr(name_state::String)::String
    m = match(r"([A-Z]{2})$", name_state)
    return isnothing(m) ? "" : m.captures[1]
end

function extract_ownership(details::String)::String
    m = match(r"^\(([^)]+)\)", details)
    return isnothing(m) ? "" : m.captures[1]
end

function extract_holes(details::String)::Int64
    s = lowercase(details)
    m = match(r"\((\d+)\s*hole[s]?\)", s)
    return isnothing(m) ? 18 : parse(Int64, m.captures[1])
end

function extract_zip(details::String)::String
    m = match(r"([A-Z]{2})\s+(\d{5})", details)
    return isnothing(m) ? "" : m.captures[2]
end

function extract_city(details::String)::String
    m = match(r",([^,]+),\s*[A-Z]{2}", details)
    if isnothing(m)
        return ""
    end
    city = m.captures[1]
    city = lstrip(city, [' ', ','])
    city = rstrip(city, [',', ' '])
    return city
end

function extract_address(details::String)::String
    m = match(r"\),\s*(.*?),(?=\s*[^,]+,[A-Z]{2})", details)
    if isnothing(m)
        return ""
    end
    addr = m.captures[1]
    addr = lstrip(addr, [',', ' ', ')'])
    addr = rstrip(addr, [',', ' '])
    return addr
end


# === 4. EXECUTION ===

function main()
    if !isfile(RAW_CSV)
        error("Input file not found: $RAW_CSV")
    end

    courses_df = CSV.read(RAW_CSV, DataFrame; header=0)
    rename!(courses_df, "Column1" => :Longitude, "Column2" => :Latitude,
            "Column3" => :Name_State, "Column4" => :Details)
    original_n = nrow(courses_df)

    courses_df = transform(courses_df,
        :Name_State => ByRow(name_state_to_name) => :Course_Name,
        :Name_State => ByRow(name_state_to_abbr) => :State_Abbr,
        :Details    => ByRow(extract_ownership)  => :Ownership_Type,
        :Details    => ByRow(extract_holes)      => :Holes,
        :Details    => ByRow(extract_zip)        => :Zip_Code,
        :Details    => ByRow(extract_city)       => :City,
        :Details    => ByRow(extract_address)    => :Address
    )

    courses_df.Latitude_rounded  = round.(courses_df.Latitude,  digits=4)
    courses_df.Longitude_rounded = round.(courses_df.Longitude, digits=4)

    courses_df = combine(groupby(courses_df, [:Latitude_rounded, :Longitude_rounded, :Course_Name])) do g
        sort!(g, :Holes, rev=true)
        first(g)
    end

    courses_df.course_id = 1:nrow(courses_df)

    courses_df = select(courses_df,
        :course_id, :Course_Name, :Ownership_Type, :Holes,
        :Address, :City, :State_Abbr, :Zip_Code, :Longitude, :Latitude
    )

    final_n   = nrow(courses_df)
    removed_n = original_n - final_n

    println("\n=== OUTPUT STATISTICS ===")
    println("  Original raw rows:      $original_n")
    println("  Duplicates removed:     $removed_n")
    println("  Final cleaned rows:     $final_n")

    mkpath(dirname(OUT_CSV))
    CSV.write(OUT_CSV, courses_df)
    println("\n  [OK] Saved -> $OUT_CSV")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
