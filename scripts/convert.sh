#!/bin/bash

# Function to convert a single UBV file
convert_ubv() {
    local input_file="$1"
    local output_dir="/output/$(dirname "${input_file#/volume1/.srv/unifi-protect/video/2025/}")"
    local filename=$(basename "$input_file" .ubv)
    local output_file="$output_dir/$filename.mp4"
    
    mkdir -p "$output_dir"
    
    # Extract metadata using UniFi Protect tools
    # TODO: Add UniFi Protect specific extraction commands
    
    # Convert using ffmpeg (placeholder - needs UniFi specific parameters)
    ffmpeg -i "$input_file" -c:v copy -c:a copy "$output_file"
}

# Process all UBV files
find /volume1/.srv/unifi-protect/video/2025 -type f -name "*.ubv" | while read -r file; do
    echo "Converting: $file"
    convert_ubv "$file"
done
