# latexdiff-notables

A wrapper script for `latexdiff` that avoids table-related compilation errors by processing LaTeX documents without tables.

## Problem

Standard `latexdiff` inserts markup (like `\DIFaddFL{}` and `\DIFdelFL{}`) inside table cells, which breaks LaTeX table structure and causes "Misplaced \cr" compilation errors. This is especially problematic for complex tables with `\multicolumn`, `\midrule`, and other formatting commands.

## Solution

This script:
1. Removes all table environments from both input files
2. Runs `latexdiff` on the table-free versions
3. Compiles the text-only diff
4. Merges tables from the new file back into the diff
5. Compiles the final diff with tables

Result: Clean diffs that compile successfully, with text changes marked and tables preserved.

## Installation

```bash
# Make the script executable
chmod +x latexdiff-notables.sh

# Optional: Add to PATH for system-wide access
sudo cp latexdiff-notables.sh /usr/local/bin/
```

## Usage

### Basic Usage

```bash
./latexdiff-notables.sh old.tex new.tex
```

This generates four files with prefix `diff`:
- `diff_notables.tex` — LaTeX source (text changes only)
- `diff_notables.pdf` — PDF with text changes marked
- `diff_final.tex` — LaTeX source (text changes + tables)
- `diff_final.pdf` — PDF with text changes + tables

### Custom Output Prefix

```bash
./latexdiff-notables.sh old.tex new.tex my_changes
```

Generates:
- `my_changes_notables.tex`
- `my_changes_notables.pdf`
- `my_changes_final.tex`
- `my_changes_final.pdf`

### From Any Directory

```bash
/path/to/latexdiff-notables.sh /path/to/old.tex /path/to/new.tex output_prefix
```

## Output Files

### Text-Only Diff (`*_notables.*`)
- **Purpose**: Shows all text changes with latexdiff markup (deletions in red, additions in blue)
- **Tables**: Excluded (removed before diffing)
- **Use case**: Review text-only changes without table complexity

### Final Diff with Tables (`*_final.*`)
- **Purpose**: Complete document with text changes marked and tables from the new file
- **Tables**: Included from the new file (without change markup)
- **Use case**: Full document review with all content

## Requirements

- `latexdiff` — LaTeX diff tool (usually included with TeX Live)
- `pdflatex` — LaTeX compiler
- `perl` — Perl interpreter (for table extraction/merging)
- `bash` — Bash shell

## How It Works

### Step 1: Remove Tables
Uses Perl regex to remove all `\begin{table}...\end{table}` and `\begin{tabular}...\end{tabular}` environments from both input files.

### Step 2: Run latexdiff
Executes `latexdiff --type=CFONT` on the table-free versions. This avoids the table-related markup issues.

### Step 3: Compile Text-Only Diff
Runs `pdflatex` on the text-only diff to generate `*_notables.pdf`.

### Step 4: Merge Tables
Extracts all tables from the new file and inserts them before `\end{document}` in the diff.

### Step 5: Compile Final Diff
Runs `pdflatex` on the merged diff to generate `*_final.pdf`.

## Limitations

- **Tables are not marked**: Tables from the new file are included as-is without change markup. This is a trade-off to avoid compilation errors.
- **Only new file tables**: Tables are taken from the new file. If tables were deleted in the new file, they won't appear in the diff.
- **Complex table structures**: While this script avoids compilation errors, extremely complex table structures might still have issues.

## Troubleshooting

### "latexdiff: command not found"
Install TeX Live or ensure `latexdiff` is in your PATH.

### "pdflatex: command not found"
Install TeX Live or ensure `pdflatex` is in your PATH.

### Compilation fails with "Undefined control sequence"
Check that both input files are valid LaTeX documents and compile independently.

### Missing output files
Check the `.log` files for compilation errors:
```bash
cat diff_notables.log
cat diff_final.log
```

## Example Workflow

```bash
# Compare two versions of a research paper
./latexdiff-notables.sh paper_v1.tex paper_v2.tex paper_diff

# Review the text-only changes
open paper_diff_notables.pdf

# Review the complete document with tables
open paper_diff_final.pdf

# Share the LaTeX source with collaborators
cat paper_diff_final.tex
```

## Notes

- The script creates temporary files in `/tmp` and cleans them up automatically.
- Output files are created in the current working directory.
- The script uses `--type=CFONT` for latexdiff markup style (colored font). Modify the script to use a different style if needed.
- Compilation logs are preserved for debugging (`.log` files).

## License

This script is provided as-is for use with LaTeX documents.
