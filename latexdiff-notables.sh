#!/bin/bash
# latexdiff-notables.sh
# Generate latexdiff while avoiding table compilation errors
# Usage: ./latexdiff-notables.sh old.tex new.tex [output_prefix]

set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 old.tex new.tex [output_prefix]"
  echo ""
  echo "Generates latexdiff output while avoiding table-related compilation errors."
  echo "Creates three output files:"
  echo "  - {prefix}_notables.pdf: Text changes only (no tables)"
  echo "  - {prefix}_notables.tex: LaTeX source for text-only diff"
  echo "  - {prefix}_final.pdf: Text changes + tables from new.tex"
  echo "  - {prefix}_final.tex: LaTeX source with tables"
  echo ""
  echo "Default output_prefix: 'diff'"
  exit 1
fi

OLD_FILE="$1"
NEW_FILE="$2"
OUTPUT_PREFIX="${3:-diff}"

# Verify input files exist
if [ ! -f "$OLD_FILE" ]; then
  echo "Error: Old file '$OLD_FILE' not found"
  exit 1
fi

if [ ! -f "$NEW_FILE" ]; then
  echo "Error: New file '$NEW_FILE' not found"
  exit 1
fi

echo "Processing: $OLD_FILE -> $NEW_FILE"
echo "Output prefix: $OUTPUT_PREFIX"
echo ""

# Create Perl script to remove tables
cat > /tmp/remove_tables_$$.pl << 'PERL_EOF'
#!/usr/bin/perl
use strict;
use warnings;

my $content = do { local $/; <> };

# Remove all table environments (tabular, tabular*, table)
$content =~ s/\\begin\{table\*?\}.*?\\end\{table\*?\}//gs;
$content =~ s/\\begin\{tabular\*?\}.*?\\end\{tabular\*?\}//gs;

print $content;
PERL_EOF

# Create Perl script to merge tables back
cat > /tmp/merge_tables_$$.pl << 'PERL_EOF'
#!/usr/bin/perl
use strict;
use warnings;

my $new_file = shift @ARGV;
die "Usage: $0 new_file < diff.tex\n" unless $new_file;

my $diff_content = do { local $/; <> };

open my $fh, '<', $new_file or die "Cannot open $new_file: $!";
my $new_content = do { local $/; <$fh> };
close $fh;

# Extract all tables from new file
my @tables;
while ($new_content =~ /\\begin\{table\*?\}.*?\\end\{table\*?\}/gs) {
  push @tables, $&;
}

# Insert tables before \end{document}
if (@tables) {
  $diff_content =~ s/(\\end\{document\})/$tables[0]\n\n$1/s;
}

print $diff_content;
PERL_EOF

# Step 1: Create versions without tables
echo "Step 1: Removing tables from input files..."
perl /tmp/remove_tables_$$.pl < "$OLD_FILE" > /tmp/old_notables_$$.tex
perl /tmp/remove_tables_$$.pl < "$NEW_FILE" > /tmp/new_notables_$$.tex

# Step 2: Generate latexdiff on table-free versions
echo "Step 2: Running latexdiff on text-only versions..."
latexdiff --type=CFONT /tmp/old_notables_$$.tex /tmp/new_notables_$$.tex > "${OUTPUT_PREFIX}_notables.tex"

# Step 3: Compile text-only diff
echo "Step 3: Compiling text-only diff..."
pdflatex -interaction=nonstopmode "${OUTPUT_PREFIX}_notables.tex" > /tmp/pdflatex_$$.log 2>&1
if [ $? -eq 0 ]; then
  echo "  ✓ ${OUTPUT_PREFIX}_notables.pdf created"
else
  echo "  ✗ Compilation failed (see ${OUTPUT_PREFIX}_notables.log)"
fi

# Step 4: Merge tables back into diff
echo "Step 4: Merging tables back into diff..."
perl /tmp/merge_tables_$$.pl "$NEW_FILE" < "${OUTPUT_PREFIX}_notables.tex" > "${OUTPUT_PREFIX}_final.tex"

# Step 5: Compile final diff with tables
echo "Step 5: Compiling final diff with tables..."
pdflatex -interaction=nonstopmode "${OUTPUT_PREFIX}_final.tex" > /tmp/pdflatex_final_$$.log 2>&1
if [ $? -eq 0 ]; then
  echo "  ✓ ${OUTPUT_PREFIX}_final.pdf created"
else
  echo "  ✗ Compilation failed (see ${OUTPUT_PREFIX}_final.log)"
fi

# Cleanup
rm -f /tmp/remove_tables_$$.pl /tmp/merge_tables_$$.pl /tmp/old_notables_$$.tex /tmp/new_notables_$$.tex /tmp/pdflatex_$$.log /tmp/pdflatex_final_$$.log

echo ""
echo "Done! Generated files:"
echo "  - ${OUTPUT_PREFIX}_notables.tex (LaTeX source, text only)"
echo "  - ${OUTPUT_PREFIX}_notables.pdf (PDF, text only)"
echo "  - ${OUTPUT_PREFIX}_final.tex (LaTeX source, with tables)"
echo "  - ${OUTPUT_PREFIX}_final.pdf (PDF, with tables)"
