#!/bin/bash

# Configuration
INPUT_DIR="/private/tmp/protect"
OUTPUT_DIR="/private/tmp/protect/converted"
LOCK_DIR="/private/tmp/protect/.locks"
LOG_FILE="/private/tmp/protect/conversion.log"
MAX_PARALLEL=12  # Optimized for M3 CPU with 14 cores

# Create necessary directories
mkdir -p "$OUTPUT_DIR" "$LOCK_DIR"
touch "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

verify_ubv() {
    local ubv_file="$1"
    if ! msr_ubvinfo -f "$ubv_file" &>/dev/null; then
        log "ERROR: Failed to verify UBV file: $ubv_file"
        return 1
    fi
    return 0
}

verify_mp4() {
    local mp4_file="$1"
    if ! ffmpeg -v error -i "$mp4_file" -f null - &>/dev/null; then
        log "ERROR: Failed to verify MP4 file: $mp4_file"
        return 1
    fi
    return 0
}

is_file_complete() {
    local file="$1"
    local lock_file="$LOCK_DIR/$(basename "$file").lock"

    # Check if file is being written to
    if lsof "$file" &>/dev/null; then
        return 1
    fi

    # Determine correct stat command for file size (Linux vs macOS)
    local size_cmd
    if stat -c %s "$file" >/dev/null 2>&1; then
        size_cmd="stat -c %s"
    else
        size_cmd="stat -f %z"
    fi

    # Check file size hasn't changed in last 30 seconds
    local size1=$(eval $size_cmd "$file")
    sleep 30
    local size2=$(eval $size_cmd "$file")

    if [ "$size1" -eq "$size2" ] 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

convert_file() {
    local ubv_file="$1"
    local base_name=$(basename "$ubv_file" .ubv)
    local mp4_file="$OUTPUT_DIR/${base_name}.mp4"
    local lock_file="$LOCK_DIR/${base_name}.lock"
    
    # Create lock file
    if ! mkdir "$lock_file" 2>/dev/null; then
        log "Skipping $ubv_file - already being processed"
        return
    fi
    
    log "Starting conversion of $ubv_file"
    
    # Verify UBV file
    if ! verify_ubv "$ubv_file"; then
        rm -rf "$lock_file"
        return
    fi
    
    # Convert to MP4 using msr_ubvexport (produces basepath_%%d.mp4 files)
    local dst_base="$OUTPUT_DIR/${base_name}"
    if ! msr_ubvexport -s "$ubv_file" -d "$dst_base" 2>/dev/null; then
        log "ERROR: Failed to convert $ubv_file to MP4"
        rm -rf "$lock_file"
        return
    fi

    # Verify generated MP4 files
    shopt -s nullglob
    local generated=("${dst_base}"_*.mp4)
    shopt -u nullglob

    if [ ${#generated[@]} -eq 0 ]; then
        log "ERROR: No MP4 files were produced for $ubv_file"
        rm -rf "$lock_file"
        return
    fi

    local all_ok=1
    for mp4 in "${generated[@]}"; do
        if ! verify_mp4 "$mp4"; then
            log "ERROR: Verification failed for $mp4"
            all_ok=0
            rm -f "$mp4"
        fi
    done

    if [ $all_ok -eq 1 ]; then
        log "Successfully converted $ubv_file to ${#generated[@]} MP4 file(s)"
        rm -f "$ubv_file"  # Remove original UBV file
    else
        log "One or more outputs failed verification for $ubv_file"
    fi
    
    rm -rf "$lock_file"
}

export -f log verify_ubv verify_mp4 convert_file
export INPUT_DIR OUTPUT_DIR LOCK_DIR LOG_FILE

# Process files in specified order (06, 07, 08)
for month in "06" "07" "08"; do
    # Prefer year/month subdirectories if present, else fallback to name match
    if [ -d "$INPUT_DIR/2025/$month" ]; then
        search_path="$INPUT_DIR/2025/$month"
    else
        search_path="$INPUT_DIR"
    fi

    find "$search_path" -type f -name "*.ubv" -print0 |
        while IFS= read -r -d '' file; do
            if is_file_complete "$file"; then
                # Use NUL-delimited output for xargs -0
                printf '%s\0' "$file"
            fi
        done |
        xargs -0 -P $MAX_PARALLEL -I {} bash -c 'convert_file "$@"' _ {}
done

log "Conversion process completed"
