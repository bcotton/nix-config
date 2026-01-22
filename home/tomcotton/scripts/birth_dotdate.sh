#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 <file_path> <operation>"
    echo "Operations:"
    echo " -r, --rename   : Completely rename the file to creation time"
    echo " -a, --append   : Append creation time to the existing filename"
    echo " -p, --prepend  : Prepend creation time to the existing filename"
    exit 1
}

# Parse arguments
if [ $# -eq 2 ]; then
    file_path="$1"
    operation="$2"
else
    usage
fi

# Validate operation
case "$operation" in
    -r|--rename|-a|--append|-p|--prepend)
        ;;
    *)
        echo "Invalid operation. Use -r, -a, or -p."
        usage
        ;;
esac

# Check if the file exists
if [ ! -f "$file_path" ]; then
    echo "File not found: $file_path"
    exit 1
fi

# Get the directory and filename components of the file path
dir_path=$(dirname "$file_path")
file_name=$(basename "$file_path")

# Perform renaming based on the chosen operation
case "$operation" in
    -r|--rename)
        ext="${file_name##*.}"
        base="$(stat -f "%SB" -t "%Y.%m.%d_%H.%M.%S" "$file_path")"
        new_name="${base}.${ext}"
        new_path="${dir_path}/${new_name}"
        counter=0
        while [ -e "$new_path" ]; do
            counter=$((counter + 1))
            new_name="${base}_$(printf "%02d" "$counter").${ext}"
            new_path="${dir_path}/${new_name}"
        done
        mv -n "$file_path" "$new_path"
        echo "Renamed: $file_path -> $new_path"
        ;;
    -a|--append)
        ext="${file_name##*.}"
        base="${file_name%.*}"
        timestamp="$(stat -f "%SB" -t "%Y.%m.%d_%H.%M.%S" "$file_path")"
        new_name="${base}_${timestamp}.${ext}"
        new_path="${dir_path}/${new_name}"
        mv -n "$file_path" "$new_path"
        echo "Renamed: $file_path -> $new_path"
        ;;
    -p|--prepend)
        ext="${file_name##*.}"
        base="${file_name%.*}"
        timestamp="$(stat -f "%SB" -t "%Y.%m.%d_%H.%M.%S" "$file_path")"
        new_name="${timestamp}_${base}.${ext}"
        new_path="${dir_path}/${new_name}"
        mv -n "$file_path" "$new_path"
        echo "Renamed: $file_path -> $new_path"
        ;;
esac