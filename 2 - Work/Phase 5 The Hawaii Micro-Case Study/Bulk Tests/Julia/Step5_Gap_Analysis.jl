# Purpose: Merge Step 2 TMKs with the Honolulu cadastral CSV to extract TMK
#          zones and map each zone to its official Oahu geographic district.
# Inputs:  Bulk Tests/Julia/Target_Golf_Parcels_List.csv               (Step 2 output)
#          00 - Data Sources/Honolulu/All_Parcels_-4613852522541990741.csv
# Outputs: Bulk Tests/Julia/Phase5_Step5_Geographic_Breakdown.csv


# === 1. USING ===

using DataFrames
using CSV
using Printf


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR        = @__DIR__
const WORK_DIR          = normpath(joinpath(@__DIR__, "..", "..", ".."))
const HONOLULU_DATA_DIR = joinpath(WORK_DIR, "00 - Data Sources", "Honolulu")
const TMK_LIST_PATH     = joinpath(SCRIPT_DIR, "Target_Golf_Parcels_List.csv")
const TAX_CSV_PATH      = joinpath(HONOLULU_DATA_DIR, "All_Parcels_-4613852522541990741.csv")
const OUT_CSV           = joinpath(SCRIPT_DIR, "Phase5_Step5_Geographic_Breakdown.csv")

const DISTRICT_MAP = Dict(
    "1" => "Honolulu (Urban Core)",
    "2" => "Honolulu (East/Anomalies)",
    "3" => "Honolulu (Anomalies)",
    "4" => "Koolaupoko (Kailua/Kaneohe)",
    "5" => "Koolauloa (North/East)",
    "6" => "Waialua (North Shore)",
    "7" => "Wahiawa (Central)",
    "8" => "Waianae (West)",
    "9" => "Ewa (Kapolei/Pearl City)",
)


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

function main()
    println("\n" * "=" ^ 70)
    println("Phase 5 - Step 5: Geographic Concentration Breakdown")
    println("=" ^ 70 * "\n")

    isfile(TMK_LIST_PATH) || error("[FATAL] TMK list not found. Run Step 2 first.\n  $TMK_LIST_PATH")
    isfile(TAX_CSV_PATH)  || error("[FATAL] Cadastral CSV not found:\n  $TAX_CSV_PATH")

    tmk_df = CSV.read(TMK_LIST_PATH, DataFrame)
    rename!(tmk_df, names(tmk_df)[1] => :TMK)
    tmk_df.TMK_clean = replace.(string.(tmk_df.TMK), r"[^0-9]" => "")

    tax_data    = CSV.read(TAX_CSV_PATH, DataFrame)
    tmk_col_idx = findfirst(c -> occursin(r"^tmk$"i, c), names(tax_data))
    if isnothing(tmk_col_idx)
        println("[FATAL] No TMK column identified in cadastral CSV.")
        println("Available columns: ", names(tax_data))
        error("[FATAL] No TMK column identified.")
    end
    tmk_col = names(tax_data)[tmk_col_idx]
    tax_data.TMK_clean = replace.(string.(tax_data[!, tmk_col]), r"[^0-9]" => "")

    step2_lens = length.(tmk_df.TMK_clean)
    csv_lens   = length.(skipmissing(tax_data.TMK_clean))

    # 8-digit format = Z S PPP QQQ  (3-digit parcel field)
    # 9-digit format = Z S PPP QQQQ (4-digit parcel field, trailing 0 for non-CPR parcels)
    if all(==(8), step2_lens) && all(==(9), csv_lens)
        tmk_df.TMK_clean = tmk_df.TMK_clean .* "0"
    elseif all(==(9), step2_lens) && all(==(8), csv_lens)
        tax_data.TMK_clean = tax_data.TMK_clean .* "0"
    end

    merged_data = innerjoin(tmk_df, tax_data, on = :TMK_clean; makeunique = true)
    # CPR sub-parcel records in the cadastral CSV share a TMK but have null Zone;
    # drop them so only parent parcel records (with zone info) are counted.
    dropmissing!(merged_data, :Zone)

    merged_data.Zone_Code    = string.(merged_data.Zone)
    merged_data.District_Name = map(z -> get(DISTRICT_MAP, z, "Zone $z"), merged_data.Zone_Code)

    geo_summary = combine(
        groupby(merged_data, [:Zone_Code, :District_Name]),
        nrow => :Parcel_Count,
    )
    total_parcels = sum(geo_summary.Parcel_Count)
    geo_summary.Pct_of_Total_Parcels = geo_summary.Parcel_Count ./ total_parcels .* 100
    sort!(geo_summary, :Parcel_Count, rev = true)

    @printf("%-5s %-35s %-15s %-15s\n", "Zone", "Geographic District", "Parcel Count", "% of Parcels")
    println("-" ^ 70)
    for row in eachrow(geo_summary)
        @printf("%-5s %-35s %-15d %.1f%%\n",
                row.Zone_Code, row.District_Name, row.Parcel_Count, row.Pct_of_Total_Parcels)
    end
    println("-" ^ 70)
    @printf("%-5s %-35s %-15d 100.0%%\n", "", "TOTAL", total_parcels)
    println("-" ^ 70)

    CSV.write(OUT_CSV, geo_summary)
    println("\n[+] Geographic Breakdown saved -> $(basename(OUT_CSV))")
    println("\n[DONE] Step 5 Complete. Phase 5 is fully finished!")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
