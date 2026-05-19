# Purpose: Pool the 5 MICE-imputed aggregate estimates using Rubin's Rules
#          to produce a single national land-value point estimate with 95% CI.
# Inputs:  Bulk Tests/Julia/Jl_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/Julia/Jl_Rubins_Rules_Summary.csv
#
# Rubin's Rules formula summary (m = 5 imputations):
#   q_bar = mean(Q_i)           -- pooled point estimate
#   v_w   = mean(Var_i)         -- within-imputation variance
#   v_b   = var(Q_i, ddof=1)    -- between-imputation variance
#   v_t   = v_w + v_b + v_b/m  -- total variance
#   se    = sqrt(v_t)
#   99%CI = q_bar +/- 2.576 * se


# === 1. LIBRARIES ===

using CSV, DataFrames, Printf, Statistics


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR = @__DIR__
const OUT_CSV    = joinpath(SCRIPT_DIR, "Jl_Rubins_Rules_Summary.csv")

const M = 5


# === 3. FUNCTIONS ===

function run_pooling(in_dir::String, out_csv::String; m_datasets::Int = 5)
    aggregates  = Float64[]
    within_vars = Float64[]

    println("--- 1  Loading imputed datasets and computing aggregates ---\n")

    for i in 1:m_datasets
        fpath = joinpath(in_dir, "Jl_Imputed_Dataset_$i.csv")
        isfile(fpath) || error("Imputed dataset not found: $fpath")

        df = CSV.read(fpath, DataFrame)
        df.Total_Opportunity_Cost = df.osm_acreage .* df.Baseline_Value_Per_Acre

        q_i   = sum(df.Total_Opportunity_Cost)
        var_i = var(df.Total_Opportunity_Cost)

        push!(aggregates,  q_i)
        push!(within_vars, var_i)

        @printf("  Dataset %d:  \$%10.3f B\n", i, q_i / 1e9)
    end

    # [METHODOLOGY] Rubin's Rules pooling — q_bar is the pooled national estimate;
    #               v_t combines within- and between-imputation variance (Rubin 1987)
    println("\n--- 2  Applying Rubin's Rules ---")

    q_bar = mean(aggregates)
    v_w   = mean(within_vars)
    v_b   = var(aggregates; corrected = true)
    v_t   = v_w + v_b + v_b / m_datasets
    se    = sqrt(v_t)
    ci_lo = q_bar - 2.576 * se
    ci_hi = q_bar + 2.576 * se

    println("\n=== RUBIN'S RULES RESULTS ===")
    @printf("  Pooled Aggregate National Value:  \$%10.3f B\n", q_bar / 1e9)
    @printf("  Within-Imputation Variance (v_w): %.4e\n", v_w)
    @printf("  Between-Imputation Variance (v_b):%.4e\n", v_b)
    @printf("  Total Variance (v_t):             %.4e\n", v_t)
    @printf("  Standard Error:                   \$%10.3f B\n", se / 1e9)
    @printf(
        "  99%% Confidence Interval:          \$%10.3f B - \$%10.3f B\n",
        ci_lo / 1e9, ci_hi / 1e9
    )

    pooled_df = DataFrame(
        Metric = vcat(
            [
                "Pooled Aggregate National Value (\$)",
                "Pooled Aggregate National Value (\$B)",
                "Within-Imputation Variance (v_w)",
                "Between-Imputation Variance (v_b)",
                "Total Variance (v_t)",
                "Standard Error (\$)",
                "95% CI Lower (\$B)",
                "95% CI Upper (\$B)",
            ],
            ["Dataset $i Aggregate (\$B)" for i in 1:m_datasets]
        ),
        Value = vcat(
            [
                @sprintf("%.2f",  q_bar),
                @sprintf("%.3f",  q_bar / 1e9),
                @sprintf("%.4e",  v_w),
                @sprintf("%.4e",  v_b),
                @sprintf("%.4e",  v_t),
                @sprintf("%.2f",  se),
                @sprintf("%.3f",  ci_lo / 1e9),
                @sprintf("%.3f",  ci_hi / 1e9),
            ],
            [@sprintf("%.3f", aggregates[i] / 1e9) for i in 1:m_datasets]
        )
    )

    CSV.write(out_csv, pooled_df; header = true)
    println("\n  [OK] Saved -> $out_csv")

    return q_bar, se, ci_lo, ci_hi
end


# === 4. EXECUTION ===

function main()
    run_pooling(SCRIPT_DIR, OUT_CSV; m_datasets = M)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
