# Purpose: Calculate the total physical footprint of U.S. golf courses (acres)
#          across the 5 MICE-imputed datasets and break it down by county_type
#          (Urban / Rural).  Acreage is a fixed spatial measurement, not a
#          modelled quantity, so pooling is done by simple averaging across
#          imputations; between-imputation variance is reported for transparency.
# Inputs:  Phase 3 Economic Merge and MICE Imputation/Data/Julia/Jl_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/Julia/Jl_National_Acreage_Summary.csv


# === 1. USING ===

using CSV
using DataFrames
using Printf
using Statistics


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR  = @__DIR__
const IMPUTED_DIR = normpath(joinpath(SCRIPT_DIR, "..", "..", "Data", "Julia"))
const OUT_CSV     = joinpath(SCRIPT_DIR, "Jl_National_Acreage_Summary.csv")

const M = 5


# === 3. FUNCTIONS ===

# Pool a vector of per-imputation totals by simple averaging.
# between-imputation variance only (within-variance = 0 for acreage).
function pool_acreage(x::AbstractVector{<:Real})
    q_bar = mean(x)
    v_b   = var(x; corrected = true)
    se    = sqrt(v_b + v_b / length(x))
    return (mean = q_bar, sd_b = sqrt(v_b), ci_lo = q_bar - 1.96 * se, ci_hi = q_bar + 1.96 * se)
end


# === 4. EXECUTION ===

function main()
    println("\n" * "=" ^ 70)
    println("Phase 3 — National Acreage Summary")
    println("=" ^ 70 * "\n")

    # ── Step 1: Load datasets and compute per-imputation totals ───────────────
    println("-" ^ 70)
    println("[Step 1] Loading imputed datasets and computing acreage totals...\n")

    national_totals = zeros(Float64, M)
    by_type_list    = Vector{DataFrame}(undef, M)

    for i in 1:M
        path = joinpath(IMPUTED_DIR, "Jl_Imputed_Dataset_$i.csv")
        isfile(path) || error("[FATAL] File not found:\n  $path")

        df = CSV.read(path, DataFrame)

        national_totals[i] = sum(skipmissing(df.osm_acreage))

        type_sums = combine(
            groupby(df, :county_type),
            :osm_acreage => (x -> sum(skipmissing(x))) => :acreage,
        )
        type_sums.imputation = fill(i, nrow(type_sums))
        by_type_list[i] = type_sums

        urban_acres = only(filter(r -> isequal(r.county_type, "Urban"), type_sums).acreage)
        rural_acres = only(filter(r -> isequal(r.county_type, "Rural"), type_sums).acreage)
        @printf("  Dataset %d:  %s acres  (%s Urban / %s Rural)\n",
            i,
            replace(@sprintf("%d", round(Int, national_totals[i])), r"(?<=\d)(?=(\d{3})+$)" => ","),
            replace(@sprintf("%d", round(Int, urban_acres)),         r"(?<=\d)(?=(\d{3})+$)" => ","),
            replace(@sprintf("%d", round(Int, rural_acres)),         r"(?<=\d)(?=(\d{3})+$)" => ","),
        )
    end

    # ── Step 2: Pool totals ───────────────────────────────────────────────────
    println("\n" * "-" ^ 70)
    println("[Step 2] Pooling across imputations...\n")

    nat_pool = pool_acreage(national_totals)

    all_by_type = vcat(by_type_list...)
    type_groups = groupby(all_by_type, :county_type)
    type_pool   = combine(type_groups) do grp
        p = pool_acreage(grp.acreage)
        DataFrame(
            pooled_acres = p.mean,
            sd_b         = p.sd_b,
            ci_lo        = p.ci_lo,
            ci_hi        = p.ci_hi,
        )
    end
    sort!(type_pool, :pooled_acres, rev = true)

    # ── Console output ────────────────────────────────────────────────────────
    println("=" ^ 70)
    println("NATIONAL ACREAGE SUMMARY — POOLED RESULTS")
    println("=" ^ 70)

    fmt(x) = replace(@sprintf("%d", round(Int, x)), r"(?<=\d)(?=(\d{3})+$)" => ",")

    @printf("\n  %-38s %s\n", "NATIONAL TOTAL (all types)", "Pooled Acres")
    println("  " * "-" ^ 38 * " " * "-" ^ 20)
    @printf("  %-38s %s\n",  "Total U.S. Golf Acreage",  fmt(nat_pool.mean))
    @printf("  %-38s %.2f\n", "Between-Imputation SD",    nat_pool.sd_b)
    @printf("  %-38s %s - %s\n", "95%% CI",               fmt(nat_pool.ci_lo), fmt(nat_pool.ci_hi))

    @printf("\n  %-20s %15s %15s %15s\n", "County Type", "Pooled Acres", "SD (between)", "95% CI")
    println("  " * "-" ^ 20 * " " * "-" ^ 15 * " " * "-" ^ 15 * " " * "-" ^ 15)
    for row in eachrow(type_pool)
        @printf("  %-20s %15s %15.2f %s - %s\n",
            row.county_type,
            fmt(row.pooled_acres),
            row.sd_b,
            fmt(row.ci_lo),
            fmt(row.ci_hi),
        )
    end
    println("=" ^ 70 * "\n")

    # ── Save CSV ──────────────────────────────────────────────────────────────
    national_row = DataFrame(
        Category          = "National Total",
        County_Type       = "All",
        Pooled_Acres      = round(nat_pool.mean, digits = 2),
        SD_Between        = round(nat_pool.sd_b,  digits = 4),
        CI_95_Lower_Acres = round(nat_pool.ci_lo, digits = 2),
        CI_95_Upper_Acres = round(nat_pool.ci_hi, digits = 2),
    )
    type_rows = DataFrame(
        Category          = fill("By County Type", nrow(type_pool)),
        County_Type       = type_pool.county_type,
        Pooled_Acres      = round.(type_pool.pooled_acres, digits = 2),
        SD_Between        = round.(type_pool.sd_b,         digits = 4),
        CI_95_Lower_Acres = round.(type_pool.ci_lo,        digits = 2),
        CI_95_Upper_Acres = round.(type_pool.ci_hi,        digits = 2),
    )
    summary_df = vcat(national_row, type_rows)

    CSV.write(OUT_CSV, summary_df)
    println("  [+] Summary saved -> $(basename(OUT_CSV))")
    println("\n[DONE] National Acreage Summary complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
