# Purpose: Generate a Marginal Effects plot (predicted dollar opportunity costs for
#          Urban vs. Rural courses) and a Raincloud diagnostic comparing observed
#          vs. MICE-imputed acreage distributions.
# Inputs:  Phase 4 Econometric Modeling/Data/Julia/Jl_Regression_Results.csv
#          Phase 2 Spatial Polygons and True Acreage/Data/Julia/Jl_Phase2_Acreage_Matched.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/Julia/Jl_Imputed_Dataset_{1..100}.csv
# Outputs: Bulk/Julia/output/6.1_Marginal_Effects_Dollar_Value.png
#          Bulk/Julia/output/6.2_MICE_Raincloud_Diagnostic.png


# === 1. LIBRARIES ===

using CSV
using DataFrames
using CairoMakie
using Statistics
using Printf
using Random


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR     = @__DIR__
const WORK_DIR       = normpath(joinpath(SCRIPT_DIR, "..", "..", ".."))
const REGRESSION_CSV = joinpath(
    WORK_DIR, "Phase 4 Econometric Modeling", "Data", "Julia",
    "Jl_Regression_Results.csv"
)
const PHASE2_CSV     = joinpath(
    WORK_DIR, "Phase 2 Spatial Polygons and True Acreage", "Data", "Julia",
    "Jl_Phase2_Acreage_Matched.csv"
)
const PHASE3_DIR     = joinpath(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "Julia"
)
const M              = 100
const N_DISPLAY      = 5
const IMPUTED_PATHS  = [joinpath(PHASE3_DIR, "Jl_Imputed_Dataset_$(i).csv") for i in 1:M]
const OUTPUT_DIR     = joinpath(SCRIPT_DIR, "output")
const OUT_MARGINAL   = joinpath(OUTPUT_DIR, "6.1_Marginal_Effects_Dollar_Value.png")
const OUT_RAINCLOUD  = joinpath(OUTPUT_DIR, "6.2_MICE_Raincloud_Diagnostic.png")

const COL_RURAL  = "#5a9e51"
const COL_URBAN  = "#1a6faf"
const IMP_COLORS = ["#e41a1c", "#ff7f00", "#4daf4a", "#377eb8", "#984ea3"]


# === 3. FUNCTIONS ===

function plot_marginal(marginal_df::DataFrame, med_holes::Float64, out_path::String)
    type_order = ["Rural", "Urban"]
    xs         = [1.0, 2.0]
    colors     = [COL_RURAL, COL_URBAN]

    get_val(type, col) = only(marginal_df[marginal_df.type .== type, col])
    est_vals = [get_val(t, :est_M) for t in type_order]
    lo_vals  = [get_val(t, :lo_M)  for t in type_order]
    hi_vals  = [get_val(t, :hi_M)  for t in type_order]

    fig = Figure(size = (700, 600))
    ax  = Axis(fig[1, 1];
        xticks        = (xs, type_order),
        ylabel        = "Expected Opportunity Cost (USD Millions)",
        title         = "Expected Opportunity Cost by County Type",
        subtitle      = "Average golf course converted to highest-value land use  │  " *
                        "Holes fixed at median = $(Int(round(med_holes)))",
        titlesize     = 14,
        subtitlesize  = 10.5,
        subtitlecolor = "#555555",
        xgridvisible  = false,
        ygridvisible  = false,
    )

    errorbars!(ax, xs, est_vals, est_vals .- lo_vals, hi_vals .- est_vals;
        direction    = :y,
        color        = colors,
        linewidth    = 1.0,
        whiskerwidth = 10
    )

    # White backing then colored fill replicates R's double-geom_point outlined-circle effect
    scatter!(ax, xs, est_vals; color = :white, markersize = 16, strokewidth = 0)
    scatter!(ax, xs, est_vals; color = colors,  markersize = 16,
                strokecolor = colors, strokewidth = 1.8)

    text!(ax, xs, hi_vals;
        text     = [@sprintf("\$%.2fM", v) for v in est_vals],
        offset   = (0, 10),
        align    = (:center, :bottom),
        fontsize = 14,
        font     = :bold,
        color    = colors
    )

    xlims!(ax, 0.7, 2.3)
    ylims!(ax, 0.0, maximum(hi_vals) * 1.25)

    ylims!(ax, minimum(lo_vals) * 0.95, maximum(hi_vals) * 1.25)

    Label(fig[2, 1],
        "Model: log(acreage) = β₀ + β₁·Holes + β₂·I(Urban). " *
        "OC = exp(ŷ) × mean land value per acre by county type. " *
        "Error bars: 95% CI (delta method; covariance terms omitted).";
        fontsize  = 8.5,
        color     = "#888888",
        halign    = :left,
        tellwidth = false
    )
    rowsize!(fig.layout, 2, Fixed(28))

    save(out_path, fig; px_per_unit = 3)
    println("    Saved: $(basename(out_path))")
    return fig
end


function plot_raincloud(cloud_df::DataFrame, sampled_imps::Vector{Int}, out_path::String)
    group_levels = vcat(["Observed"], ["Imp. $i" for i in sampled_imps])
    group_colors = vcat(["#1c1c1c"], IMP_COLORS)
    n_groups     = length(group_levels)

    log10_breaks = log10.([1.0, 10.0, 50.0, 200.0, 1000.0, 5000.0])
    log10_labels = ["1", "10", "50", "200", "1,000", "5,000"]

    fig = Figure(size = (1200, 700))
    ax  = Axis(fig[1, 1];
        xticks        = (1:n_groups, group_levels),
        yticks        = (log10_breaks, log10_labels),
        ylabel        = "Final Acreage (log₁₀ scale)",
        title         = "MICE Imputation Diagnostic — Acreage Distribution",
        subtitle      = "Observed parcels (measured) vs. $(length(sampled_imps)) randomly-sampled MICE draws " *
                        "out of $M (imputed parcels only)  │  log₁₀ scale",
        titlesize     = 14,
        subtitlesize  = 10.5,
        subtitlecolor = "#555555",
        xgridvisible  = false,
        ygridvisible  = true,
    )

    Random.seed!(42)
    for (gidx, (label, color)) in enumerate(zip(group_levels, group_colors))
        vals = cloud_df[cloud_df.group .== label, :log10_acreage]
        n    = length(vals)
        n == 0 && continue

        # [METHODOLOGY] Half-violin (side=:right) approximates ggdist::stat_halfeye;
        # the flat edge sits at the group x-position, density extends rightward.
        violin!(ax, fill(gidx, n), vals;
            side        = :right,
            width       = 0.55,
            color       = (color, 0.60),
            strokecolor = color,
            strokewidth = 0.5
        )

        boxplot!(ax, fill(gidx, n), vals;
            width        = 0.12,
            color        = (color, 0.55),
            strokecolor  = "#333333",
            strokewidth  = 0.5,
            whiskerwidth = 0.5,
            outliercolor = :transparent
        )

        jitter_x = fill(Float64(gidx), n) .+ randn(n) .* 0.055
        scatter!(ax, jitter_x, vals;
            color      = (color, 0.20),
            markersize = 3
        )
    end

    Label(fig[2, 1],
        "Note: For visual clarity, only $(length(sampled_imps)) of the $M " *
        "imputed datasets are displayed.";
        fontsize  = 8.5,
        color     = "#888888",
        halign    = :left,
        tellwidth = false
    )
    rowsize!(fig.layout, 2, Fixed(24))

    save(out_path, fig; px_per_unit = 3)
    println("    Saved: $(basename(out_path))")
    return fig
end


# === 4. EXECUTION ===

function main()
    println()
    mkpath(OUTPUT_DIR)

    for f in vcat([REGRESSION_CSV, PHASE2_CSV], IMPUTED_PATHS)
        isfile(f) || error("Input file not found: $f")
    end


    # ── 4.1  Marginal Effects Plot ────────────────────────────────────────────

    println("--- [1/4] Computing marginal effects")

    reg_df    = CSV.read(REGRESSION_CSV, DataFrame)
    phase2_df = CSV.read(PHASE2_CSV, DataFrame)

    lookup_coef(p) = only(reg_df[reg_df.Parameter .== p, :Coef])
    lookup_se(p)   = only(reg_df[reg_df.Parameter .== p, :Std_Error])

    b0       = lookup_coef("(Intercept)")
    b_holes  = lookup_coef("Holes")
    b_urban  = lookup_coef("county_type: Urban")
    se_b0    = lookup_se("(Intercept)")
    se_holes = lookup_se("Holes")
    se_urban = lookup_se("county_type: Urban")

    med_holes  = median([Float64(x) for x in phase2_df.Holes if !ismissing(x)])

    bvpa_rural = mean([Float64(x) for x in
        phase2_df[coalesce.(phase2_df.county_type .== "Rural", false), :Baseline_Value_Per_Acre]
        if !ismissing(x)])
    bvpa_urban = mean([Float64(x) for x in
        phase2_df[coalesce.(phase2_df.county_type .== "Urban", false), :Baseline_Value_Per_Acre]
        if !ismissing(x)])

    # Predicted log-acreage at median holes (Rural = no Urban premium)
    log_hat_rural = b0 + b_holes * med_holes
    log_hat_urban = b0 + b_holes * med_holes + b_urban

    # [METHODOLOGY] Prediction SE via delta method (diagonal variance only;
    # off-diagonal covariance terms omitted, matching the R implementation).
    se_pred_rural = sqrt(se_b0^2 + (med_holes * se_holes)^2)
    se_pred_urban = sqrt(se_b0^2 + (med_holes * se_holes)^2 + se_urban^2)

    make_row(log_hat, se_pred, bvpa, type; z = 1.96) = (
        type  = type,
        est_M = exp(log_hat)               * bvpa / 1e6,
        lo_M  = exp(log_hat - z * se_pred) * bvpa / 1e6,
        hi_M  = exp(log_hat + z * se_pred) * bvpa / 1e6,
    )
    marginal_df = DataFrame([
        make_row(log_hat_rural, se_pred_rural, bvpa_rural, "Rural"),
        make_row(log_hat_urban, se_pred_urban, bvpa_urban, "Urban"),
    ])

    @printf("    Median holes = %g  |  Rural BVpA = \$%.0f  |  Urban BVpA = \$%.0f\n",
        med_holes, bvpa_rural, bvpa_urban)

    rural_row = only(eachrow(marginal_df[marginal_df.type .== "Rural", :]))
    urban_row = only(eachrow(marginal_df[marginal_df.type .== "Urban", :]))
    @printf("    Predicted OC — Rural: \$%.2fM  [%.2fM, %.2fM]\n",
        rural_row.est_M, rural_row.lo_M, rural_row.hi_M)
    @printf("    Predicted OC — Urban: \$%.2fM  [%.2fM, %.2fM]\n",
        urban_row.est_M, urban_row.lo_M, urban_row.hi_M)

    println("--- [2/4] Building Marginal Effects Plot")
    plot_marginal(marginal_df, med_holes, OUT_MARGINAL)


    # ── 4.2  MICE Raincloud Diagnostic ───────────────────────────────────────

    println("--- [3/4] Loading acreage data for raincloud")

    mice_ids = Set(phase2_df[ismissing.(phase2_df.osm_acreage), :course_id])

    rows = Tuple{Float64, String}[]
    for x in phase2_df.osm_acreage
        !ismissing(x) && x > 0 && push!(rows, (log10(Float64(x)), "Observed"))
    end

    # [METHODOLOGY] Each MICE draw provides imputed osm_acreage for courses lacking
    # an OSM polygon (identified by missing osm_acreage in Phase 2). Filtering each
    # imputed dataset to mice_ids isolates only the previously-missing rows.
    # Display sample randomly drawn from 1:M each run (no seed) — the full M=$M
    # set is too crowded to plot directly, so a fresh subset is shown each time.
    sampled_imps = sort(randperm(M)[1:N_DISPLAY])
    @printf("    Display sample (%d of %d): %s\n",
        N_DISPLAY, M, join(["Imp. $i" for i in sampled_imps], ", "))

    for i in sampled_imps
        imp_df = CSV.read(IMPUTED_PATHS[i], DataFrame)
        for row in eachrow(imp_df[in.(imp_df.course_id, Ref(mice_ids)), :])
            !ismissing(row.osm_acreage) && row.osm_acreage > 0 &&
                push!(rows, (log10(Float64(row.osm_acreage)), "Imp. $i"))
        end
    end

    cloud_df = DataFrame(rows, [:log10_acreage, :group])

    n_obs   = count(==("Observed"), cloud_df.group)
    first_label = "Imp. $(sampled_imps[1])"
    n_first = count(==(first_label), cloud_df.group)
    @printf("    Observed: %d rows  |  %s: %d rows\n", n_obs, first_label, n_first)

    println("--- [4/4] Building Raincloud Plot")
    plot_raincloud(cloud_df, sampled_imps, OUT_RAINCLOUD)

    println()
    println("=== 6_Advanced_Econometric_Plots.jl complete ===")
    println()
end

main()
