# Purpose: Run MICE imputation (m=5) on the Phase 2 acreage-matched dataset
#          to fill missing osm_acreage and Baseline_Value_Per_Acre values.
# Inputs:  Phase 2 Spatial Polygons and True Acreage/
#            Jl_Phase2_Acreage_Matched.csv
# Outputs: Bulk Tests/Julia/Jl_Imputed_Dataset_{1..5}.csv


# === 1. LIBRARIES ===

using CategoricalArrays, CSV, DataFrames, Mice, Printf, Random, Statistics


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR = @__DIR__
const INPUT_CSV  = joinpath(
    SCRIPT_DIR, "..", "..", "..",
    "Phase 2 Spatial Polygons and True Acreage",
    "Jl_Phase2_Acreage_Matched.csv"
)
const OUT_DIR = SCRIPT_DIR

const M             = 5
const IMPUTE_COLS   = [:osm_acreage, :Baseline_Value_Per_Acre]
const PREDICTOR_COLS = [:Holes, :Course_Type, :county_type, :Longitude, :Latitude]


# === 3. FUNCTIONS ===

function run_imputation(input_csv::String, out_dir::String; m_datasets::Int = 5)
    # 1. Load ----------------------------------------------------------------
    println("--- 1  Loading Phase 2 acreage-matched dataset ---")

    isfile(input_csv) || error("Input file not found: $input_csv")

    acreage_df = CSV.read(input_csv, DataFrame)
    println("    Rows: $(size(acreage_df, 1))")
    println("    Missing osm_acreage:            $(sum(ismissing, acreage_df.osm_acreage))")
    println("    Missing Baseline_Value_Per_Acre: $(sum(ismissing, acreage_df.Baseline_Value_Per_Acre))")

    # 2. Prepare -------------------------------------------------------------
    println("--- 2  Preparing imputation frame ---")

    acreage_df.Holes = [
        ismissing(x) || string(x) == "" ? missing :
        parse(Float64, string(x))
        for x in acreage_df.Holes
    ]
    acreage_df.Course_Type = categorical(acreage_df.Ownership_Type)
    acreage_df.county_type = categorical(acreage_df.county_type)

    model_cols = vcat(PREDICTOR_COLS, IMPUTE_COLS)
    imp_df     = acreage_df[!, model_cols]

    # 3. Run MICE ------------------------------------------------------------
    println("--- 3  Running MICE imputation (m=$m_datasets) ---")
    # [METHODOLOGY] Mice.jl MICE — m=5 multiply-imputed datasets, iter=5;
    #               see Van Buuren (2018) for methodology
    imputed_list = mice(imp_df, m = m_datasets, iter = 5)

    # 4. Save each imputed dataset -------------------------------------------
    println("\n--- 4  Saving $m_datasets imputed datasets ---")

    for i in 1:m_datasets
        completed = complete(imputed_list, i)

        completed.osm_acreage            = clamp.(completed.osm_acreage, 0, Inf)
        completed.Baseline_Value_Per_Acre = clamp.(
            completed.Baseline_Value_Per_Acre, 0, Inf
        )

        out = copy(acreage_df)
        out.osm_acreage            = completed.osm_acreage
        out.Baseline_Value_Per_Acre = completed.Baseline_Value_Per_Acre

        fname = joinpath(out_dir, "Jl_Imputed_Dataset_$i.csv")
        CSV.write(fname, out; header = true, quote_empty_string = false)
        println("    [OK] $fname")
    end

    # 5. Verification report (Dataset 1) -------------------------------------
    ds1 = CSV.read(joinpath(out_dir, "Jl_Imputed_Dataset_1.csv"), DataFrame)

    println("\n=== IMPUTATION VERIFICATION (Dataset 1) ===")
    println("  Method: Mice.jl")
    println("  Datasets generated:     $m_datasets")
    println("  Iterations per dataset: 5")

    for col in IMPUTE_COLS
        s = ds1[!, col]
        println("\n  $col:")
        println("    Missing:  $(sum(ismissing, s))")
        @printf "    Min:      %14.2f\n" minimum(s)
        @printf "    Median:   %14.2f\n" median(s)
        @printf "    Mean:     %14.2f\n" mean(s)
        @printf "    Max:      %14.2f\n" maximum(s)
        println("    Negative: $(sum(<(0), s))")
    end
end


# === 4. EXECUTION ===

function main()
    run_imputation(INPUT_CSV, OUT_DIR; m_datasets = M)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
