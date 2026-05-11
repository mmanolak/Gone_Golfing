# Purpose: Diagnostic merge of Step 2 TMKs against the Honolulu cadastral CSV
#          to verify TMK format compatibility before Step 5 geographic analysis.
# Inputs:  Bulk Tests/Julia/Target_Golf_Parcels_List.csv             (Step 2 output)
#          00 - Data Sources/Honolulu/All_Parcels_-4613852522541990741.csv
#          00 - Data Sources/Honolulu/Cadastral_2020_8454252231025374231.csv
# Outputs: (console diagnostic output only)


# === 1. USING ===

using DataFrames
using CSV
using Printf


# === 2. GLOBALS & PATHS ===

const SCRIPT_DIR        = @__DIR__
const WORK_DIR          = normpath(joinpath(@__DIR__, "..", "..", ".."))
const HONOLULU_DATA_DIR = joinpath(WORK_DIR, "00 - Data Sources", "Honolulu")
const TMK_LIST_PATH     = joinpath(SCRIPT_DIR, "Target_Golf_Parcels_List.csv")

const TAX_CSV_CANDIDATES = [
    joinpath(HONOLULU_DATA_DIR, "All_Parcels_-4613852522541990741.csv"),
    joinpath(HONOLULU_DATA_DIR, "Cadastral_2020_8454252231025374231.csv"),
]


# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===

function main()
    println("\n" * "=" ^ 70)
    println("Phase 5 - Step 4: Tax Assessment Merge (Diagnostic)")
    println("=" ^ 70 * "\n")

    isfile(TMK_LIST_PATH) || error("[FATAL] TMK list not found. Run Step 2 first.\n  $TMK_LIST_PATH")

    tmk_df = CSV.read(TMK_LIST_PATH, DataFrame)
    rename!(tmk_df, names(tmk_df)[1] => :TMK)
    tmk_df.TMK_clean = replace.(string.(tmk_df.TMK), r"[^0-9]" => "")

    tax_file = findfirst(isfile, TAX_CSV_CANDIDATES)
    if isnothing(tax_file)
        candidates = join(TAX_CSV_CANDIDATES, "\n  ")
        error("[FATAL] No Honolulu cadastral CSV found. Expected:\n  $candidates")
    end
    tax_data = CSV.read(TAX_CSV_CANDIDATES[tax_file], DataFrame)

    println("--- DIAGNOSTIC INFO ---")
    println("All Columns in Honolulu CSV:")
    println(names(tax_data))

    tmk_col_idx = findfirst(c -> occursin(r"^tmk$|parcel_id|tax_map_key|pin"i, c), names(tax_data))
    if isnothing(tmk_col_idx)
        error("[FATAL] No TMK column identified in cadastral CSV.")
    end
    tmk_col = names(tax_data)[tmk_col_idx]

    tax_data.TMK_clean = replace.(string.(tax_data[!, tmk_col]), r"[^0-9]" => "")

    println("\nFirst 5 TMKs from Step 2 (Target Golf Courses):")
    println(tmk_df.TMK_clean[1:min(5, nrow(tmk_df))])
    println("\nFirst 5 TMKs from Honolulu CSV:")
    println(tax_data.TMK_clean[1:min(5, nrow(tax_data))])
    println("-----------------------\n")

    step2_lens = length.(tmk_df.TMK_clean)
    csv_lens   = length.(skipmissing(tax_data.TMK_clean))

    # 8-digit format = Z S PPP QQQ  (3-digit parcel field)
    # 9-digit format = Z S PPP QQQQ (4-digit parcel field, trailing 0 for non-CPR parcels)
    # Conversion: append '0' to the shorter set to align parcel fields.
    if all(==(8), step2_lens) && all(==(9), csv_lens)
        println("[AUTO-FIX] Step 2 TMKs are 8-digit; appending '0' to match 9-digit CSV format...")
        tmk_df.TMK_clean = tmk_df.TMK_clean .* "0"
    elseif all(==(9), step2_lens) && all(==(8), csv_lens)
        println("[AUTO-FIX] CSV TMKs are 8-digit; appending '0' to match 9-digit Step 2 format...")
        tax_data.TMK_clean = tax_data.TMK_clean .* "0"
    end

    merged_data   = innerjoin(tmk_df, tax_data, on = :TMK_clean; makeunique = true)
    matched_count = nrow(merged_data)

    @printf("  Successfully matched %d out of %d TMKs (%.1f%%).\n",
            matched_count, nrow(tmk_df), matched_count / nrow(tmk_df) * 100)

    if matched_count > 0
        println("\n[SUCCESS] The TMKs are now matching! Please paste this output back " *
                "so I can see the column names and write the final Step 5 script.")
    else
        println("\n[FAIL] Still 0 matches. Please paste this output back " *
                "so I can analyze the TMK formats.")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
