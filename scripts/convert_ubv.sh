#!/bin/bash

echo "Scanning for UBV files..."

convert_file() {
    local input_file="$1"
    local relative_path=${input_file#/volume1/.srv/unifi-protect/video/2025/}
    local output_dir="/output/${relative_path%/*}"
    local filename=$(basename "$input_file" .ubv)
    
    mkdir -p "$output_dir"
    echo "Converting $input_file to $output_dir/$filename.mp4"
    
    # Use UniFi Protect binary to get the stream info
    /usr/share/unifi-protect/bin/unifi-protect stream --input="$input_file" | \
    ffmpeg -i pipe:0 -c:v copy -c:a copy "$output_dir/$filename.mp4"
}

# Process all UBV files
find /volume1/.srv/unifi-protect/video/2025 -type f -name "*.ubv" | while read -r file; do
    convert_file "$file"
done
