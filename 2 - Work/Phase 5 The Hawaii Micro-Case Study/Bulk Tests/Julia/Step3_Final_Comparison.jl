# Purpose: Cross-reference Oahu golf TMKs against official parcel cadastre and
#          Phase 4 MICE-pooled opportunity cost estimates; apply spatial
#          deduplication and Rubin's Rules to produce the final comparison table.
# Inputs:  Bulk Tests/Julia/Target_Golf_Parcels_List.csv      (Step 2 output)
#          Bulk Tests/Julia/Honolulu_Parcels_Reprojected.gpkg  (Step 1 output)
#          Bulk Tests/Julia/Target_Golf_Polygons.gpkg          (Step 1 output)
#          Phase 4 Econometric Modeling/Data/Julia/Jl_Regression_Results.csv
#          Phase 3 Economic Merge and MICE Imputation/Data/Julia/Jl_Imputed_Dataset_{1..5}.csv
# Outputs: Bulk Tests/Julia/Phase5_Oahu_Comparison.csv


# === 1. USING ===

using GeoDataFrames
using ArchGDAL
using DataFrames
using CSV
using Statistics
using Printf


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR = @__DIR__
const WORK_DIR   = normpath(joinpath(@__DIR__, "..", "..", ".."))

const TMK_LIST_PATH  = joinpath(SCRIPT_DIR, "Target_Golf_Parcels_List.csv")
const PARCELS_GPKG   = joinpath(SCRIPT_DIR, "Honolulu_Parcels_Reprojected.gpkg")
const OSM_POLYS_PATH = joinpath(SCRIPT_DIR, "Target_Golf_Polygons.gpkg")
const OUT_CSV        = joinpath(SCRIPT_DIR, "Phase5_Oahu_Comparison.csv")

const PHASE3_DATA_DIR = joinpath(
    WORK_DIR, "Phase 3 Economic Merge and MICE Imputation", "Data", "Julia"
)
const IMPUTED_PATHS = [
    joinpath(PHASE3_DATA_DIR, "Jl_Imputed_Dataset_$i.csv") for i in 1:5
]
const PHASE4_DATA_DIR = joinpath(WORK_DIR, "Phase 4 Econometric Modeling", "Data", "Julia")
const REGRESSION_CSV  = joinpath(PHASE4_DATA_DIR, "Jl_Regression_Results.csv")

const OSM_DERIVED_ACRES = 8342.28
const M = 5

const OAHU_LAT_MIN =  21.2
const OAHU_LAT_MAX =  21.9
const OAHU_LON_MIN = -158.5
const OAHU_LON_MAX = -157.6


# === 3. FUNCTIONS ===

function add_row!(rows::Vector, metric::AbstractString, value)
    push!(rows, (Metric = String(metric), Value = string(value)))
end

# [METHODOLOGY] createcoordtrans + transform! — in-place reproject using ArchGDAL.jl API;
# ArchGDAL.reproject(geom, ISpatialRef, ISpatialRef) is not defined in this version.
function reproject_geom(geom, src_crs, tgt_crs)
    ArchGDAL.createcoordtrans(src_crs, tgt_crs) do t
        ArchGDAL.transform!(geom, t)
        geom
    end
end

function find_nearest_polygon(pt_osm, polys_geo::DataFrame)
    min_dist   = Inf
    nearest_id = 0
    for j in 1:nrow(polys_geo)
        # [METHODOLOGY] ArchGDAL.distance — distance from course point to OSM polygon
        d = ArchGDAL.distance(pt_osm, polys_geo.geometry[j])
        if d < min_dist
            min_dist   = d
            nearest_id = j
        end
    end
    return nearest_id, min_dist
end


# === 4. EXECUTION ===

function main()
    println("\n" * "=" ^ 70)
    println("Phase 5 - Step 3: Economic Validation")
    println("=" ^ 70)
    println("\n  TMK list      : $TMK_LIST_PATH")
    println("  Parcels GPKG  : $PARCELS_GPKG")
    println("  OSM Polygons  : $OSM_POLYS_PATH")
    println("  Phase 3 dir   : $PHASE3_DATA_DIR")
    println("  Phase 4 dir   : $PHASE4_DATA_DIR")
    println("  Output        : $OUT_CSV\n")

    for (label, path) in [
        ("TMK list (Step 2 output)",     TMK_LIST_PATH),
        ("Parcels GPKG (Step 1 output)", PARCELS_GPKG),
        ("OSM Polygons (Step 1 output)", OSM_POLYS_PATH),
        ("Phase 4 regression CSV",       REGRESSION_CSV),
    ]
        isfile(path) || error("[FATAL] $label not found:\n  $path")
    end

    missing_imp = filter(!isfile, IMPUTED_PATHS)
    if !isempty(missing_imp)
        error("[FATAL] Phase 3 imputed datasets not found:\n  " * join(missing_imp, "\n  "))
    end

    # ---- Step 3.1: Load TMK list ----
    println("-" ^ 70)
    println("[Step 3.1] Loading TMK list...")
    tmk_df = CSV.read(TMK_LIST_PATH, DataFrame)
    rename!(tmk_df, names(tmk_df)[1] => :tmk)
    tmk_df.tmk = string.(tmk_df.tmk)
    println("  Loaded $(nrow(tmk_df)) TMKs.")

    # ---- Step 3.2: Load parcel attributes ----
    println("-" ^ 70)
    println("[Step 3.2] Loading parcel attributes from cadastre GPKG...")
    # [METHODOLOGY] GeoDataFrames.read — spatial read of Step 1 parcel cadastre for attribute join
    parcels_attr = select(GeoDataFrames.read(PARCELS_GPKG), Not(:geometry))

    if "tmk" in names(parcels_attr)
        parcels_attr.tmk = string.(parcels_attr.tmk)
    else
        found = findfirst(c -> c in names(parcels_attr), ["TMK", "tmk8num", "tmk9num", "taxpin", "parcel_uid"])
        isnothing(found) && error("[FATAL] Cannot find a TMK join column in parcels GPKG.")
        rename!(parcels_attr, ["TMK", "tmk8num", "tmk9num", "taxpin", "parcel_uid"][found] => :tmk)
        parcels_attr.tmk = string.(parcels_attr.tmk)
    end

    matched_parcels = innerjoin(tmk_df, parcels_attr, on = :tmk)
    println("  TMKs from Step 2:      $(nrow(tmk_df))")
    println("  Matched in cadastre:   $(nrow(matched_parcels))")

    area_candidates    = ["dpp_approved_area_acres", "dpp_stated_area", "rpa_stated_area"]
    area_col           = findfirst(c -> c in names(matched_parcels) && any(!ismissing, matched_parcels[!, c]), area_candidates)
    official_area_acres = NaN
    if !isnothing(area_col)
        col = area_candidates[area_col]
        official_area_acres = sum(skipmissing(matched_parcels[!, col]))
        println("\n  Official area column used : $col")
        @printf("  Total official area       : %s acres\n", replace(@sprintf("%.2f", official_area_acres), r"(?<=\d)(?=(\d{3})+\.)" => ","))
    end
    @printf("\n  OSM-derived legal footprint (Step 2 geometry): %s acres\n", replace(@sprintf("%.2f", OSM_DERIVED_ACRES), r"(?<=\d)(?=(\d{3})+\.)" => ","))

    # ---- Step 3.3: Load Phase 3 imputations & spatial deduplication ----
    println("-" ^ 70)
    println("[Step 3.3] Loading Phase 3 imputations & applying spatial deduplication...")

    oahu_estimates = Vector{DataFrame}(undef, M)
    for i in 1:M
        df_i = CSV.read(IMPUTED_PATHS[i], DataFrame)
        # [METHODOLOGY] lat/lon bounding box — Oahu extents used to pre-filter national
        #               dataset before spatial deduplication; bounds from island geography
        mask = .!ismissing.(df_i.Longitude) .& .!ismissing.(df_i.Latitude) .&
               (df_i.Latitude  .>= OAHU_LAT_MIN) .& (df_i.Latitude  .<= OAHU_LAT_MAX) .&
               (df_i.Longitude .>= OAHU_LON_MIN) .& (df_i.Longitude .<= OAHU_LON_MAX)
        df_oahu = df_i[mask, :]
        df_oahu.Total_Opportunity_Cost = df_oahu.osm_acreage .* df_oahu.Baseline_Value_Per_Acre
        df_oahu.imputation = fill(i, nrow(df_oahu))
        oahu_estimates[i] = df_oahu
    end

    oahu_all = vcat(oahu_estimates...)
    sizes    = join(string.(nrow.(oahu_estimates)), ", ")
    println("  Oahu courses before deduplication (per imputation): $sizes")
    println("\n  Applying spatial deduplication using OSM polygons...")

    # [METHODOLOGY] GeoDataFrames.read — spatial read of Oahu golf polygons for deduplication
    osm_polys_geo = GeoDataFrames.read(OSM_POLYS_PATH)
    osm_polys_geo.poly_id = 1:nrow(osm_polys_geo)

    unique_courses = combine(
        groupby(oahu_all, [:Longitude, :Latitude]),
        :Holes => maximum => :Holes,
    )

    # importPROJ4 guarantees traditional lon/lat (x=lon, y=lat) axis order;
    # importEPSG(4326) in GDAL 3.x returns lat/lon which would silently swap axes.
    wgs84   = ArchGDAL.importPROJ4("+proj=longlat +datum=WGS84 +no_defs")
    osm_crs = ArchGDAL.getspatialref(osm_polys_geo.geometry[1])

    group_ids = Vector{String}(undef, nrow(unique_courses))
    for i in 1:nrow(unique_courses)
        lon = unique_courses.Longitude[i]
        lat = unique_courses.Latitude[i]
        # [METHODOLOGY] ArchGDAL.createpoint — convert course lat/lon to spatial point
        pt_wgs84 = ArchGDAL.createpoint(lon, lat)
        # [METHODOLOGY] ArchGDAL.reproject — align course point to OSM CRS
        pt_osm   = reproject_geom(pt_wgs84, wgs84, osm_crs)
        # [METHODOLOGY] find_nearest_polygon + 500 m cap — nearest-neighbor match to OSM polygons;
        #               mirrors Phase 2's fallback matching logic; threshold = 500 m spatial tolerance
        nearest_id, dist = find_nearest_polygon(pt_osm, osm_polys_geo)
        group_ids[i] = dist <= 500 ? string(osm_polys_geo.poly_id[nearest_id]) : "orphan_$i"
    end
    unique_courses.group_id = group_ids

    sort!(unique_courses, [:group_id, :Holes], rev = [false, true])
    master_keep = unique(unique_courses, :group_id)
    select!(master_keep, [:Longitude, :Latitude, :Holes])
    println("  Unique Oahu courses after spatial deduplication: $(nrow(master_keep))")

    oahu_deduped_list = Vector{DataFrame}(undef, M)
    for i in 1:M
        df_i = filter(r -> r.imputation == i, oahu_all)
        oahu_deduped_list[i] = innerjoin(df_i, master_keep, on = [:Longitude, :Latitude, :Holes])
    end

    all_deduped = vcat(oahu_deduped_list...)
    agg_spec = [
        :imputation             => length  => :n_imputations,
        :osm_acreage            => mean    => :mean_final_acreage,
        :Baseline_Value_Per_Acre => mean   => :mean_baseline_val,
        :Total_Opportunity_Cost => mean    => :mean_opportunity_cost,
        :Holes                  => first   => :Holes,
    ]
    "county_type" in names(all_deduped) && push!(agg_spec, :county_type => first => :county_type)
    oahu_per_course = combine(groupby(all_deduped, [:Longitude, :Latitude]), agg_spec...)
    sort!(oahu_per_course, :Longitude)

    # [METHODOLOGY] Rubin's Rules — pooling across M imputations; simplified formula
    #               using total-level aggregates (see Phase 4 for full coefficient pooling)
    oahu_agg_dedup = [sum(d.Total_Opportunity_Cost) for d in oahu_deduped_list]
    q_bar = mean(oahu_agg_dedup)
    v_w   = mean([var(d.Total_Opportunity_Cost) for d in oahu_deduped_list])
    v_b   = var(oahu_agg_dedup)
    v_t   = v_w + v_b + v_b / M
    se    = sqrt(v_t)
    ci_lo = q_bar - 2.576 * se
    ci_hi = q_bar + 2.576 * se

    @printf("\n  Deduplicated Pooled Oahu Opportunity Cost: \$%.3fB (99%% CI: \$%.3fB - \$%.3fB)\n",
            q_bar / 1e9, ci_lo / 1e9, ci_hi / 1e9)

    # ---- Step 3.4: Build and save comparison table ----
    println("-" ^ 70)
    println("[Step 3.4] Building and saving comparison table...")

    rows = NamedTuple{(:Metric, :Value), Tuple{String, String}}[]
    add_row!(rows, "Total Golf Courses (Oahu, OSM polygons)", nrow(osm_polys_geo))
    add_row!(rows, "Total Unique TMKs (Step 2)",              replace(@sprintf("%d", nrow(tmk_df)), r"(?<=\d)(?=(\d{3})+$)" => ","))
    add_row!(rows, "TMKs Matched in Cadastre",                replace(@sprintf("%d", nrow(matched_parcels)), r"(?<=\d)(?=(\d{3})+$)" => ","))
    add_row!(rows, "OSM-Derived Legal Footprint (acres)",     @sprintf("%.2f", OSM_DERIVED_ACRES))

    for (i, val) in enumerate(oahu_agg_dedup)
        add_row!(rows, "Oahu Opportunity Cost - Imputation $i (\$B)", @sprintf("%.3f", val / 1e9))
    end

    add_row!(rows, "Pooled Oahu Opportunity Cost - q_bar (\$B)", @sprintf("%.3f", q_bar / 1e9))
    add_row!(rows, "Standard Error (\$B)",                        @sprintf("%.3f", se    / 1e9))
    add_row!(rows, "95% CI Lower (\$B)",                          @sprintf("%.3f", ci_lo / 1e9))
    add_row!(rows, "95% CI Upper (\$B)",                          @sprintf("%.3f", ci_hi / 1e9))

    if !isnan(official_area_acres)
        add_row!(rows, "Total Official Area (acres)", @sprintf("%.2f", official_area_acres))
    end

    comparison_df = DataFrame(rows)

    println("=" ^ 70)
    println("PHASE 5 ECONOMIC VALIDATION - RESULTS")
    println("=" ^ 70)
    for row in eachrow(comparison_df)
        @printf("  %-55s %s\n", row.Metric, row.Value)
    end
    println("=" ^ 70)

    CSV.write(OUT_CSV, comparison_df)
    println("\n[+] Comparison table saved -> $OUT_CSV")

    @printf("\n  Per-Course Summary (%d Oahu courses, averaged across %d imputations):\n",
            nrow(oahu_per_course), M)
    @printf("  %-12s %-12s %-10s %-18s %s\n", "Latitude", "Longitude", "Holes", "Mean Acreage", "Mean Opp. Cost (\$M)")
    println("-" ^ 70)
    for row in eachrow(oahu_per_course)
        @printf("  %-12.4f %-12.4f %-10s %-18.1f \$%.2fM\n",
                row.Latitude, row.Longitude,
                string(row.Holes), row.mean_final_acreage,
                row.mean_opportunity_cost / 1e6)
    end

    println("\n[DONE] Step 3 Complete.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
