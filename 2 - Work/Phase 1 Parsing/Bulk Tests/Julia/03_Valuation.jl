# Purpose: Left-join USDA ag-land and FHFA residential proxies onto golf courses,
#          then fetch 2023 RUCC codes and assign Baseline_Value_Per_Acre.
# Inputs:  Bulk Tests/Julia/Jl_Phase1_Spatial_Joined_Golf_Courses.csv
#          00 - Data Sources/Original Data/2022 - USDA County Data - Ag Use.csv
#          00 - Data Sources/Original Data/2024 - FHFA June 20 Land Prices.xlsx
#          00 - Data Sources/Secondary/2023-rural-urban-continuum-codes.csv
# Outputs: Bulk Tests/Julia/Jl_Phase1_Baseline_Golf_Valuation.csv


# === 1. LIBRARIES ===

using CSV, DataFrames, XLSX, Printf, Statistics


# === 2. GLOBALS & PATHS ===

SCRIPT_DIR = @__DIR__
ROOT_DIR   = joinpath(SCRIPT_DIR, "..", "..", "..")
DATA_DIR   = joinpath(ROOT_DIR, "00 - Data Sources", "Original Data")

GOLF_IN  = joinpath(SCRIPT_DIR, "Jl_Phase1_Spatial_Joined_Golf_Courses.csv")
USDA_IN  = joinpath(DATA_DIR, "2022 - USDA County Data - Ag Use.csv")
FHFA_IN  = joinpath(DATA_DIR, "2024 - FHFA June 20 Land Prices.xlsx")
RUCC_CSV = joinpath(ROOT_DIR, "00 - Data Sources", "Secondary", "2023-rural-urban-continuum-codes.csv")
OUT_CSV  = joinpath(SCRIPT_DIR, "Jl_Phase1_Baseline_Golf_Valuation.csv")


# === 3. FUNCTIONS ===

function format_fips(x, pad_len::Int)
    if ismissing(x)
        return ""
    end
    # strip trailing ".0" if the value was read as a float
    s = replace(string(x), r"\.0$" => "")
    return lpad(s, pad_len, '0')
end


# === 4. EXECUTION ===

function main()
    for path in (GOLF_IN, USDA_IN, FHFA_IN, RUCC_CSV)
        if !isfile(path)
            error("Input file not found: $path")
        end
    end

    courses_df = CSV.read(GOLF_IN, DataFrame)
    courses_df.FIPS = format_fips.(courses_df.FIPS, 5)
    original_n = nrow(courses_df)

    usda_df = CSV.read(USDA_IN, DataFrame)
    usda_df = filter(row -> row."Data Item" == "AG LAND, INCL BUILDINGS - ASSET VALUE, MEASURED IN \$ / ACRE", usda_df)
    usda_df.State_ANSI  = format_fips.(usda_df[!, "State ANSI"],  2)
    usda_df.County_ANSI = format_fips.(usda_df[!, "County ANSI"], 3)
    usda_df.FIPS = usda_df.State_ANSI .* usda_df.County_ANSI
    usda_df.USDA_Ag_Value_Per_Acre = map(usda_df.Value) do x
        ismissing(x) && return missing
        val = tryparse(Float64, replace(string(x), "," => ""))
        isnothing(val) ? missing : val
    end
    usda_df = dropmissing(select(usda_df, [:FIPS, :USDA_Ag_Value_Per_Acre]), :USDA_Ag_Value_Per_Acre)
    usda_df = unique!(usda_df, :FIPS)

    fhfa_workbook = XLSX.readxlsx(FHFA_IN)
    sheet_names = XLSX.sheetnames(fhfa_workbook)
    target_sheet = nothing
    for name in sheet_names
        if lowercase(strip(name)) == "panel counties"
            target_sheet = name
            break
        end
    end
    if isnothing(target_sheet)
        error("Could not find 'Panel Counties' sheet in FHFA file. Available sheets: $sheet_names")
    end

    # Scan up to row 15 for the header row — FHFA has metadata rows above the table
    sheet_data = fhfa_workbook[target_sheet]
    detected_row = 1
    for r in 1:15
        row_data = sheet_data[r, :]
        if any(x -> !ismissing(x) && occursin("FIPS", string(x)), row_data)
            detected_row = r
            break
        end
    end

    fhfa_df = DataFrame(XLSX.readtable(FHFA_IN, target_sheet; first_row=detected_row))
    if "Year" in names(fhfa_df)
        fhfa_df = filter(row -> row.Year == 2022, fhfa_df)
    end
    fhfa_df.FIPS = format_fips.(fhfa_df.FIPS, 5)

    as_is_col = nothing
    for col in names(fhfa_df)
        if occursin("Per Acre, As-Is", col)
            as_is_col = col
            break
        end
    end
    if isnothing(as_is_col)
        error("Could not find 'Per Acre, As-Is' column in FHFA data")
    end

    fhfa_df.FHFA_Res_Value_Per_Acre = map(fhfa_df[!, as_is_col]) do x
        ismissing(x) && return missing
        val = tryparse(Float64, replace(string(x), "," => ""))
        isnothing(val) ? missing : val
    end
    fhfa_df = dropmissing(select(fhfa_df, [:FIPS, :FHFA_Res_Value_Per_Acre]), :FHFA_Res_Value_Per_Acre)
    fhfa_df = unique!(fhfa_df, :FIPS)

    courses_df = leftjoin(courses_df, usda_df, on=:FIPS)
    courses_df = leftjoin(courses_df, fhfa_df, on=:FIPS)

    rucc_df = CSV.read(RUCC_CSV, DataFrame)
    # RUCC source is long-format with multiple attributes per FIPS — isolate RUCC_2023 to get one code per county
    rucc_df = filter(row -> row.Attribute == "RUCC_2023", rucc_df)
    rucc_df.FIPS = format_fips.(rucc_df.FIPS, 5)
    rucc_df.RUCC_2023 = map(rucc_df.Value) do x
        ismissing(x) && return missing
        val = tryparse(Int64, replace(string(x), "," => ""))
        isnothing(val) ? missing : val
    end
    rucc_df = dropmissing(select(rucc_df, [:FIPS, :RUCC_2023]), :RUCC_2023)
    rucc_df = unique!(rucc_df, :FIPS)

    courses_df = leftjoin(courses_df, rucc_df, on=:FIPS)

    courses_df.county_type = map(courses_df.RUCC_2023) do rucc_val
        if ismissing(rucc_val)
            return missing
        end
        if rucc_val in 1:3
            return "Urban"
        elseif rucc_val in 4:9
            return "Rural"
        else
            return missing
        end
    end

    courses_df.Baseline_Value_Per_Acre = map(
        courses_df.county_type, courses_df.FHFA_Res_Value_Per_Acre, courses_df.USDA_Ag_Value_Per_Acre
    ) do ct, fhfa_val, usda_val
        if ismissing(ct)
            return missing
        elseif ct == "Urban"
            return fhfa_val
        elseif ct == "Rural"
            return usda_val
        else
            return missing
        end
    end

    urban        = count(==("Urban"), skipmissing(courses_df.county_type))
    rural        = count(==("Rural"), skipmissing(courses_df.county_type))
    unclassified = count(ismissing, courses_df.county_type)
    missing_base = count(ismissing, courses_df.Baseline_Value_Per_Acre)
    bv           = courses_df.Baseline_Value_Per_Acre[.!ismissing.(courses_df.Baseline_Value_Per_Acre)]

    println("\n=== OUTPUT STATISTICS ===")
    println("  Total golf courses:       $(lpad(string(original_n), 14, ' '))")
    println("  Urban courses:            $(lpad(string(urban), 14, ' '))")
    println("  Rural courses:            $(lpad(string(rural), 14, ' '))")
    println("  Unclassified (no RUCC):   $unclassified")
    println("  Missing Baseline value:   $(lpad(string(missing_base), 14, ' '))  (MICE imputation target)")

    if !isempty(bv)
        println("\n  Baseline_Value_Per_Acre summary:")
        println("    Min:    \$$(lpad(@sprintf("%.2f", minimum(bv)), 14, ' '))")
        println("    Median: \$$(lpad(@sprintf("%.2f", median(bv)), 14, ' '))")
        println("    Mean:   \$$(lpad(@sprintf("%.2f", mean(bv)), 14, ' '))")
        println("    Max:    \$$(lpad(@sprintf("%.2f", maximum(bv)), 14, ' '))")
    end

    CSV.write(OUT_CSV, courses_df)
    println("\n  [OK] Saved -> $OUT_CSV")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
