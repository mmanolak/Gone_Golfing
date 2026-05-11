# Purpose: Fit OLS regression with HC1 robust standard errors on each of the
#          5 Julia-generated MICE imputed datasets from Phase 3.
# Inputs:  Phase 3 Economic Merge and MICE Imputation/Jl_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/Julia/Jl_model_results.jls


# === 1. LIBRARIES ===

using Pkg
Pkg.add(["DataFrames", "CSV", "GLM", "CovarianceMatrices", "Serialization"])  # [OUTSTANDING ISSUE] runs on every execution — remove once packages installed

using DataFrames
using CSV
using GLM
using CovarianceMatrices
using Serialization
using Statistics
using LinearAlgebra
using Printf


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR    = @__DIR__
const PHASE3_DIR    = joinpath(
    SCRIPT_DIR, "..", "..", "..", "Phase 3 Economic Merge and MICE Imputation"
)
const OUT_DIR       = SCRIPT_DIR
const JLS_PATH      = joinpath(OUT_DIR, "Jl_model_results.jls")

const FORMULA_STR   = "Log_Opportunity_Cost ~ Holes + county_type"
const M             = 5
const IMPUTED_PATHS = [
    joinpath(PHASE3_DIR, "Jl_Imputed_Dataset_$i.csv") for i in 1:M
]


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

function main()
    missing_files = filter(p -> !isfile(p), IMPUTED_PATHS)
    if !isempty(missing_files)
        println("[FATAL] The following imputed dataset(s) were not found:")
        for p in missing_files
            println("  $p")
        end
        exit(1)
    end

    println("Phase 4 — Model Fitting")
    println("============================================================")
    println("Phase 3 inputs : $PHASE3_DIR")
    println("Output folder  : $OUT_DIR")
    println("Formula        : $FORMULA_STR")
    println("============================================================\n")

    model_results       = []
    first_model_summary = ""

    for (i, path) in enumerate(IMPUTED_PATHS)
        fname = basename(path)
        println("[$i/5] Loading $fname...")

        acreage_df = CSV.read(path, DataFrame)

        if !("osm_acreage" in names(acreage_df))
            error("Column 'osm_acreage' not found in $fname.")
        end
        if !("Baseline_Value_Per_Acre" in names(acreage_df))
            error("Column 'Baseline_Value_Per_Acre' not found in $fname.")
        end

        acreage_df.Total_Opportunity_Cost = acreage_df.osm_acreage .* acreage_df.Baseline_Value_Per_Acre
        acreage_df.Log_Opportunity_Cost   = log1p.(acreage_df.Total_Opportunity_Cost)

        cols_needed = ["Log_Opportunity_Cost", "Holes", "Baseline_Value_Per_Acre", "county_type"]
        n_before    = nrow(acreage_df)
        dropmissing!(acreage_df, cols_needed)
        n_dropped   = n_before - nrow(acreage_df)

        if n_dropped > 0
            println("       Dropped $n_dropped rows with missing values in model columns.")
        end

        acreage_df.county_type = string.(acreage_df.county_type)

        model = lm(@formula(Log_Opportunity_Cost ~ Holes + county_type), acreage_df)  # [METHODOLOGY] OLS — log-linear model for opportunity cost

        # [METHODOLOGY] HC1 robust standard errors — heteroskedasticity-consistent;
        #               HC1 applies n/(n-k) finite-sample correction (manual sandwich)
        X    = modelmatrix(model)
        e    = residuals(model)
        n, k = size(X)
        bread    = inv(X' * X)
        meat     = X' * (X .* (e .^ 2))
        vcov_hc1 = (n / (n - k)) .* (bread * meat * bread)
        bse      = sqrt.(diag(vcov_hc1))

        rsquared_val     = r2(model)
        rsquared_adj_val = adjr2(model)
        nobs_val         = nobs(model)
        df_resid_val     = dof_residual(model)
        params_names     = coefnames(model)
        params_vals      = coef(model)

        param_dict = Dict{String, Float64}(
            params_names[j] => params_vals[j] for j in 1:length(params_names)
        )
        bse_dict = Dict{String, Float64}(
            params_names[j] => bse[j] for j in 1:length(params_names)
        )

        model_data = Dict(
            "params"       => param_dict,
            "bse"          => bse_dict,
            "rsquared"     => rsquared_val,
            "rsquared_adj" => rsquared_adj_val,
            "nobs"         => nobs_val,
            "df_resid"     => df_resid_val,
        )

        push!(model_results, model_data)

        @printf("       Done — R²=%.4f, N=%d, df_resid=%d\n",
                rsquared_val, nobs_val, df_resid_val)

        if i == 1
            io = IOBuffer()
            show(io, MIME("text/plain"), coeftable(model))
            first_model_summary = String(take!(io))
        end
    end

    serialize(JLS_PATH, model_results)

    println("\n[+] Saved $(length(model_results)) model data dicts to:\n    $JLS_PATH")

    println("\n============================================================")
    println("Model 1 Summary (Jl_Imputed_Dataset_1.csv) [Default SEs shown]")
    println("============================================================")
    println(first_model_summary)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
