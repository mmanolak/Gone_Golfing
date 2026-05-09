# Multi-Phase Standardization Instructions
# Covers: Phase 2, Phase 3, Phase 4, Phase 5, Phase 6
# For use with Claude Code in VS Code
# Read guidelines.md first — these instructions extend and clarify it.
#
# PREREQUISITE: Phase 1 has already been standardized. Variable names established
# in Phase 1 are canonical. Before touching any script in the target phase, read
# that phase's predecessor summary document to carry forward locked names.


## ROLE & CONSTRAINTS

You are a strict code linter and standardizer for an economics thesis codebase.
Your job is formatting and naming consistency only.
You must not alter any mathematical logic, spatial operations, data structures,
or existing analytical results.
Proceed fully through all scripts without checking in. Do not ask for confirmation
at any step. If you encounter a decision where both options are purely
formatting/naming with no logic impact, choose the more readable option and note
your choice in the summary document. If a change would affect logic, skip it and
flag it in the summary document under Outstanding Issues instead.


## HOW TO DETERMINE YOUR TARGET PHASE

Read the value of CURRENT_PHASE at the top of this file, or if not set, infer it
from which phase directory you have been pointed at in the user's opening message.
All path templates below use [N] as a placeholder — substitute the actual phase
number throughout.

CURRENT_PHASE = (set by user in opening message)


## PHASE DIRECTORY MAP

Phase 2: 2 - Work/Phase 2 Spatial Polygons and True Acreage/
Phase 3: 2 - Work/Phase 3 Economic Merge and MICE Imputation/
Phase 4: 2 - Work/Phase 4 Econometric Modeling/
Phase 5: 2 - Work/Phase 5 The Hawaii Micro-Case Study/


## STEP 0 — LOAD CANONICAL NAMES FROM PRIOR PHASE

Before reading any script in the target phase, read the summary document from
the immediately preceding phase:

  2 - Work/Phase [N-1] .../00 - Phase_[N-1]_Summary.md

Extract the Cross-Language Naming Decisions table from that document.
Those names are locked — the target phase must conform to them, not the reverse.
If the prior summary document does not exist, note this under Outstanding Issues
and proceed — do not stop.

For Phase 2, also read:
  2 - Work/Phase 1 Parsing/00 - Phase_1_Summary.md

Do not open any other files from prior phases.


## STEP 1 — UNDERSTAND CONTEXT FROM EXTRA JUNK

Check 2 - Work/extra junk/ for data summary markdown files.
Pattern: NN - Data_Summary_YYYYMMDD_HHMMSS.md
If multiple files share the same NN - prefix, the most recent timestamp is authoritative.

DO NOT open the MD file directly.
Instead, find and read the paired Python generator script (a .py file in extra junk
whose name or header comment references generating a summary or file tree).
Use only what the script reveals to infer data structure context.
Open the MD file only if the generator script alone cannot answer a specific structural
question — and if so, read the minimum lines needed.

DO NOT open any file with these extensions under any circumstances:
  .csv  .shp  .rds  .gpkg  .geojson  .dbf  .prj  .shx  .rda  .feather  .pbf


## STEP 2 — TARGET FILE LIST

Process every script in the target phase directory and its Bulk Tests/ subdirectory.
File lists by phase:

### Phase 2
  Phase 2 Spatial Polygons and True Acreage/
    Phase_2.R
    Phase_2.jl
    Phase_2.py
  Bulk Tests/R/
    01_Match_OSM.R
    02_Match_Tigris.R
    03_Finalize_Acreage.R
    parse_osm_golf_polygons.R
  Bulk Tests/python/
    (read directory — list all .py files present)
  Bulk Tests/Julia/
    (read directory — list all .jl files present)

### Phase 3
  Phase 3 Economic Merge and MICE Imputation/
    Phase_3.R
    Phase_3.jl
    Phase_3.py
  Bulk Tests/R/
    (read directory — list all .R files present)
  Bulk Tests/python/
    (read directory — list all .py files present)
  Bulk Tests/Julia/
    (read directory — list all .jl files present)

### Phase 4
  Phase 4 Econometric Modeling/
    Phase_4.R
    Phase_4.jl
    Phase_4.py
  Bulk Tests/R/
    (read directory — list all .R files present)
  Bulk Tests/python/
    (read directory — list all .py files present)
  Bulk Tests/Julia/
    (read directory — list all .jl files present)

### Phase 5
  Phase 5 The Hawaii Micro-Case Study/
    Phase_5.R
    Phase_5.jl
    Phase_5.py
  Bulk Tests/R/
    Step1_Data_Acquisition.R
    Step2_Parcel_Intersection.R
    Step3_Economic_Validation.R
    (read directory for any others)
  Bulk Tests/python/
    (read directory — list all .py files present)
  Bulk Tests/Julia/
    (read directory — list all .jl files present)
	
### Phase 6
  Phase 6 The Hawaii Micro-Case Study/
    Phase_6.R
    Phase_6.jl
    Phase_6.py
  Bulk Tests/R/
    1_Macro_Maps.R
    2_County_Map.R
    3_Oahu_TMK_Map.R
	4_Oahu_Zoning_Map.R
	5_Econometric_Plots.R
	6_Advanced_Econometric_Plots.R
	7_Bivariate_Econometric_Map.R
	8_LaTeX_Tables.R
	9_Oahu_Opportunity_Cost_Map.R
    (read directory for any others)
  Bulk Tests/python/
    (read directory — list all .py files present)
  Bulk Tests/Julia/
    (read directory — list all .jl files present)


## STEP 3 — PROCESSING ORDER

Process scripts in this order within each phase:
  1. Bulk R scripts in numeric/alphabetical order
  2. Bulk Python scripts in numeric/alphabetical order
  3. Bulk Julia scripts in numeric/alphabetical order
  4. Master scripts: Phase_[N].R, Phase_[N].py, Phase_[N].jl

For each script:
  1. Read it fully.
  2. Apply all standardization changes in a single edit pass.
  3. Do not stop to ask for confirmation.
  4. Do not execute any script.
  5. If you find logic that appears to be a bug or methodological inconsistency,
     do not fix it. Note it in your running list for the summary document.


## STEP 4 — STANDARDIZATION RULES

Apply every rule in guidelines.md plus all clarifications below.


### Naming consistency

The same real-world concept must use the same base name everywhere:
  - Across R, Python, and Julia versions of the same script
  - Across bulk test scripts and master scripts
  - Across all phases (Phase 1 names are canonical upstream anchors)

Language-specific suffix is the only permitted variation:
  - Spatial objects: _sf in R and Julia, _geo in Python

If a variable is a filtered or geographic subset of a parent object, name it explicitly:
  - Correct:   hawaii_courses_sf  vs  all_courses_sf
  - Incorrect: df2  vs  df3

Overwriting a variable with an enriched version of itself after a join or merge is
acceptable and preferred over throwaway intermediate names.

Canonical names by concept (add to these as you encounter new concepts per phase):

  All parsed golf course points (spatial):
    R/Julia:  courses_sf
    Python:   courses_geo

  All parsed golf course records (tabular):
    R/Python/Julia:  courses_df

  Baseline valuation output:
    R/Python/Julia:  baseline_df

  County economic data:
    R/Python/Julia:  county_econ_df

  OSM golf polygons:
    R/Julia:  osm_golf_sf
    Python:   osm_golf_geo

  Tigris landmark polygons:
    R/Julia:  tigris_golf_sf
    Python:   tigris_golf_geo

  Acreage-matched output:
    R/Python/Julia:  acreage_df

  MICE imputed dataset list (Phase 3):
    R/Python/Julia:  imputed_list

  Pooled post-Rubin output (Phase 3):
    R/Python/Julia:  pooled_df

  Regression model results object (Phase 4):
    R/Python/Julia:  model_results

  Parcel intersection spatial object (Phase 5):
    R/Julia:  parcel_intersection_sf
    Python:   parcel_intersection_geo

  TMK identifier list (Phase 5):
    R/Python/Julia:  tmk_df


### Four-section structure

Every script must use these exact section headers:
  # === 1. LIBRARIES ===
  # === 2. GLOBALS & PATHS ===
  # === 3. FUNCTIONS ===
  # === 4. EXECUTION ===

Two blank lines between sections.
One blank line between logical chunks within a section.


### Library rules

R: Remove redundant packages whose functionality is fully covered by tidyverse
   (dplyr, readr, stringr, tidyr, purrr, ggplot2, tibble, forcats).
   Keep packages not covered by tidyverse (sf, tigris, mice, wooldridge, etc.).
   Include tidyverse and wooldridge in Section 1 for any script doing data
   manipulation or econometric work.
   Do not add them to purely spatial scripts with no tabular manipulation.

Python: All imports at top in Section 1. No mid-script imports.

Julia: All using statements at top in Section 1. No mid-script using statements.


### Paths — relative only

R:      this.path::this.dir()
Python: pathlib.Path(__file__).parent
Julia:  @__DIR__

Replace every hardcoded absolute path (C:/Users/Michael/...) with relative construction.


### Methodology flags

Add # [METHODOLOGY] on the same line or immediately above any of:
  - Spatial joins:            st_join(), sjoin(), and all equivalents
  - CRS transformations:      st_transform(), .to_crs(), and all equivalents
  - Spatial read/write:       st_read(), st_write(), gpd.read_file(), and equivalents
  - Geometric operations:     st_area(), st_intersection(), st_union(), st_buffer(), equivalents
  - MICE imputation:          mice() or any equivalent multiple imputation call
  - Rubin's Rules pooling:    any block that pools across imputation datasets
  - Model fitting:            lm(), glm(), felm(), statsmodels equivalent
  - Stochastic processes:     random sampling, random forest, any set.seed() or equivalent
  - Distance thresholds:      any hardcoded spatial tolerance or buffer distance value

Include a brief why-explanation in the flag comment where the reason is not obvious.
Example: # [METHODOLOGY] st_transform to EPSG:5070 — equal-area CRS required for accurate
#          acreage calculation; WGS84 distorts area at Hawaii latitudes


### Inline comments — why not what

Convert all what-comments to why-comments.
Remove scratch notes, developer thinking-aloud comments, and structural labels
that are replaced by section headers.
If the reason cannot be determined from context:
  # [REVIEW NEEDED] — reason for this step unclear


### File existence checks

Every script must check that required input files exist before attempting to read them.
R:
  if (!file.exists(INPUT_PATH)) stop(paste("Input file not found:", INPUT_PATH))
Python:
  if not INPUT_PATH.exists():
      raise FileNotFoundError(f"Input file not found: {INPUT_PATH}")
Julia:
  isfile(INPUT_PATH) || error("Input file not found: $INPUT_PATH")


### Pipe operators

R: Convert all %>% to |> throughout.


## STEP 5 — WRITE THE SUMMARY DOCUMENT

After all scripts in the target phase are processed, create or overwrite:
  2 - Work/Phase [N] .../00 - Phase_[N]_Summary.md

Use exactly this structure:

---

# Phase [N] [Name] — Standardization Summary

## Purpose
One paragraph describing what this phase accomplishes analytically.
State clearly what it receives from the prior phase and what it hands to the next.

## Inherited Naming from Prior Phase
List which canonical variable names were carried forward unchanged from Phase [N-1].

## R Scripts

### [filename]
- Changes applied:
  - [bullet]
- Methodology flags added:
  - [line description and flag text]
- Issues flagged for manual review:
  - [bullet or "None"]

## Python Scripts
[same structure]

## Julia Scripts
[same structure]

## Cross-Language Naming Decisions

| Concept | R name | Python name | Julia name |
|---------|--------|-------------|------------|

## Outstanding Issues
Anything requiring manual review before scripts are run.
If none, write "None identified."

---


## ABSOLUTE CONSTRAINTS — NEVER VIOLATE THESE

1. Do not alter any formula, coefficient, spatial operation parameter, filter
   threshold, or model specification.

2. Do not open any data file (.csv, .shp, .rds, .gpkg, .geojson, .dbf, .pbf,
   or any other data format).

3. Do not execute any script or pipeline.

4. Do not create new files anywhere except:
     2 - Work/Phase [N] .../00 - Phase_[N]_Summary.md
   and, if a temporary scratch file is needed:
     2 - Work/extra junk/

5. Do not read, edit, or touch any file outside the target phase directory and
   its subdirectories, with these two exceptions:
     a. Reading the prior phase summary document per Step 0.
     b. Reading context generator scripts in extra junk/ per Step 1.

6. If a change would affect logic rather than only formatting or naming, skip it
   and flag it in the summary document. Do not make the change.
   

## CONTEXT MANAGEMENT

After completing each individual script edit, discard from your working memory
the full content of that script. Retain only:
  - The canonical variable names you established or confirmed from it
  - Any outstanding issues to add to the summary document
  - The next script's filename

Do not reproduce or re-read previously edited scripts unless explicitly asked.