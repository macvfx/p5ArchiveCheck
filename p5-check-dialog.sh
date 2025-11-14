#!/bin/sh
# Copyright Mat X 2025 - All Rights Reserved
# Check if files in a given folder were archived by Archiware P5
# with lightweight logging and explicit temp file creation + proper cleanup

# Path to nsdchat and dialog
chatcmd="/usr/local/aw/bin/nsdchat -c"
dialog="./dialog"

# Get the current timestamp
now=$(date +"%Y-%m-%d_%H%M%S")

# Lightweight log file
logfile="/private/tmp/p5-check.log"

# start fresh
: > "$logfile"

# Function for logging with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$logfile"
}

log "=== Script started at $now ==="

# Ask user for drag-drop folder if not provided
if [ -z "${1:-}" ]; then
    log "No folder argument provided; expecting an argument."
    echo "Usage: $0 /path/to/folder"
    exit 1
else
    storage_path="$1"
    log "Using provided path: $storage_path"
fi

# Validate path
if [ ! -d "$storage_path" ]; then
    log "Error: Invalid folder path: $storage_path"
    echo "Invalid folder path: $storage_path"
    exit 1
fi

# Command file for dialog
cmdfile="/private/tmp/${now}-$(basename "$storage_path")-dialog.log"
log "Command file will be: $cmdfile"

# Create/clear temp files up front
tmpdir="/private/tmp"
files_txt="$tmpdir/files.txt"
files2_txt="$tmpdir/files2.txt"
files_handle="$tmpdir/files-handle.txt"
files_nohandle="$tmpdir/files-no-handle.txt"
files_status="$tmpdir/files-status.txt"
files_size="$tmpdir/files-size.txt"
files_size_converted="$tmpdir/files-size-converted.txt"
files_btime="$tmpdir/files-btime.txt"
files_btime_converted="$tmpdir/files-btime-converted.txt"
files_volume="$tmpdir/files-volume.txt"
files_barcode="$tmpdir/files-barcode.txt"
output_csv="$tmpdir/output.csv"
output_final="$tmpdir/output_final.csv"

# Ensure all temp files exist (clear them)
: > "$cmdfile"
: > "$files_txt"
: > "$files2_txt"
: > "$files_handle"
: > "$files_nohandle"
: > "$files_status"
: > "$files_size"
: > "$files_size_converted"
: > "$files_btime"
: > "$files_btime_converted"
: > "$files_volume"
: > "$files_barcode"
: > "$output_csv"
: > "$output_final"

log "Temp files created/cleared in $tmpdir"

# Start dialog (if available) — uses cmdfile for progress updates
if command -v "$dialog" >/dev/null 2>&1; then
    "$dialog" --mini \
      -t "Check for files archived by P5" \
      -m "Checking $(basename "$storage_path") for files archived" \
      --progress 100 \
      --icon ./ArchiwareP5Archive-256.png \
      --commandfile "$cmdfile" &
    dialog_pid=$!
    log "Started dialog (pid $dialog_pid)"
else
    log "dialog binary not found; continuing without GUI dialog"
    dialog_pid=""
fi

# Build file list (exclude meta if you want similar filters)
log "Building file list..."
find "$storage_path" -type f \
  -not -name '*.DS_Store' \
  -not -name '.*' \
  -not -name '*.p5c' \
  -not -name '*.p5a' \
  -print > "$files_txt"

total=$(wc -l < "$files_txt" 2>/dev/null || echo 0)
log "Total files found: $total"

# Process: get handle for each file and write to temp files
log "Querying P5 handles (writing results to $files_handle and $files_nohandle)..."
i=0
while IFS= read -r file; do
    i=$((i + 1))
    # Use chatcmd to request handle; store raw output in files-handle or record missing
    handle=$($chatcmd ArchiveEntry handle localhost "{${file}}" 2>/dev/null || true)

    if [ -n "$handle" ]; then
        echo "$handle" >> "$files_handle"
        # Save mapping if desired: store file path adjacent to handle
        printf '%s\t%s\n' "$file" "$handle" >> "${files_handle}.map"
    else
        echo "$file" >> "$files_nohandle"
    fi

    # update progress to dialog (safe if cmdfile is present)
    if [ -n "$total" ] && [ "$total" -gt 0 ]; then
        progress=$((i * 100 / total))
        echo "progress $progress" > "$cmdfile"
    fi
done < "$files_txt"

# Derive files2.txt as those that have handles: join via grep -f of handles.map if exists
# We'll create files2_txt by removing files in no-handle list from files.txt
if [ -s "$files_nohandle" ]; then
    grep -v -F -f "$files_nohandle" "$files_txt" > "$files2_txt"
else
    cp "$files_txt" "$files2_txt"
fi

log "Handles collected: $(wc -l < "$files_handle" 2>/dev/null || echo 0)"
log "No-handle entries: $(wc -l < "$files_nohandle" 2>/dev/null || echo 0)"

# If there are handles, fetch status, size, btime, volume, barcode — writing outputs to temp files
if [ -s "$files_handle" ]; then
    log "Fetching status for each handle into $files_status..."
    while IFS= read -r handle; do
        $chatcmd ArchiveEntry "$handle" status >> "$files_status" 2>/dev/null || echo "" >> "$files_status"
    done < "$files_handle"

    log "Fetching size for each handle into $files_size..."
    while IFS= read -r handle; do
        $chatcmd ArchiveEntry "$handle" size >> "$files_size" 2>/dev/null || echo "0" >> "$files_size"
    done < "$files_handle"

    log "Converting sizes to GB into $files_size_converted..."
    awk '{printf "%.3f\n", ($1+0)/1024/1024/1024}' "$files_size" > "$files_size_converted" 2>/dev/null || : > "$files_size_converted"

    log "Fetching btime for each handle into $files_btime..."
    while IFS= read -r handle; do
        $chatcmd ArchiveEntry "$handle" btime >> "$files_btime" 2>/dev/null || echo "0" >> "$files_btime"
    done < "$files_handle"

    log "Converting btime to readable date into $files_btime_converted..."
    while IFS= read -r nixtime; do
        if [ -n "$nixtime" ] && [ "$nixtime" -ne 0 ] 2>/dev/null; then
            date -r "$nixtime" "+%Y-%m-%d %H:%M:%S"
        else
            echo ""
        fi
    done < "$files_btime" > "$files_btime_converted"

    log "Fetching volume names into $files_volume..."
    while IFS= read -r handle; do
        $chatcmd ArchiveEntry "$handle" volume >> "$files_volume" 2>/dev/null || echo "" >> "$files_volume"
    done < "$files_handle"

    log "Fetching barcode for each volume into $files_barcode..."
    # iterate volumes (may contain duplicates if many files on same volume)
    while IFS= read -r vol; do
        # For empty volumes, add empty line
        if [ -z "$vol" ]; then
            echo "" >> "$files_barcode"
        else
            $chatcmd Volume "$vol" barcode >> "$files_barcode" 2>/dev/null || echo "" >> "$files_barcode"
        fi
    done < "$files_volume"

else
    log "No handles found — skipping handle-based queries."
fi

# Build CSV: combine files2, handles, status, size, size-converted, btime-converted, barcode
log "Combining temp files into CSV: $output_csv"
# Use paste -d ',' safely; ensure files exist by providing empty filler files if necessary
for f in "$files2_txt" "$files_handle" "$files_status" "$files_size" "$files_size_converted" "$files_btime_converted" "$files_barcode"; do
    [ -f "$f" ] || : > "$f"
done

paste -d ',' \
  "$files2_txt" \
  "$files_handle" \
  "$files_status" \
  "$files_size" \
  "$files_size_converted" \
  "$files_btime_converted" \
  "$files_barcode" > "$output_csv"

# Prepend header
{
  echo 'File Path,P5 Handle,Status,Size,Size GB,Archived Date,Barcode'
  cat "$output_csv"
} > "$output_final"
mv "$output_final" "$output_csv"

# Copy outputs to /Users/Shared
summary="/Users/Shared/${now}-Files-To-Archive-$(basename "$storage_path").txt"
archived_csv="/Users/Shared/${now}-Archived-$(basename "$storage_path").csv"
backup_tar="/Users/Shared/${now}-$(basename "$storage_path").bak.tar.gz"

if [ -s "$files_nohandle" ]; then
    cp "$files_nohandle" "$summary"
    log "Wrote not-archived list to $summary"
else
    echo "All files archived. $storage_path" > "$files_nohandle"
    cp "$files_nohandle" "$summary"
    log "All files archived; wrote confirmation to $summary"
fi

cp "$output_csv" "$archived_csv"
log "Wrote archived CSV to $archived_csv"

# Finish dialog progress and quit
if [ -n "${dialog_pid:-}" ]; then
    echo "progress: 100" >> "$cmdfile"
    echo "message: Completed check for $(basename "$storage_path")" >> "$cmdfile"
    echo "progress: complete" >> "$cmdfile"
    echo "quit:" >> "$cmdfile"
    log "Sent completion commands to dialog."
    sleep 2
    kill "$dialog_pid" 2>/dev/null || true
    log "Dialog process (pid $dialog_pid) terminated."
else
    log "No dialog process found to close."
fi

# Create backup tar containing the temp files we generated
log "Creating backup archive $backup_tar (includes temp files)"
tar zcf "$backup_tar" \
  "$cmdfile" \
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
  2>>"$logfile" && log "Backup saved to $backup_tar" || log "Warning: tar failed (see $logfile)"

# Open the results if possible
if command -v open >/dev/null 2>&1; then
    open "$summary" || true
    open "$archived_csv" || true
fi

# Clean up temporary files
log "Cleaning up temporary files..."
rm -f \
  "$cmdfile" \
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
  "$output_final" 2>/dev/null || true

# Move log file to Shared folder for permanent record
final_log="/Users/Shared/p5-check-$(basename "$storage_path")-${now}.log"
if [ -f "$logfile" ]; then
    mv "$logfile" "$final_log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file moved to $final_log" >> "$final_log"
else
    echo "Warning: log file missing" > "$final_log"
fi

log "=== Script finished: Checked $total files. Archived: $(wc -l < "$files_handle" 2>/dev/null || echo 0). Not archived: $(wc -l < "$files_nohandle" 2>/dev/null || echo 0) ==="
exit 0
