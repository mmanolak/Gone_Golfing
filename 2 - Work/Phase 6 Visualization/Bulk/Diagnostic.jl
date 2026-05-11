# Diagnostic_Mod10.jl
# Purpose : Audit per-course Rubin pooling stats for Oahu Golf Courses.
#           Identifies whether wide CIs in the dumbbell plot come from:
#             (a) Missing osm_acreage in Phase 2  → MICE must impute from scratch
#             (b) Unstable MICE imputation        → high between-imputation variance
#             (c) Matching failure                → n_valid < M for some language
#             (d) Language disagreement on mean   → possible Phase 1/2 data issue
#
# Run with: julia Diagnostic_Mod10.jl
# Output:   printed table + Diagnostic_Mod10_Results.csv saved alongside this script.

using CSV, DataFrames, Printf, Statistics


# === GLOBALS & PATHS ===

const SCRIPT_DIR    = @__DIR__
const WORK_DIR      = normpath(joinpath(SCRIPT_DIR, ".."))
const PHASE2_JL_CSV = joinpath(WORK_DIR, "Phase 2 Spatial Polygons and True Acreage",
                                "Data", "Julia", "Jl_Phase2_Acreage_Matched.csv")
const PHASE1_JL_CSV = joinpath(WORK_DIR, "Phase 1 Parsing", "Data", "Julia",
                                "Jl_Phase1_Baseline_Golf_Valuation.csv")
const PHASE3_DIR_PY = joinpath(WORK_DIR, "Phase 3 Economic Merge and MICE Imputation",
                                "Data", "Python")
const PHASE3_DIR_R  = joinpath(WORK_DIR, "Phase 3 Economic Merge and MICE Imputation",
                                "Data", "R")
const PHASE3_DIR_JL = joinpath(WORK_DIR, "Phase 3 Economic Merge and MICE Imputation",
                                "Data", "Julia")
const OUT_CSV       = joinpath(SCRIPT_DIR, "Diagnostic_Mod10_Results.csv")

const M         = 100
const OAHU_FIPS = 15003
const X_MIN_AX  = log10(5e5)
const X_MAX_AX  = log10(2e10)

round_loc(lon, lat) = (round(Float64(lon); digits = 4), round(Float64(lat); digits = 4))


# === FUNCTIONS ===

function rubin_pool(vals::Vector{Float64})
    n = length(vals)
    n == 0 && return (est = NaN, se = NaN, n = 0, cv = NaN)
    q̄  = mean(vals)
    B  = n > 1 ? var(vals) : 0.0
    T  = B * (1.0 + 1.0 / n)
    se = sqrt(max(T, 0.0))
    cv = q̄ > 0 ? se / q̄ : NaN
    (est = q̄, se = se, n = n, cv = cv)
end

function ci_flag(est_M, se_M)
    (isnan(est_M) || isnan(se_M)) && return "NO_DATA"
    q_lo = (est_M - 1.96 * se_M) * 1e6
    q_hi = (est_M + 1.96 * se_M) * 1e6
    flags = String[]
    q_lo <= 0                      && push!(flags, "CI_lo<=0")
    log10(max(q_hi, 1)) > X_MAX_AX && push!(flags, "CI_hi>axis")
    se_M / est_M > 1.0             && push!(flags, "CV>100%")
    isempty(flags) ? "OK" : join(flags, "|")
end


# === EXECUTION ===

for f in [PHASE1_JL_CSV, PHASE2_JL_CSV]
    isfile(f) || error("Input file not found: $f")
end

println("\n=== Diagnostic_Mod10: Loading Phase 1 + Phase 2 baseline ===\n")

baseline  = CSV.read(PHASE1_JL_CSV, DataFrame)
oahu_base = baseline[coalesce.(baseline.FIPS .== OAHU_FIPS, false), :]
n_courses = nrow(oahu_base)
@printf("    Oahu courses in Phase 1 baseline: %d\n", n_courses)

course_ids   = Int.(oahu_base.course_id)
course_names = String.(oahu_base.Course_Name)
fhfa_vals    = Float64.(oahu_base.FHFA_Res_Value_Per_Acre)
lons         = Float64.(oahu_base.Longitude)
lats         = Float64.(oahu_base.Latitude)

id_to_idx    = Dict(course_ids[i] => i for i in 1:n_courses)
coord_to_idx = Dict(round_loc(lons[i], lats[i]) => i for i in 1:n_courses)

# Phase 2 acreage check — missing here means MICE imputed from scratch
ph2      = CSV.read(PHASE2_JL_CSV, DataFrame)
ph2_oahu = ph2[coalesce.(ph2.FIPS .== OAHU_FIPS, false), :]

ph2_acreage = Dict{Int, Union{Float64, Missing}}()
for row in eachrow(ph2_oahu)
    cid = Int(row.course_id)
    ph2_acreage[cid] = ismissing(row.osm_acreage) ? missing : Float64(row.osm_acreage)
end

phase2_obs = [get(ph2_acreage, course_ids[i], missing) for i in 1:n_courses]

oc_jl = [Float64[] for _ in 1:n_courses]
oc_py = [Float64[] for _ in 1:n_courses]
oc_r  = [Float64[] for _ in 1:n_courses]

println("--- Pooling Julia (M=$(M)) ---")
for i in 1:M
    path = joinpath(PHASE3_DIR_JL, "Jl_Imputed_Dataset_$(i).csv")
    isfile(path) || error("Input file not found: $path")
    df = CSV.read(path, DataFrame)
    for row in eachrow(df[coalesce.(df.FIPS .== OAHU_FIPS, false), :])
        idx = get(id_to_idx, Int(row.course_id), 0)
        idx == 0 && continue
        v = row.osm_acreage
        !ismissing(v) && Float64(v) > 0 &&
            push!(oc_jl[idx], Float64(v) * fhfa_vals[idx] / 1e6)
    end
    df = nothing; GC.gc()
end

println("--- Pooling Python (M=$(M)) ---")
for i in 1:M
    path = joinpath(PHASE3_DIR_PY, "Py_Imputed_Dataset_$(i).csv")
    isfile(path) || error("Input file not found: $path")
    df = CSV.read(path, DataFrame)
    for row in eachrow(df)
        ismissing(row.FIPS) && continue
        row.FIPS != Float64(OAHU_FIPS) && continue
        loc = round_loc(row.Longitude, row.Latitude)
        idx = get(coord_to_idx, loc, 0)
        idx == 0 && continue
        v = row.osm_acreage
        !ismissing(v) && Float64(v) > 0 &&
            push!(oc_py[idx], Float64(v) * fhfa_vals[idx] / 1e6)
    end
    df = nothing; GC.gc()
end

println("--- Pooling R (M=$(M)) ---")
for i in 1:M
    path = joinpath(PHASE3_DIR_R, "R_Imputed_Dataset_$(i).csv")
    isfile(path) || error("Input file not found: $path")
    df = CSV.read(path, DataFrame)
    for row in eachrow(df)
        loc = round_loc(row.Longitude, row.Latitude)
        idx = get(coord_to_idx, loc, 0)
        idx == 0 && continue
        v = row.final_acreage
        !ismissing(v) && Float64(v) > 0 &&
            push!(oc_r[idx], Float64(v) * fhfa_vals[idx] / 1e6)
    end
    df = nothing; GC.gc()
end

# Build results
rows = []
for i in 1:n_courses
    rpy = rubin_pool(oc_py[i])
    rr  = rubin_pool(oc_r[i])
    rjl = rubin_pool(oc_jl[i])

    p2_missing = ismissing(phase2_obs[i])
    p2_str     = p2_missing ? "MISSING" : @sprintf("%.1f", phase2_obs[i])

    means       = filter(isfinite, [rpy.est, rr.est, rjl.est])
    mean_spread = length(means) >= 2 ?
        (maximum(means) / max(minimum(means), 1e-9)) : NaN
    mean_flag   = (!isnan(mean_spread) && mean_spread > 3.0) ?
        "MEAN_DISAGREE($(round(mean_spread, digits=1))x)" : ""

    push!(rows, (
        course         = first(String(course_names[i]), 45),
        ph2_acreage_ac = p2_str,
        n_py           = rpy.n,
        mean_py_M      = isnan(rpy.est) ? NaN : round(rpy.est, digits=3),
        se_py_M        = isnan(rpy.se)  ? NaN : round(rpy.se,  digits=3),
        cv_py          = isnan(rpy.cv)  ? NaN : round(rpy.cv,  digits=3),
        ci_py          = ci_flag(rpy.est, rpy.se),
        n_r            = rr.n,
        mean_r_M       = isnan(rr.est)  ? NaN : round(rr.est,  digits=3),
        se_r_M         = isnan(rr.se)   ? NaN : round(rr.se,   digits=3),
        cv_r           = isnan(rr.cv)   ? NaN : round(rr.cv,   digits=3),
        ci_r           = ci_flag(rr.est, rr.se),
        n_jl           = rjl.n,
        mean_jl_M      = isnan(rjl.est) ? NaN : round(rjl.est, digits=3),
        se_jl_M        = isnan(rjl.se)  ? NaN : round(rjl.se,  digits=3),
        cv_jl          = isnan(rjl.cv)  ? NaN : round(rjl.cv,  digits=3),
        ci_jl          = ci_flag(rjl.est, rjl.se),
        mean_spread_x  = isnan(mean_spread) ? NaN : round(mean_spread, digits=2),
        notes          = join(filter(!isempty, [
            p2_missing ? "PH2_MISSING_ACREAGE" : "",
            mean_flag,
        ]), " | "),
    ))
end

df_out = DataFrame(rows)

println("\n\n=== FLAGGED COURSES ===\n")
flagged = df_out[
    (df_out.ci_py .!= "OK") .| (df_out.ci_r .!= "OK") .| (df_out.ci_jl .!= "OK") .|
    (df_out.notes .!= ""), :]

for r in eachrow(flagged)
    println("  $(r.course)")
    println("    Phase 2 acreage : $(r.ph2_acreage_ac) acres")
    println("    Python  n=$(r.n_py)  mean=\$$(r.mean_py_M)M  SE=\$$(r.se_py_M)M  CV=$(r.cv_py)  → $(r.ci_py)")
    println("    R       n=$(r.n_r)   mean=\$$(r.mean_r_M)M   SE=\$$(r.se_r_M)M   CV=$(r.cv_r)   → $(r.ci_r)")
    println("    Julia   n=$(r.n_jl)  mean=\$$(r.mean_jl_M)M  SE=\$$(r.se_jl_M)M  CV=$(r.cv_jl)  → $(r.ci_jl)")
    println("    Notes   : $(r.notes)")
    println()
end

println("""
=== HOW TO READ THE FLAGS ===

  PH2_MISSING_ACREAGE   osm_acreage was NULL in Phase 2 for this course.
                         MICE imputed acreage from scratch every draw.
                         High SE is expected — reflects genuine uncertainty.
                         Action: verify Phase 2 OSM polygon search found nothing.
                         If a real polygon exists, Phase 2 may need a re-run.

  CI_lo<=0              Lower 95% CI bound went negative (SE > mean/1.96).
                         Almost always co-occurs with PH2_MISSING_ACREAGE.
                         Bar is clamped to plot left edge — not a code bug.

  CI_hi>axis            Upper 95% CI exceeds the \$20B axis limit.
                         Same cause. Bar clamped to plot right edge.

  CV>100%               Coefficient of variation > 1.0 (SE > mean).
                         Imputation is very uncertain for this course.

  MEAN_DISAGREE(Nx)     The three language mean estimates differ by factor N.
                         If N > 5 and Phase 2 acreage is NOT missing, this
                         may indicate a Phase 1 or Phase 2 data issue.
                         If Phase 2 acreage IS missing, large N is expected.
""")

CSV.write(OUT_CSV, df_out)
println("Full results saved to: $(OUT_CSV)")
println("=== Diagnostic complete ===\n")
