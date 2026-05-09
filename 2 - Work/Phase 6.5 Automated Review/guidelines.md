# Project-Wide Coding & Documentation Standards

## 1. Global Naming Conventions

### 1.1 Variables & DataFrames
- Strictly use `snake_case` for all variable and function names (e.g., `golf_course_data`).
- Suffix dataframes with `_df` (e.g., `zoning_df`).
- Suffix spatial objects with `_sf` in R and Julia, and `_geo` in Python (e.g., `hawaii_tracts_sf`, `hawaii_tracts_geo`).
- Functions must start with an action verb to distinguish them from variables (e.g., `calc_opportunity_cost()`, `clean_tmk_data()`).
- Use `ALL_CAPS` for constants — static values, threshold parameters, seeds, and CRS codes defined at the top of scripts (e.g., `TARGET_CRS <- "EPSG:5070"`, `MAX_ITERATIONS <- 50`).

### 1.2 Cross-Language & Cross-Phase Consistency
The same real-world concept must use the same base name everywhere it appears — across R, Python, and Julia versions of the same script, across bulk test scripts and master scripts, and across all phases of the project. The language-specific suffix (`_sf` vs `_geo`) is the only permitted variation for the same concept across languages.

Examples of correct cross-language naming:
| Concept | R | Python | Julia |
|---|---|---|---|
| All parsed golf course points | `courses_sf` | `courses_geo` | `courses_sf` |
| Baseline valuation dataframe | `baseline_df` | `baseline_df` | `baseline_df` |
| County economic data | `county_econ_df` | `county_econ_df` | `county_econ_df` |

Variable names established in Phase 1 become the **canonical names** for those concepts in all later phases. If a later phase uses a different name for the same concept, the later phase must be updated to match Phase 1, not the reverse.

### 1.3 Naming Filtered or Enriched Objects
- If a variable is a filtered geographic or demographic subset of a parent object, the name must make the distinction explicit and human-readable (e.g., `hawaii_courses_sf` vs `all_courses_sf`, never `df2` vs `df3`).
- Overwriting a variable with an enriched version of itself after a join or merge is acceptable and preferred over creating throwaway intermediate names (e.g., `courses_sf` after adding county attributes is still `courses_sf`).
- If a variable serves a genuinely different purpose from any existing name, choose a new name that a human reader would find intuitive given the analytical context.


## 2. Commenting & Documentation

### 2.1 Script Headers
Every script must begin with a block comment containing:
- **Purpose:** A one-sentence summary of what the script accomplishes analytically.
- **Inputs:** The specific data files or objects the script reads.
- **Outputs:** The specific data files, objects, or plots the script generates.

### 2.2 Function Docstrings
Every custom function must have a formal docstring immediately above or inside it:
- R: use Roxygen2-style `#'` comments specifying `@param` and `@return`.
- Python: use `"""triple-quoted docstrings"""` specifying parameters and return type.
- Julia: use `"""triple-quoted docstrings"""` above the function definition.

### 2.3 Inline Comments — Why, Not What
Inline comments must explain *why* a specific mathematical, spatial, or analytical decision was made — not *what* the code is doing. Examples:

- **Wrong:** `# filter to golf courses` 
- **Right:** `# restrict to golf_course leisure tag per OSM schema — excludes driving ranges and mini-golf`

If the reason for a step cannot be determined from context, use: `# [REVIEW NEEDED] — reason for this step unclear`

### 2.4 Methodology Flags
Any critical analytical step must be flagged with a `# [METHODOLOGY]` comment on the same line or the line immediately above. Flag every instance of:
- Spatial joins: `st_join()` in R/Julia, `sjoin()` in Python, and all equivalents.
- CRS transformations: `st_transform()` in R/Julia, `.to_crs()` in Python, and all equivalents.
- MICE imputation: any call to `mice()` or equivalent multiple imputation function.
- Rubin's Rules pooling: any block that pools across imputation datasets.
- Random forest or other stochastic model fitting.
- Any custom distance threshold or spatial tolerance parameter.


## 3. Structural Layout

Every script must follow this four-section structure, separated by a commented header line. Use **two blank lines** between major sections and **one blank line** between logical chunks within a section.

```
# === 1. LIBRARIES ===

# === 2. GLOBALS & PATHS ===

# === 3. FUNCTIONS ===

# === 4. EXECUTION ===
```

**Section omission rule:** All four section headers must always be present as labelled comments, preserving the numbered sequence. If a section has no content for a particular script, keep the header and place a single line `# (none)` beneath it. Do not renumber remaining sections.

Example of a script with no custom functions:
```
# === 3. FUNCTIONS ===

# (none)


# === 4. EXECUTION ===
```

### Section 1: LIBRARIES
All `library()` calls (R), `import` statements (Python), or `using` statements (Julia) must appear here and only here. No mid-script imports under any circumstances.

**R — Phase 1 and Phase 2:** Include `tidyverse` and `wooldridge` in every R script that performs data manipulation or econometric work, even if not all functionality is actively used in the current version. This supports forward compatibility as scripts are extended. Do not add them to purely spatial scripts with no tabular manipulation.

**R — Phase 3, Phase 4, and Phase 5:** Before adding `wooldridge` to any script in these phases, pause and report to the user. State specifically: which script you are about to edit, which function or dataset from `wooldridge` you believe could be used there and why, and what change you would make. Wait for the user's confirmation before adding `wooldridge` to that script. This rule applies per-script — each addition requires its own pause and confirmation. `tidyverse` may still be added to Phase 3–5 scripts without pausing.

### Section 2: GLOBALS & PATHS
Define all file paths and constants immediately after imports. Rules:
- All file paths must be **relative**, derived from the script's own location:
  - R: use `this.path::this.dir()` or `here::here()`.
  - Python: use `pathlib.Path(__file__).parent`.
  - Julia: use `@__DIR__`.
- No hardcoded absolute paths anywhere in any script.
- All threshold values, seeds, CRS codes, and other parameters belong here as named `ALL_CAPS` constants — never inline magic numbers in the execution section.

### Section 3: FUNCTIONS
Define all custom logic here before the main execution block. No anonymous logic that could reasonably be a named function should appear in the execution section. If no custom functions exist in a script, write `# (none)` under this header.

### Section 4: EXECUTION
The main script logic: load data, call functions, save outputs. Keep this section as a clean narrative of steps — detailed logic lives in Section 3.


## 4. Modern Syntax & Reproducibility

- **R:** Prefer the native pipe `|>` and Tidyverse/dplyr idioms. Avoid base R apply loops where a `dplyr` verb is cleaner.
- **Python:** Prefer modern Pandas method chaining. Use `pathlib` for all path operations, never `os.path` string concatenation.
- **Julia:** Prefer `DataFrames.jl` and `Chain.jl` idioms where applicable.
- **Reproducibility:** Explicitly set random seeds for any stochastic process (imputation, random forest, sampling). Ensure all parallel processing blocks are safely opened and closed — no dangling workers.
- **No silent failures:** Any file read or write must be preceded by an existence check or wrapped in error handling that produces a human-readable message.


## 5. Output File Naming Conventions

Output data files written by scripts follow this scheme:
```
[LanguagePrefix]_Phase[N]_[Descriptor]_[OptionalStage].csv
```
Examples:
- `R_Phase1_Baseline_Golf_Valuation.csv`
- `Py_Phase2_OSM_Golf_Polygons.gpkg`
- `Jl_Phase1_Spatial_Joined_Golf_Courses.csv`

The language prefix (`R_`, `Py_`, `Jl_`) identifies which pipeline produced the file. The phase number and descriptor must be consistent with the analytical step that produced the file. Do not use ad-hoc suffixes like `_NEW`, `_v2`, or `_FINAL` — use the standardized naming scheme and let the pipeline step number convey version context.


## 6. Summary Documents

Each phase directory must contain a summary markdown file named:
```
00 - Phase_[N]_Summary.md
```
Located in the phase root directory (e.g., `Phase 1 Parsing/00 - Phase_1_Summary.md`), not in subdirectories.

This file must be structured by language (R, Python, Julia) and must document:
- What the phase accomplishes analytically (one paragraph).
- For each script: what it does, what it reads, what it writes.
- A cross-language naming table (see Section 1.2).
- Any outstanding issues or steps requiring manual review.

This summary is the authoritative reference for any reader or reviewer of the codebase — write it as if a colleague unfamiliar with the project will need to understand the phase from this document alone.