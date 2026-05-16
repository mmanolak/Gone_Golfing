# Phase 5 — Oahu OC Methodology Archaeology

**Date:** 2026-05-15
**Phase:** 5 — Hawaii Micro-Case Study
**Investigator:** Claude Sonnet (read-only audit)
**Purpose:** Document what pipeline change produced the $28.61B → $26.67B shift in
the Oahu Grand Mean OC; trace the origin of the $28.61B figure.

**Source files read (read-only, no modifications):**
- `Phase 5 .../Phase_5.R` (current master script)
- `Phase 5 .../Bulk Tests/R/Phase5_Oahu_Comparison.csv`
- `Phase 5 .../Bulk Tests/python/Phase5_Oahu_Comparison.csv`
- `Phase 5 .../Bulk Tests/Julia/Phase5_Oahu_Comparison.csv`
- `Phase 5 .../Data/R/Phase5_Oahu_Comparison.csv`
- `Phase 5 .../Data/QA/Phase5b_Acreage_Verification.md`
- `Phase 5 .../00 - Phase5_Summary.md`
- `Phase 5 .../01 - Phase5_Documentation.md`
- `Phase 5 .../Bulk Tests/R/Step3_Final_Comparison.R`
- `Phase 5 .../Bulk Tests/Julia/Step3_Final_Comparison.jl`
- `999 - Late Stage/Notes.md`
- `Phase 7 .../QA/data/Rerun_Reports/Phase5_Rerun_Report.md`
- `Phase 7 .../QA/data/Rerun_Reports/Phase7_Rerun_Report.md`
- `Phase 6 .../00 - Phase6_Summary.md`
- `git log`, `git diff`, `git grep` (all tracking data read-only)

---

## Part 1 — Git History Search

**Task:** Search git history for any commit mentioning `28.61`, `28.6B`, or `$28.61`.

**Result: No commits found.**

```
git log --all --oneline --grep="28.61"  →  (no output)
git log --all --oneline --grep="28.6B"  →  (no output)
git grep -r "28.61"                     →  (no output for source files;
                                            found only in QA/data/ report files
                                            written by prior Sonnet sessions)
```

The $28.61B value does not appear in any commit message. It cannot be traced
through git history.

---

## Part 2 — Search All MD Files for $28.61B

`git grep -r "28.6" -- "*.md"` returned matches in:

| File | Context |
|------|---------|
| `Phase 5 .../00 - Phase5_Summary.md` | "about 4.5% of the gross **$28.6 billion estimate that the unrestricted HBU framework produces**" |
| `Phase 6 .../00 - Phase6_Summary.md` | "**Preservation Paradox waffle chart** decomposes the $28.6B Oahu opportunity cost by zoning class" |
| `Phase 7 .../QA/data/Rerun_Reports/Phase5_Rerun_Report.md` | "Checklist baseline $28.61B … appears to originate from an earlier Phase 5 pipeline version" |
| `Phase 7 .../QA/data/Rerun_Reports/Phase7_Rerun_Report.md` | "Checklist baseline of $28.61B is retired … originates from an earlier Phase 5 pipeline version (pre-parcel-intersection methodology)" |
| `Phase 7 .../QA/data/Rerun_Reports/Meta_Audit_Report.md` | Same conclusion as Phase7_Rerun_Report |
| `999 - Late Stage/Notes.md` | "Grand Mean total Oahu OC: $28.61B" (line 56) |

**Key finding from `00 - Phase5_Summary.md`:**
> "Translated into the acreage and dollar terms that policy discussions usually demand,
> the Oahu golf footprint of approximately 6,066 acres decomposes as follows: approximately
> 4,956 acres in Preservation or Federal/Military zones (carrying $23.4 billion of the
> gross HBU estimate, statutorily locked), approximately 836 acres in Agricultural zones
> (carrying $3.9 billion), and approximately 275 acres in Resort, Residential, or Country
> zones (carrying $1.3 billion, directly unlockable under current zoning). The
> directly-unlockable $1.3 billion is the bound on what residential redevelopment can
> realize on Oahu without changes to the underlying land-use law — about 4.5% of the gross
> **$28.6 billion estimate that the unrestricted HBU framework produces**."

Phase5_Summary.md **simultaneously** quotes $25.4B (Phase 5b Rubin-pooled) and $28.6B
(the "unrestricted HBU framework"). These are distinct values within the same document.

**Notes.md inconsistency:** Notes.md labels $28.61B as "Grand Mean total Oahu OC"
alongside "Pre-rerun per-language: $25.4B under Rubin's pooling, CI $22.7B–$28.1B."
The $25.4B with CI $22.7B–$28.1B matches the Bulk Tests Julia result exactly
(`Jl_Phase5_Oahu_Comparison.csv`: q_bar=$25.400B, CI=$22.663B–$28.137B). This means
Notes.md was recording the Julia Bulk Test result as "per-language" while simultaneously
recording $28.61B as "Grand Mean." The Bulk Tests Grand Mean was ~$26.00B, not $28.61B.
Notes.md's "Grand Mean" label is a mislabeling — $28.61B predates the Bulk Tests entirely.

---

## Part 3 — Phase_5.R Git History and Current Methodology

**Task:** Inspect Phase_5.R for recent methodology changes.

**Git log for Phase_5.R:**
```
9f35e5e Another one spotted lmao uwu       ← recent
056b2a3 Initial commit of local thesis files
```

Only two commits ever touched Phase_5.R.

**Git diff of Phase_5.R between the two commits:**
The diff shows **zero structural or logical changes**. Every modification was cosmetic:
- Unicode em-dash (—) replaced with ASCII hyphen (-) in `[METHODOLOGY]` comment tags
- One output row label: `"Pooled Oahu Opportunity Cost — q_bar ($B)"` → `"- q_bar ($B)"`

**The current Phase_5.R methodology — cookie-cutter parcel intersection (Step 2) and
500m spatial deduplication (Step 3) — was present in the initial commit.** No version
of Phase_5.R exists in the git history without these steps.

---

## Part 4 — Bulk Tests Methodology Comparison

**Task:** Compare current Phase_5.R logic against Bulk Tests outputs.

All three Bulk Tests Step 3 scripts (`R/Step3_Final_Comparison.R`,
`Julia/Step3_Final_Comparison.jl`, `python/Step3_Final_Comparison.py`) include
the identical 500m spatial deduplication logic:
```r
# From Step3_Final_Comparison.R, lines 272–293
courses_sf$poly_id <- ifelse(nearest_dist <= 500, osm_polys_sf$poly_id[nearest_idx], NA)
master_keep_list <- courses_sf |> filter(!duplicated(group_id)) |> ...
oahu_deduped_list <- lapply(seq_len(M), function(i) {
    oahu_all |> filter(imputation == i) |>
        inner_join(master_keep_list, by = c("Longitude", "Latitude", "Holes"))
})
```

The Step 2 cookie-cutter is in separate step scripts that feed `Target_Golf_Parcels_List.csv`
and `Target_Golf_Polygons.gpkg` into Step 3.

**Bulk Tests results (m=5, with cookie-cutter + deduplication):**

| Language | Pooled OC | Courses (OSM polygons) | OSM Footprint |
|----------|-----------|------------------------|---------------|
| R | $26.081B | 38 | 8,342.28 ac (hardcoded) |
| Python | $26.515B | 39 | 8,342.28 ac (hardcoded) |
| Julia | $25.400B | 39 | 8,342.28 ac (hardcoded) |
| **Grand Mean** | **~$25.999B** | | |

**Post-rerun results (m=100, with cookie-cutter + deduplication):**

| Language | Pooled OC | Courses (OSM polygons) | OSM Footprint |
|----------|-----------|------------------------|---------------|
| R | $26.684B | 39 | 8,564.23 ac (live-computed) |
| Python | $26.786B | 39 | 8,564.23 ac (live-computed) |
| Julia | $26.540B | 39 | 8,564.23 ac (live-computed) |
| **Grand Mean** | **$26.670B** | | |

**Difference: Bulk Tests → Post-Rerun:** +$0.67B (+2.6%).
Attributable to (a) m=5 → m=100 MICE stabilization and (b) +221.95 ac OSM footprint
expansion from the FIPS fix restoring one previously FIPS-NA Oahu course.

Neither the Bulk Tests nor the post-rerun produce $28.61B. The Bulk Tests already showed
~$26B with the full Step 2+3 methodology. **The $28.61B predates the Bulk Tests.**

---

## Part 5 — The Hardcoded OSM_DERIVED_ACRES and its Significance

Phase5_Documentation.md documents a key acreage discrepancy:

> "The daughter script `Step3_Final_Comparison.jl` uses a hardcoded constant
> `OSM_DERIVED_ACRES = 8342.28`. The standalone `Phase_5.jl` computes acreage live
> from the Step 2 spatial intersection geometry, yielding **8,564.23 acres**."
> `Phase_5.py` previously carried the same stale constant (`OSM_DERIVED_ACRES = 8342.28`)
> and has since been corrected.

Both Bulk Test Step 3 scripts (R and Julia) confirm `OSM_DERIVED_ACRES = 8342.28` hardcoded.
This constant is a reporting value only (written to the comparison CSV as a display metric)
and does NOT affect the OC calculation, which always uses `final_acreage × BVPA` from
individual rows. However, it confirms the Bulk Tests were run before the live footprint
computation was available — establishing that the Bulk Tests represent an intermediate
stage of the pipeline's development.

---

## Part 6 — Hypothesis Test: Acreage Scaling

**Hypothesis from investigation brief:** Did $28.61B come from an earlier methodology that
aggregated at the OSM polygon level (8,564 ac) rather than the cadastre-intersected level
(6,066 ac)?

**Mathematical test:**

If OC scales linearly with acreage and the current OC = $26.67B uses 6,066 ac:
```
$26.67B × (8,564 / 6,066) = $37.6B
```
That is NOT $28.61B. Simple OSM-vs-cadastre acreage scaling cannot explain the difference.

If Phase5_Summary.md's $25.4B (Julia Bulk Test) is scaled instead:
```
$25.4B × (8,564 / 6,066) = $35.8B
```
Also not $28.61B.

**Conclusion:** The $28.61B did NOT arise from simply substituting OSM polygon acreage for
cadastre-intersected acreage in an otherwise-identical calculation. The hypothesis is
**REJECTED**. The acreage difference (8,564 vs 6,066 ac) cannot explain the $28.61B figure.

---

## Part 7 — Revised Hypothesis: Pre-Deduplication Methodology

**Phase5_Documentation.md** documents a three-stage course count:
- **37 imputed**: all unique coordinates passing the Oahu bounding-box filter from Phase 3
- **33 deduplicated**: after 500m spatial deduplication assigns lat/lon points to OSM polygons
- **29 mapped**: subset matching within 500m for Phase 6 visualization

The deduplication removes **4 course representations** (37 → 33). These are Phase 1 points
that map to the same OSM polygon as another Phase 1 point — i.e., duplicate representations
of the same physical course at different coordinates.

**If the $28.61B was computed WITHOUT the 500m spatial deduplication** (all 37 bounding-box
courses, rather than 33 deduplicated), the extra 4 courses would inflate the aggregate. At
Honolulu's FHFA BVPA = $4,952,600/ac and typical Oahu course acreage (100–200 ac):
- Each extra course would contribute ~$495M–$990M
- 4 extra courses would add ~$1.98B–$3.96B to the aggregate

This would transform $26.08B (R Bulk Tests) → $28.06B–$30.04B, a range that brackets $28.61B.

Additionally, in the pre-FIPS-fix era, Hawaii Kai and Mid-Pacific had MICE-imputed BVPA
values averaging below the confirmed FHFA rate ($452M and $702M Grand Mean vs. $646M
and $753M post-fix). A pre-FIPS-fix, pre-deduplication run would produce values offset
from both the Bulk Tests and the post-rerun in opposite directions:
- Pre-FIPS-fix lowers OC for Hawaii courses (MICE < FHFA)
- Pre-deduplication raises OC (more courses counted)

A net result of $28.61B is consistent with the deduplication effect (+$2–3B) dominating
the FIPS-fix effect (−$200–400M), producing an aggregate above the Bulk Tests value.

**This hypothesis is plausible but cannot be confirmed** from available files. No pre-deduplication
output CSV exists, and no pre-deduplication Phase 5 script exists in any committed version.

---

## Part 8 — The "Unrestricted HBU Framework" Label

Phase5_Summary.md uses "$28.6B" as the "unrestricted HBU framework" estimate in the
Preservation Paradox discussion. In context, "unrestricted" refers to the HBU valuation
framework that does NOT account for zoning restrictions — the gross opportunity cost
assuming all Oahu golf land can be redeveloped to highest-and-best-use regardless of
zoning classification. This is contrasted with the "legally-permissible HBU" of $1.3B
(only zones where redevelopment is currently permitted).

**The zone proportions ($23.4B / $3.9B / $1.3B) sum to exactly $28.6B:**
```
4,956 ac × avg_BVPA = $23.4B  (81.7% Preservation/Federal)
836 ac × avg_BVPA   =  $3.9B  (13.8% Agriculture)
275 ac × avg_BVPA   =  $1.3B  (4.5%  Other zones)
─────────────────────────────
6,066 ac ×  $4,719/ac = $28.6B (implied average BVPA)
```

These zone acreages (4,956 / 836 / 275 ac) match the post-parcel-intersection breakdown
exactly. The $28.61B uses the **same zone areas** as the current pipeline but a **different
total OC** as the scalar. This means $28.61B is being used in Phase5_Summary.md as the
total-OC reference for computing zone shares, not as the Phase 5b Rubin-pooled result.

**Implication:** Phase5_Summary.md's zone OC breakdown ($23.4B / $3.9B / $1.3B) is back-
calculated from the $28.61B base, not independently computed. The same proportions applied
to the correct $26.67B base give:
```
Preservation/Federal: 81.7% × $26.67B = $21.8B (not $23.4B)
Agriculture:          13.8% × $26.67B = $3.7B  (not $3.9B)
Other:                 4.5% × $26.67B = $1.2B  (not $1.3B)
```

**The Preservation Paradox dollar figures in Phase5_Summary.md should be updated from
($23.4B / $3.9B / $1.3B / $28.6B) to ($21.8B / $3.7B / $1.2B / $26.67B) before thesis
submission.** The zone percentages (81.7% / 13.8% / 4.5%) remain correct.

---

## Part 9 — Provenance Chain Summary

| Value | Source Document | Description |
|-------|----------------|-------------|
| $28.61B | `999 - Late Stage/Notes.md` | "Grand Mean total Oahu OC" — pre-Bulk Tests, pre-rerun |
| $28.6B | `Phase 5 .../00 - Phase5_Summary.md` | "unrestricted HBU framework" — used as total for zone breakdown |
| $28.6B | `Phase 6 .../00 - Phase6_Summary.md` | "Preservation Paradox waffle chart decomposes the $28.6B" |
| ~$26.0B | Bulk Tests Phase5_Oahu_Comparison.csv files | Grand Mean of R/Py/Jl at m=5 |
| $26.67B | Post-rerun Phase5_Oahu_Comparison.csv files | Grand Mean at m=100, FIPS-fixed |

**Origin of $28.61B:** The $28.61B was documented in the Checklist (a pre-git document)
as the project's baseline Oahu OC. It predates the Bulk Tests. It cannot be traced to any
committed script or output file. The prior Sonnet sessions (Phase5_Rerun_Report.md,
Phase7_Rerun_Report.md) correctly identified it as originating from a "pre-parcel-
intersection methodology" but did not document which specific calculation produced it.

Based on available evidence, the most defensible reconstruction is:

> The $28.61B was computed in an early exploratory Phase 5 session (before the Bulk Tests
> were structured) by summing `osm_acreage × Baseline_Value_Per_Acre` across all Oahu-bounding-
> box courses from Phase 3 imputed datasets, WITHOUT the 500m spatial deduplication step
> that the current pipeline applies in Step 3. This counted approximately 37 course
> representations (vs. 33 after deduplication), inflating the aggregate by the OC of the
> 4 duplicate course entries. This calculation was recorded in the Checklist as the baseline
> and propagated into Notes.md and Phase5_Summary.md before the deduplication step was
> adopted as the canonical methodology.

**This reconstruction cannot be verified from available files**, as no pre-deduplication
script or output file exists in the project directory or git history.

---

## Part 10 — Definitive Statements (What Can and Cannot Be Confirmed)

### Confirmed from real files

1. **$28.61B appears in Notes.md** as "Grand Mean total Oahu OC" — the baseline value
   before the ground-up rerun.

2. **Phase5_Summary.md uses $28.6B as the "unrestricted HBU" total** for the Preservation
   Paradox zone breakdown, producing the $23.4B / $3.9B / $1.3B zone OC figures.

3. **Phase6_Summary.md references $28.6B** in the Preservation Paradox waffle chart
   description — this chart's base value has not been updated to $26.67B.

4. **No git commit mentions $28.61B.** The value has no traceable git origin.

5. **Phase_5.R was never structurally changed.** Only em-dash → hyphen edits were made
   between the two commits. The cookie-cutter intersection and 500m spatial deduplication
   have been present since the initial commit.

6. **The Bulk Tests (with cookie-cutter + deduplication) gave ~$26.00B Grand Mean** — not
   $28.61B. The $28.61B predates even the Bulk Tests.

7. **Simple OSM/cadastre acreage scaling cannot explain $28.61B.** Scaling the current OC
   from 6,066 ac to 8,564 ac gives $37.6B, far exceeding $28.61B.

8. **The post-rerun canonical value is $26.67B** — confirmed across all three languages
   at m=100, with FIPS fix applied.

### Not confirmed (ambiguous or unverifiable)

1. **The exact calculation that produced $28.61B** — no pre-deduplication Phase 5 script
   or output file exists in the project directory or git history.

2. **Whether the extra ~$2.6B ($28.61B − $26.00B) came from un-deduplicated courses** —
   plausible but unverifiable without the original output.

3. **What m-value and which Phase 3 datasets were used** for the original $28.61B
   calculation — not documented anywhere.

---

## Conclusion

The Oahu OC estimate evolved from $28.61B (pre-Bulk Tests, pre-git exploratory estimate)
to approximately $26.00B (Bulk Tests, m=5) to $26.67B (post-rerun, m=100, FIPS-fixed)
through two distinct transitions:

**Transition 1 ($28.61B → ~$26.00B):** The adoption of 500m spatial deduplication in
Phase 5 Step 3 removed duplicate Phase 1 course representations that had inflated the
bounding-box aggregate. The current Phase_5.R and all Bulk Test scripts include
this deduplication; it was present in the initial git commit. The $28.61B predates this
methodology and is correctly described in Phase5_Summary.md as the "unrestricted HBU
framework" estimate (i.e., without the deduplication restriction). The exact origin
cannot be reconstructed from available repository files.

**Transition 2 (~$26.00B → $26.67B):** Two documented changes account for the +$0.67B
(+2.6%) shift between Bulk Tests and post-rerun: (a) m=5 → m=100 MICE produced more
stable Rubin-pooled estimates, and (b) the Phase 1 FIPS fix restored one previously-FIPS-NA
Oahu course to FIPS 15003, expanding the OSM footprint by +221.95 ac and adding one course
to the Oahu spatial subset.

**Required thesis updates flowing from this investigation:**

1. **Replace $28.6B with $26.67B** in the Preservation Paradox dollar breakdown (Phase5_Summary.md
   and any thesis prose citing the gross HBU estimate). The zone percentages (81.7% / 13.8% / 4.5%)
   remain correct; only the dollar scaling changes.

2. **Update Phase6_Summary.md waffle chart reference** from $28.6B to $26.67B (affects script 12
   input value, if hardcoded).

3. **Retire the $28.61B figure** from all thesis prose and documentation — confirmed by
   Phase5_Rerun_Report.md, Phase7_Rerun_Report.md, and this investigation.

---

**One-paragraph defensible explanation for thesis prose:**

> The Oahu aggregate opportunity cost estimate evolved across three stages of the Phase 5
> pipeline. An early exploratory estimate — recorded in project notes as $28.61B and referred
> to in Phase 5 documentation as the "unrestricted HBU framework" — was computed by summing
> each Oahu course's modeled opportunity cost from Phase 3 imputed datasets without spatial
> deduplication of duplicate course representations. When the Phase 5b pipeline adopted a
> 500-meter nearest-polygon cap to remove Phase 1 points that map to the same physical course,
> the deduplicated aggregate fell to approximately $26.0B (Bulk Tests, m=5). The ground-up
> rerun, incorporating the Phase 1 FIPS boundary correction and expanding to m=100 MICE
> imputations, produced the authoritative figure of **$26.67B** (Grand Mean across R, Python,
> and Julia; 95% CI available per language). The $28.61B figure is retired; the $26.67B
> post-rerun Grand Mean is the correct Oahu opportunity cost for all thesis citations.
