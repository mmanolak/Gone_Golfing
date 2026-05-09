# Purpose: Pool the 5 per-imputation OLS estimates from model_fitting.jl via
#          Rubin's Rules and save a regression table.
# Inputs:  Bulk Tests/Julia/Jl_model_results.jls
# Outputs: Bulk Tests/Julia/Jl_Regression_Results.csv


# === 1. LIBRARIES ===

using Pkg
Pkg.add(["DataFrames", "CSV", "Serialization", "Distributions"])  # [OUTSTANDING ISSUE] runs on every execution — remove once packages installed

using DataFrames
using CSV
using Serialization
using Statistics
using Printf
using Distributions


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR = @__DIR__
const JLS_PATH   = joinpath(SCRIPT_DIR, "Jl_model_results.jls")
const OUT_CSV    = joinpath(SCRIPT_DIR, "Jl_Regression_Results.csv")


# === 3. FUNCTIONS ===

"""
    get_stars(p) -> String

Return significance stars for a single p-value.
"""
function get_stars(p)
    if isnan(p) return "" end
    if p < 0.001 return "***" end
    if p < 0.01  return "**" end
    if p < 0.05  return "*" end
    if p < 0.1   return "." end
    return ""
end


# === 4. EXECUTION ===

function main()
    if !isfile(JLS_PATH)
        println("[FATAL] Could not find model results file:\n  $JLS_PATH")
        println("  Run model_fitting.jl first.")
        exit(1)
    end

    model_results = deserialize(JLS_PATH)
    num_imp       = length(model_results)

    println("Phase 4 — Parameter Pooling (Rubin's Rules)")
    println("============================================================")
    println("Loaded $num_imp model data lists from:\n  $JLS_PATH\n")

    all_params_set = Set{String}()
    for r in model_results
        union!(all_params_set, keys(r["params"]))
    end
    all_params = collect(all_params_set)
    sort!(all_params)

    if "(Intercept)" in all_params
        filter!(x -> x != "(Intercept)", all_params)
        insert!(all_params, 1, "(Intercept)")
    end

    num_params = length(all_params)
    coef_mat   = fill(NaN, num_imp, num_params)
    var_mat    = fill(NaN, num_imp, num_params)

    for i in 1:num_imp
        for (j, p) in enumerate(all_params)
            if haskey(model_results[i]["params"], p)
                coef_mat[i, j] = model_results[i]["params"][p]
                var_mat[i, j]  = (model_results[i]["bse"][p])^2
            end
        end
    end

    missing_mask = any(isnan.(coef_mat), dims=1)[1, :]
    if any(missing_mask)
        println("[!] The following parameters were absent in at least one model:")
        for (j, p) in enumerate(all_params)
            if missing_mask[j]
                present_in = sum(.!isnan.(coef_mat[:, j]))
                println("      $p  (present in $present_in/$num_imp models)")
            end
        end
        println()
    end

    # [METHODOLOGY] Rubin's Rules — Barnard & Rubin (1999) df approximation
    m_i = Float64.(vec(sum(.!isnan.(coef_mat), dims=1)))
    m_i .= max.(m_i, 2.0)

    q_bar = zeros(num_params)
    v_w   = zeros(num_params)
    v_b   = zeros(num_params)

    for j in 1:num_params
        valid_idx = .!isnan.(coef_mat[:, j])
        q_bar[j]  = mean(coef_mat[valid_idx, j])
        v_w[j]    = mean(var_mat[valid_idx, j])
        v_b[j]    = var(coef_mat[valid_idx, j], corrected=true)
    end

    v_t    = v_w .+ (1.0 .+ 1.0 ./ m_i) .* v_b
    se     = sqrt.(v_t)

    t_stat  = q_bar ./ se
    lambda_ = (1.0 .+ 1.0 ./ m_i) .* v_b ./ v_t
    df_old  = (m_i .- 1.0) ./ (lambda_ .^ 2)
    df_com  = model_results[1]["df_resid"]
    df_obs  = (df_com + 1.0) / (df_com + 3.0) * df_com .* (1.0 .- lambda_)
    df_adj  = 1.0 ./ (1.0 ./ df_old .+ 1.0 ./ df_obs)

    p_val = 2.0 .* ccdf.(TDist.(df_adj), abs.(t_stat))

    sig_stars = get_stars.(p_val)

    pooled_df = DataFrame(
        Parameter = all_params,
        Coef      = q_bar,
        Std_Error = se,
        t_stat    = t_stat,
        df_adj    = df_adj,
        p_value   = p_val,
        Sig       = sig_stars,
        V_within  = v_w,
        V_between = v_b,
        V_total   = v_t,
        FMI       = lambda_,
    )

    @printf("Pooled OLS Regression Results  (M=%d imputations, Rubin's Rules)\n",
            num_imp)
    println("Formula: Log_Opportunity_Cost ~ Holes + county_type")
    println("Robust variance: HC1 | Sig: *** p<.001  ** p<.01  * p<.05  . p<.1")
    println("-" ^ 70)

    header = @sprintf("%-45s %10s %10s %8s %8s  %s",
                      "Parameter", "Coef", "SE", "t", "p", "Sig")
    println(header)
    println("-" ^ 70)

    for i in 1:nrow(pooled_df)
        @printf("%-45s %10.4f %10.4f %8.3f %8.4f  %s\n",
                pooled_df.Parameter[i],
                pooled_df.Coef[i],
                pooled_df.Std_Error[i],
                pooled_df.t_stat[i],
                pooled_df.p_value[i],
                pooled_df.Sig[i])
    end
    println("-" ^ 70)

    r2_vals  = [r["rsquared"]     for r in model_results]
    r2a_vals = [r["rsquared_adj"] for r in model_results]
    n_vals   = [r["nobs"]         for r in model_results]

    @printf("\nModel diagnostics across %d imputations:\n", num_imp)
    @printf("  R²         : mean=%.4f  min=%.4f  max=%.4f\n",
            mean(r2_vals), minimum(r2_vals), maximum(r2_vals))
    @printf("  Adj. R²    : mean=%.4f  min=%.4f  max=%.4f\n",
            mean(r2a_vals), minimum(r2a_vals), maximum(r2a_vals))
    println("  N per model: [$(join(n_vals, ", "))]")

    CSV.write(OUT_CSV, pooled_df)
    @printf("\n[+] Jl_Regression_Results.csv saved to:\n    %s\n", OUT_CSV)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
