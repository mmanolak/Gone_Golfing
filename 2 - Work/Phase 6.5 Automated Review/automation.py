"""
automation.py
Purpose:  Orchestrate automated academic review of thesis materials using local
          LLMs served via llama-server (OpenAI-compatible API). Routes tasks to
          the appropriate model based on task type, then appends findings to
          list.md for manual review.
Inputs:   Files in REVIEW_DIRS matching REVIEW_EXTENSIONS. Instruction files in
          the same directory as this script.
Outputs:  Appends timestamped review sections to list.md.

USAGE:
  1. Start your llama-server with the desired model on port 8080.
  2. Set ACTIVE_MODEL below to match the alias you gave llama-server.
  3. Run:  python automation.py

MODELS RECOGNISED:
  "GPT-OSS-120B-Heretic"          -> loads instructions_gpt_oss.md
  "Qwen3-80B-Thinking-Uncensored" -> loads instructions_qwen3.md
  Any other alias                 -> falls back to a generic system prompt.
"""

# === 1. LIBRARIES ===

import os
import sys
import json
import requests
from datetime import datetime
from pathlib import Path


# === 2. GLOBALS & PATHS ===

# --- Server ---
SERVER_URL   = "http://localhost:8080/v1/chat/completions"
ACTIVE_MODEL = "GPT-OSS-120B-Heretic"   # Change to match your llama-server --alias

# --- Paths (all relative to this script's location) ---
SCRIPT_DIR   = Path(__file__).parent
OUTPUT_FILE  = SCRIPT_DIR / "list.md"

# Directories to scan for review targets (relative to home on the server)
# Edit these to match your gone_golfing folder structure.
HOME         = Path.home()
THESIS_ROOT  = HOME / "gone_golfing"

REVIEW_DIRS  = [
    THESIS_ROOT / "Phase 1 Parsing",
    THESIS_ROOT / "Phase 2 Spatial Polygons and True Acreage",
    THESIS_ROOT / "Phase 3 Economic Merge and MICE Imputation",
    THESIS_ROOT / "Phase 4 Econometric Modeling",
    THESIS_ROOT / "Phase 5 The Hawaii Micro-Case Study",
    THESIS_ROOT / "Phase 6 Visualization",
    THESIS_ROOT / "Phase 7 Documentation, Discussion and Write Up",
]

# File types the script will read and send for review
REVIEW_EXTENSIONS = {".md", ".tex", ".txt", ".R", ".py", ".jl"}

# Files to always skip regardless of extension
SKIP_FILES = {
    "list.md",          # the output file itself
    "temp.txt",         # scratch notes not intended for review
    "automation.py",    # this script
}

# --- Generation parameters ---
TEMPERATURE = 0.1    # low temperature for analytical consistency
MAX_TOKENS  = 4096   # per-file response ceiling

# --- Shared context files (loaded once, prepended to every prompt) ---
PURPOSE_FILE   = SCRIPT_DIR / "purpose.md"
GUIDELINES_FILE = SCRIPT_DIR / "guidelines.md"

# --- Model-specific instruction files ---
MODEL_INSTRUCTIONS = {
    "GPT-OSS-120B-Heretic":          SCRIPT_DIR / "instructions_gpt_oss.md",
    "Qwen3-80B-Thinking-Uncensored": SCRIPT_DIR / "instructions_qwen3.md",
}


# === 3. FUNCTIONS ===

def load_text(path: Path, label: str) -> str:
    """
    Read a text file and return its contents as a string.

    Parameters
    ----------
    path  : Path to the file to read.
    label : Human-readable label used in error messages.

    Returns
    -------
    str : File contents, or an empty string if the file is missing.
    """
    if not path.exists():
        print(f"  [WARN] {label} not found at {path} — skipping.")
        return ""
    return path.read_text(encoding="utf-8")


def build_system_prompt(model_alias: str) -> str:
    """
    Assemble the system prompt for the active model by concatenating:
      purpose.md + guidelines.md + model-specific instructions file.

    Parameters
    ----------
    model_alias : The --alias string used when launching llama-server.

    Returns
    -------
    str : The complete system prompt to send with every request.
    """
    purpose    = load_text(PURPOSE_FILE,    "purpose.md")
    guidelines = load_text(GUIDELINES_FILE, "guidelines.md")

    instr_path = MODEL_INSTRUCTIONS.get(model_alias)
    if instr_path is None:
        print(f"  [WARN] No instruction file mapped for model '{model_alias}'."
              "  Using generic fallback prompt.")
        instructions = (
            "You are a meticulous thesis reviewer. Identify logical inconsistencies, "
            "methodological errors, formatting problems, and unclear reasoning. "
            "Output only your critique in clean Markdown. Do not rewrite the text."
        )
    else:
        instructions = load_text(instr_path, f"instructions for {model_alias}")

    return "\n\n---\n\n".join(filter(None, [purpose, guidelines, instructions]))


def collect_files(review_dirs: list[Path]) -> list[Path]:
    """
    Recursively collect all reviewable files from the target directories.
    Skips data files, output files, and any path containing 'Bulk Tests'.

    Parameters
    ----------
    review_dirs : List of root directories to scan.

    Returns
    -------
    list[Path] : Sorted list of file paths to review.
    """
    found = []
    for root_dir in review_dirs:
        if not root_dir.exists():
            print(f"  [WARN] Review directory not found: {root_dir}")
            continue
        for fpath in root_dir.rglob("*"):
            if not fpath.is_file():
                continue
            if fpath.suffix.lower() not in REVIEW_EXTENSIONS:
                continue
            if fpath.name in SKIP_FILES:
                continue
            # Skip bulk test output CSVs and data files sitting in script dirs
            if any(part in ("Bulk Tests", "Data") for part in fpath.parts):
                continue
            found.append(fpath)
    return sorted(found)


def review_file(system_prompt: str, file_path: Path) -> str:
    """
    Send one file's content to the local LLM and return the critique.

    Parameters
    ----------
    system_prompt : The assembled system prompt for the active model.
    file_path     : Path to the file being reviewed.

    Returns
    -------
    str : The model's critique in Markdown, or an error message.
    """
    content = file_path.read_text(encoding="utf-8", errors="replace")

    # Truncate very large files to avoid overwhelming the context window.
    # 12,000 characters is roughly 3,000 tokens — safe for 128k context models
    # when combined with the system prompt.
    MAX_CHARS = 12_000
    truncated = False
    if len(content) > MAX_CHARS:
        content   = content[:MAX_CHARS]
        truncated = True

    user_message = (
        f"Please review the following file: `{file_path.name}`\n"
        f"Full path for reference: `{file_path}`\n"
    )
    if truncated:
        user_message += (
            f"[NOTE: File was truncated to {MAX_CHARS} characters to fit context.]\n"
        )
    user_message += f"\n```\n{content}\n```"

    payload = {
        "model":       ACTIVE_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user",   "content": user_message},
        ],
        "temperature": TEMPERATURE,
        "max_tokens":  MAX_TOKENS,
    }

    try:
        response = requests.post(SERVER_URL, json=payload, timeout=300)
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]
    except requests.exceptions.ConnectionError:
        return (
            "**ERROR:** Could not connect to llama-server. "
            "Ensure it is running on port 8080."
        )
    except Exception as exc:
        return f"**ERROR reviewing file:** {exc}"


def append_to_report(output_path: Path, file_path: Path, critique: str,
                     model_alias: str) -> None:
    """
    Append one file's review section to the output markdown report.

    Parameters
    ----------
    output_path  : Path to list.md.
    file_path    : Path of the file that was reviewed.
    critique     : The model's critique text.
    model_alias  : Name of the model that produced this critique.
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    section = (
        f"\n\n---\n\n"
        f"## {file_path.name}\n"
        f"**Reviewed by:** {model_alias}  \n"
        f"**Timestamp:** {timestamp}  \n"
        f"**Full path:** `{file_path}`\n\n"
        f"{critique}\n"
    )
    with output_path.open("a", encoding="utf-8") as f:
        f.write(section)


def init_report(output_path: Path, model_alias: str) -> None:
    """
    Write the session header to list.md if it does not already exist,
    or append a new session divider if it does.

    Parameters
    ----------
    output_path  : Path to list.md.
    model_alias  : Name of the model running this session.
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    header = (
        f"# Automated Review Log\n\n"
        f"<!-- Each session appends below. Do not edit above this line. -->\n"
    )
    session_divider = (
        f"\n\n===\n\n"
        f"# Review Session — {timestamp}\n"
        f"**Model:** {model_alias}\n"
    )

    if not output_path.exists():
        output_path.write_text(header + session_divider, encoding="utf-8")
    else:
        with output_path.open("a", encoding="utf-8") as f:
            f.write(session_divider)


# === 4. EXECUTION ===

def main() -> None:
    print(f"\n{'='*60}")
    print(f"  Automated Thesis Review")
    print(f"  Model   : {ACTIVE_MODEL}")
    print(f"  Output  : {OUTPUT_FILE}")
    print(f"{'='*60}\n")

    # Verify server is reachable before doing any file work
    try:
        requests.get(SERVER_URL.replace("/chat/completions", "/models"), timeout=5)
    except requests.exceptions.ConnectionError:
        print("[FATAL] Cannot reach llama-server at", SERVER_URL)
        print("        Start your model first, then re-run this script.")
        sys.exit(1)

    system_prompt = build_system_prompt(ACTIVE_MODEL)
    if not system_prompt.strip():
        print("[FATAL] System prompt is empty — check that purpose.md and")
        print("        at least one instructions file exist in", SCRIPT_DIR)
        sys.exit(1)

    files = collect_files(REVIEW_DIRS)
    if not files:
        print("[WARN] No reviewable files found in the specified directories.")
        sys.exit(0)

    print(f"  Found {len(files)} file(s) to review.\n")
    init_report(OUTPUT_FILE, ACTIVE_MODEL)

    for i, file_path in enumerate(files, start=1):
        rel = file_path.relative_to(THESIS_ROOT) if THESIS_ROOT in file_path.parents else file_path
        print(f"  [{i:>3}/{len(files)}] {rel}")

        critique = review_file(system_prompt, file_path)
        append_to_report(OUTPUT_FILE, file_path, critique, ACTIVE_MODEL)

    print(f"\n  Done. Results appended to: {OUTPUT_FILE}\n")


if __name__ == "__main__":
    main()