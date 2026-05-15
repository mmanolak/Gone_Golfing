# Purpose: Generate a Forest Plot of Phase 4 regression coefficients and a
#          MICE Density Plot comparing observed acreage against MICE imputations
#          to visually validate the imputation methodology.
# Inputs:  Phase 4 Econometric Modeling/Data/Julia/Jl_Regression_Results.csv
#          Phase 2 Spatial Polygons and True Acreage/Data/Julia/Jl_Phase2_Acreage_Matched.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/Julia/Jl_Imputed_Dataset_{1..100}.csv
# Outputs: Bulk/Julia/output/5.1_Forest_Plot.png
#          Bulk/Julia/output/5.211_MICE_Density_Jl_n005.png
#          Bulk/Julia/output/5.212_MICE_Density_Jl_n025.png
#          Bulk/Julia/output/5.213_MICE_Density_Jl_n050.png
#          Bulk/Julia/output/5.214_MICE_Density_Jl_n075.png
#          Bulk/Julia/output/5.215_MICE_Density_Jl_n100.png


# === 1. LIBRARIES ===

using CSV
using DataFrames
using CairoMakie
using Printf


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
const IMPUTED_PATHS  = [joinpath(PHASE3_DIR, "Jl_Imputed_Dataset_$(i).csv") for i in 1:M]
const OUTPUT_DIR     = joinpath(SCRIPT_DIR, "output")
const OUT_FOREST     = joinpath(OUTPUT_DIR, "5.1_Forest_Plot.png")

# Each tuple: (n_imputations, output_id, n_suffix)
const DENSITY_CHECKPOINTS = [
    (5,   "5.211", "n005"),
    (25,  "5.212", "n025"),
    (50,  "5.213", "n050"),
    (75,  "5.214", "n075"),
    (100, "5.215", "n100"),
]

const PARAM_LABELS = Dict(
    "(Intercept)"        => "Intercept",
    "Holes"              => "Holes (per 18-hole unit)",
    "county_type: Urban" => "Urban County"
)


# === 3. FUNCTIONS ===

function plot_forest(reg_df::DataFrame, out_path::String)
    labels = map(eachrow(reg_df)) do row
        base = get(PARAM_LABELS, String(row.Parameter), String(row.Parameter))
        row.Sig in ("*", "**", "***") ? base * "  " * row.Sig : base
    end

    order         = sortperm(reg_df.Coef)
    sorted_coef   = reg_df.Coef[order]
    sorted_ci_lo  = (reg_df.Coef .- 1.96 .* reg_df.Std_Error)[order]
    sorted_ci_hi  = (reg_df.Coef .+ 1.96 .* reg_df.Std_Error)[order]
    sorted_labels = labels[order]
    n             = length(order)

    fig = Figure(size = (900, 400))
    ax  = Axis(fig[1, 1];
        yticks        = (1:n, sorted_labels),
        xlabel        = "Coefficient  [Dependent variable: log(Opportunity_Cost)]",
        title         = "Regression Coefficients — Phase 4 MICE-Pooled Model",
        subtitle      = "Point estimates with 95% confidence intervals  |  *** p < 0.001",
        titlesize     = 14,
        subtitlesize  = 11,
        subtitlecolor = "#024731",
        xgridvisible  = true,
        ygridvisible  = false,
    )

    vlines!(ax, 0.0; color = "#888888", linestyle = :dash, linewidth = 0.5)

    rangebars!(ax, collect(Float64.(1:n)), sorted_ci_lo, sorted_ci_hi;
        direction    = :x,
        color        = "#444444",
        linewidth    = 0.75,
        whiskerwidth = 0.2
    )

    scatter!(ax, sorted_coef, Float64.(1:n); color = "#800080", markersize = 12)

    Label(fig[2, 1],
        "Dependent variable: log(Opportunity_Cost). " *
        "OLS estimated on pooled MICE imputations (M = 100) via Rubin's Rules.";
        fontsize  = 10,
        color     = "#800080",
        halign    = :left,
        tellwidth = false
    )
    rowsize!(fig.layout, 2, Fixed(24))

    save(out_path, fig; px_per_unit = 3)
    println("    Saved: $(basename(out_path))")
    return fig
end


function plot_density(phase2_df::DataFrame, imputed_paths::Vector{String}, out_path::String)
    m_count  = length(imputed_paths)
    mice_ids = Set(phase2_df[ismissing.(phase2_df.osm_acreage), :course_id])
    @printf("    Observed: %d parcels  |  MICE targets: %d parcels\n",
        count(.!ismissing.(phase2_df.osm_acreage)),
        length(mice_ids))

    obs_raw = [x for x in phase2_df.osm_acreage if !ismissing(x) && x > 0]
    obs_log = log10.(Float64.(obs_raw))

    # [METHODOLOGY] Each MICE draw provides one plausible imputed osm_acreage for every
    # course that lacked an OSM polygon (identified by missing osm_acreage in Phase 2).
    # Filtering each imputed dataset to mice_ids isolates only the previously-missing rows
    # for distributional comparison against observed parcels.
    imp_logs = Vector{Vector{Float64}}(undef, m_count)
    for i in 1:m_count
        isfile(imputed_paths[i]) || error("Input file not found: $(imputed_paths[i])")
        imp_df      = CSV.read(imputed_paths[i], DataFrame)
        target_rows = imp_df[in.(imp_df.course_id, Ref(mice_ids)), :]
        vals        = [x for x in target_rows.osm_acreage if !ismissing(x) && x > 0]
        imp_logs[i] = log10.(Float64.(vals))
        imp_df      = nothing
        GC.gc()
    end

    break_vals = [1.0, 10.0, 50.0, 200.0, 1000.0, 5000.0]
    break_pos  = log10.(break_vals)
    break_labs = ["1 ac", "10 ac", "50 ac", "200 ac", "1,000 ac", "5,000 ac"]

    fig = Figure(size = (1100, 600))
    ax  = Axis(fig[1, 1];
        xticks        = (break_pos, break_labs),
        xlabel        = "Final Acreage (log₁₀ scale)",
        ylabel        = "Density",
        title         = "Acreage Distribution — Observed vs. MICE Imputations",
        subtitle      = "Log₁₀ scale  |  Observed = measured parcels  |  " *
                        "Imputations = MICE-filled missing values (purple, α = 0.05 per draw)",
        titlesize     = 14,
        subtitlesize  = 11,
        subtitlecolor = "#024731",
        xgridvisible  = false,
        ygridvisible  = false,
    )

    density!(ax, obs_log;
        color       = (:black, 0.0),
        strokecolor = :black,
        strokewidth = 1.3,
    )

    for i in 1:m_count
        density!(ax, imp_logs[i];
            color       = (:purple, 0.05),
            strokecolor = :transparent,
            strokewidth = 0.0,
        )
    end

    Legend(fig[1, 2],
        [
            [LineElement(color = :black, linewidth = 1.3)],
            [PolyElement(color = (:purple, 0.5), strokecolor = :transparent)],
        ],
        ["Observed", "MICE Imputations (n = $m_count)"];
        framevisible = false, labelsize = 11
    )

    Label(fig[2, 1],
        "Alpha-blended density (α = 0.05 per draw): denser regions indicate higher " *
        "agreement across the $m_count MICE imputations.";
        fontsize  = 10,
        color     = "#024731",
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

    println("--- [1/8] Loading regression results")
    reg_df = CSV.read(REGRESSION_CSV, DataFrame)

    println("--- [2/8] Building Forest Plot")
    plot_forest(reg_df, OUT_FOREST)
    reg_df = nothing
    GC.gc()

    println("--- [3/8] Loading observed acreage data")
    phase2_df = CSV.read(PHASE2_CSV, DataFrame)

    for (k, (n, id, nstr)) in enumerate(DENSITY_CHECKPOINTS)
        println("--- [$(3+k)/8] Building MICE Density Plot (n = $n)")
        out_path = joinpath(OUTPUT_DIR, "$(id)_MICE_Density_Jl_$(nstr).png")
        plot_density(phase2_df, IMPUTED_PATHS[1:n], out_path)
    end
    phase2_df = nothing
    GC.gc()

    println()
    println("=== 5_Econometric_Plots.jl complete ===")
    println()
end

main()