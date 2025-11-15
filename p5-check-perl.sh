#!/bin/sh
# Copyright Mat X 2025 - All Rights Reserved
# Check if files in a given folder were archived by Archiware P5
# Modified for Xcode app integration with progress reporting

# Path to nsdchat
chatcmd="/usr/local/aw/bin/nsdchat -c"

# Check if nsdchat exists
if [ ! -f "/usr/local/aw/bin/nsdchat" ]; then
    echo "ERROR:NSDCHAT_NOT_FOUND" >&2
    exit 2
fi

# Verify nsdchat is executable
if [ ! -x "/usr/local/aw/bin/nsdchat" ]; then
    echo "ERROR:NSDCHAT_NOT_EXECUTABLE" >&2
    exit 3
fi

# Get the current timestamp
now=$(date +"%Y-%m-%d_%H%M%S")

# Lightweight log file
logfile="/private/tmp/p5-check.log"

# Progress file for Swift to monitor
progressfile="/private/tmp/p5-progress-${now}.txt"

# start fresh
: > "$logfile"
: > "$progressfile"

# Function for logging with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$logfile"
}

# Function to report progress (for Swift UI to monitor)
report_progress() {
    local progress_val="$1"
    local message="$2"
    
    if [ -n "$progress_val" ]; then
        echo "progress: $progress_val" >> "$progressfile"
    fi
    
    if [ -n "$message" ]; then
        echo "message: $message" >> "$progressfile"
    fi
    
    # Also log it
    log "Progress: $progress_val% - $message"
}

log "=== Script started at $now ==="
report_progress 0 "Initializing..."

# Ask user for drag-drop folder if not provided
if [ -z "${1:-}" ]; then
    log "No folder argument provided; expecting an argument."
    echo "ERROR:NO_FOLDER_PROVIDED" >&2
    exit 1
else
    storage_path="$1"
    log "Using provided path: $storage_path"
fi

# Validate path
if [ ! -d "$storage_path" ]; then
    log "Error: Invalid folder path: $storage_path"
    echo "ERROR:INVALID_FOLDER_PATH:$storage_path" >&2
    exit 1
fi

report_progress 5 "Validating folder access..."

# Create/clear temp files up front
tmpdir="/private/tmp"
files_txt="$tmpdir/files-${now}.txt"
files2_txt="$tmpdir/files2-${now}.txt"
files_handle="$tmpdir/files-handle-${now}.txt"
files_nohandle="$tmpdir/files-nohandle-${now}.txt"
files_status="$tmpdir/files-status-${now}.txt"
files_size="$tmpdir/files-size-${now}.txt"
files_size_converted="$tmpdir/files-size-converted-${now}.txt"
files_btime="$tmpdir/files-btime-${now}.txt"
files_btime_converted="$tmpdir/files-btime-converted-${now}.txt"
files_volume="$tmpdir/files-volume-${now}.txt"
files_barcode="$tmpdir/files-barcode-${now}.txt"
output_csv="$tmpdir/output-${now}.csv"
output_final="$tmpdir/output_final-${now}.csv"

# Ensure all temp files exist (clear them)
for tmpfile in "$files_txt" "$files2_txt" "$files_handle" "$files_nohandle" \
               "$files_status" "$files_size" "$files_size_converted" \
               "$files_btime" "$files_btime_converted" "$files_volume" \
               "$files_barcode" "$output_csv" "$output_final"; do
    : > "$tmpfile"
done

log "Temp files created/cleared in $tmpdir"
report_progress 10 "Building file list..."

# Build file list (exclude meta files)
log "Building file list..."
find "$storage_path" -type f \
  -not -name '*.DS_Store' \
  -not -name '.*' \
  -not -name '*.p5c' \
  -not -name '*.p5a' \
  -print > "$files_txt" 2>/dev/null

total=$(wc -l < "$files_txt" 2>/dev/null | tr -d ' ')
log "Total files found: $total"

if [ "$total" -eq 0 ]; then
    log "Warning: No files found in $storage_path"
    report_progress 100 "No files found to check"
    echo "No files found in folder" > "$files_nohandle"
    
    summary="/Users/Shared/${now}-Files-To-Archive-$(basename "$storage_path").txt"
    cp "$files_nohandle" "$summary"
    echo "RESULT:SUMMARY:$summary" >&1
    exit 0
fi

report_progress 15 "Found $total files. Querying P5..."

# Process: get handle for each file
log "Querying P5 handles (writing results to $files_handle and $files_nohandle)..."
i=0
query_start=15
query_end=60

while IFS= read -r file; do
    i=$((i + 1))
    
    # Calculate progress (15% to 60% for this phase)
    if [ "$total" -gt 0 ]; then
        progress=$((query_start + (i * (query_end - query_start) / total)))
        
        # Update every 10 files or on significant progress changes
        if [ $((i % 10)) -eq 0 ] || [ $((i % (total / 10 + 1))) -eq 0 ]; then
            report_progress "$progress" "Checking file $i of $total..."
        fi
    fi
    
    # Query P5 for handle
    handle=$($chatcmd ArchiveEntry handle localhost "{${file}}" 2>/dev/null || true)

    if [ -n "$handle" ]; then
        echo "$handle" >> "$files_handle"
        printf '%s\t%s\n' "$file" "$handle" >> "${files_handle}.map"
    else
        echo "$file" >> "$files_nohandle"
    fi
done < "$files_txt"

report_progress 60 "Handles collected. Processing archive details..."

# Derive files2.txt as those that have handles
if [ -s "$files_nohandle" ]; then
    grep -v -F -f "$files_nohandle" "$files_txt" > "$files2_txt" 2>/dev/null || : > "$files2_txt"
else
    cp "$files_txt" "$files2_txt"
fi

handles_count=$(wc -l < "$files_handle" 2>/dev/null | tr -d ' ')
nohandle_count=$(wc -l < "$files_nohandle" 2>/dev/null | tr -d ' ')

log "Handles collected: $handles_count"
log "No-handle entries: $nohandle_count"

# If there are handles, fetch detailed information
if [ -s "$files_handle" ] && [ "$handles_count" -gt 0 ]; then
    report_progress 65 "Fetching archive status..."
    log "Fetching status for each handle..."
    
    while IFS= read -r handle; do
        $chatcmd ArchiveEntry "$handle" status 2>/dev/null >> "$files_status" || echo "" >> "$files_status"
    done < "$files_handle"

    report_progress 70 "Fetching file sizes..."
    log "Fetching size for each handle..."
    
    while IFS= read -r handle; do
        $chatcmd ArchiveEntry "$handle" size 2>/dev/null >> "$files_size" || echo "0" >> "$files_size"
    done < "$files_handle"

    report_progress 75 "Converting sizes..."
    log "Converting sizes to GB..."
    awk '{printf "%.3f\n", ($1+0)/1024/1024/1024}' "$files_size" > "$files_size_converted" 2>/dev/null || : > "$files_size_converted"

    report_progress 80 "Fetching backup times..."
    log "Fetching btime for each handle..."
    
    while IFS= read -r handle; do
        $chatcmd ArchiveEntry "$handle" btime 2>/dev/null >> "$files_btime" || echo "0" >> "$files_btime"
    done < "$files_handle"

    report_progress 85 "Converting timestamps..."
    log "Converting btime to readable date..."
    
    while IFS= read -r nixtime; do
        if [ -n "$nixtime" ] && [ "$nixtime" -ne 0 ] 2>/dev/null; then
            date -r "$nixtime" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo ""
        else
            echo ""
        fi
    done < "$files_btime" > "$files_btime_converted"

    report_progress 90 "Fetching volume information..."
    log "Fetching volume names..."
    
    while IFS= read -r handle; do
        $chatcmd ArchiveEntry "$handle" volume 2>/dev/null >> "$files_volume" || echo "" >> "$files_volume"
    done < "$files_handle"

    report_progress 92 "Fetching barcodes..."
    log "Fetching barcode for each volume..."
    
    while IFS= read -r vol; do
        if [ -z "$vol" ]; then
            echo "" >> "$files_barcode"
        else
            $chatcmd Volume "$vol" barcode 2>/dev/null >> "$files_barcode" || echo "" >> "$files_barcode"
        fi
    done < "$files_volume"
else
    log "No handles found — skipping handle-based queries."
    report_progress 90 "No archived files found"
fi

report_progress 95 "Generating reports..."

# Build CSV: combine all data with proper CSV escaping using Perl
log "Combining temp files into CSV: $output_csv"

# DEBUG: Check file line counts
log "DEBUG: Line counts before CSV generation:"
log "DEBUG: files2.txt: $(wc -l < "$files2_txt" 2>/dev/null || echo 0) lines"
log "DEBUG: files_handle: $(wc -l < "$files_handle" 2>/dev/null || echo 0) lines"
log "DEBUG: files_status: $(wc -l < "$files_status" 2>/dev/null || echo 0) lines"

# Ensure all files exist
for f in "$files2_txt" "$files_handle" "$files_status" "$files_size" "$files_size_converted" "$files_btime_converted" "$files_barcode"; do
    [ -f "$f" ] || : > "$f"
done

# DEBUG: Show first few lines of key files
log "DEBUG: First 3 lines of files2.txt:"
head -3 "$files2_txt" >> "$logfile" 2>&1

log "Using Perl for CSV generation with proper escaping"

# Use Perl for bulletproof CSV escaping (always available on macOS)
perl -e '
use strict;
use warnings;

# Escape CSV field according to RFC 4180
sub escape_csv {
    my ($field) = @_;
    $field = "" unless defined $field;
    
    # If field contains comma, quote, newline, or carriage return, wrap in quotes
    if ($field =~ /[,"\n\r]/) {
        # Double any existing quotes
        $field =~ s/"/""/g;
        # Wrap in quotes
        return "\"$field\"";
    }
    return $field;
}

# Print CSV header
print "File Path,P5 Handle,Status,Size,Size GB,Archived Date,Barcode\n";

# Open all input files
open(my $f1, "<", $ARGV[0]) or die "Cannot open $ARGV[0]: $!";
open(my $f2, "<", $ARGV[1]) or die "Cannot open $ARGV[1]: $!";
open(my $f3, "<", $ARGV[2]) or die "Cannot open $ARGV[2]: $!";
open(my $f4, "<", $ARGV[3]) or die "Cannot open $ARGV[3]: $!";
open(my $f5, "<", $ARGV[4]) or die "Cannot open $ARGV[4]: $!";
open(my $f6, "<", $ARGV[5]) or die "Cannot open $ARGV[5]: $!";
open(my $f7, "<", $ARGV[6]) or die "Cannot open $ARGV[6]: $!";

# Process line by line from all files simultaneously
while (1) {
    my $filepath = <$f1>;
    my $handle = <$f2>;
    my $status = <$f3>;
    my $size = <$f4>;
    my $size_gb = <$f5>;
    my $btime = <$f6>;
    my $barcode = <$f7>;
    
    # Break if any file reached EOF
    last unless defined $filepath;
    
    # Remove trailing newlines
    chomp($filepath) if defined $filepath;
    chomp($handle) if defined $handle;
    chomp($status) if defined $status;
    chomp($size) if defined $size;
    chomp($size_gb) if defined $size_gb;
    chomp($btime) if defined $btime;
    chomp($barcode) if defined $barcode;
    
    # Escape each field and print CSV line
    print escape_csv($filepath), ",",
          escape_csv($handle), ",",
          escape_csv($status), ",",
          escape_csv($size), ",",
          escape_csv($size_gb), ",",
          escape_csv($btime), ",",
          escape_csv($barcode), "\n";
}

# Close all files
close($f1);
close($f2);
close($f3);
close($f4);
close($f5);
close($f6);
close($f7);
' "$files2_txt" "$files_handle" "$files_status" "$files_size" "$files_size_converted" "$files_btime_converted" "$files_barcode" > "$output_csv"

# DEBUG: Check CSV line count and show sample
csv_lines=$(wc -l < "$output_csv" 2>/dev/null || echo 0)
log "DEBUG: CSV generated with $csv_lines lines (should be $handles_count + 1 with header)"
log "DEBUG: First 3 lines of CSV:"
head -3 "$output_csv" >> "$logfile" 2>&1

# Copy outputs to /Users/Shared
summary="/Users/Shared/${now}-Files-To-Archive-$(basename "$storage_path").txt"
archived_csv="/Users/Shared/${now}-Archived-$(basename "$storage_path").csv"
backup_tar="/Users/Shared/${now}-$(basename "$storage_path").bak.tar.gz"

if [ -s "$files_nohandle" ]; then
    cp "$files_nohandle" "$summary"
    log "Wrote not-archived list to $summary"
else
    echo "All files archived. $storage_path" > "$summary"
    log "All files archived; wrote confirmation to $summary"
fi

cp "$output_csv" "$archived_csv"
log "Wrote archived CSV to $archived_csv"

report_progress 98 "Creating backup archive..."

# Create backup tar containing the temp files we generated
log "Creating backup archive $backup_tar"
tar zcf "$backup_tar" \
  "$files_txt" \
  "$files2_txt" \
  "$files_handle" \
  "$files_nohandle" \
  "$files_status" \
  "$files_size" \
  "$files_size_converted" \
  "$files_btime" \
  "$files_btime_converted" \
  "$files_volume" \
  "$files_barcode" \
  "$output_csv" \
  2>>"$logfile" && log "Backup saved to $backup_tar" || log "Warning: tar failed"

# Move log file to Shared folder for permanent record
final_log="/Users/Shared/p5-check-$(basename "$storage_path")-${now}.log"
if [ -f "$logfile" ]; then
    cp "$logfile" "$final_log"
    log "Log file copied to $final_log"
fi

# Output result paths for Swift to parse (on stdout)
echo "RESULT:SUMMARY:$summary"
echo "RESULT:CSV:$archived_csv"
echo "RESULT:BACKUP:$backup_tar"
echo "RESULT:LOG:$final_log"
echo "RESULT:TOTAL:$total"
echo "RESULT:ARCHIVED:$handles_count"
echo "RESULT:NOT_ARCHIVED:$nohandle_count"

report_progress 100 "Complete!"

# Clean up temporary files
log "Cleaning up temporary files..."
rm -f \
  "$files_txt" \
  "$files2_txt" \
  "$files_handle" \
  "${files_handle}.map" \
  "$files_nohandle" \
  "$files_status" \
  "$files_size" \
  "$files_size_converted" \
  "$files_btime" \
  "$files_btime_converted" \
  "$files_volume" \
  "$files_barcode" \
  "$output_csv" \
  "$output_final" \
  "$progressfile" 2>/dev/null || true

log "=== Script finished: Checked $total files. Archived: $handles_count. Not archived: $nohandle_count ==="
exit 0
