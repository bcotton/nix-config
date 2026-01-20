#!/bin/zsh

# This script is designed for use with the macc Shortcuts app. 

usage() {
    echo "Usage: $0 <file_path>"
    exit 1
}

if [ $# -eq 1 ]; then
    file_path="$1"
else
    usage
fi

# Check if the file exists
if [ ! -f "$file_path" ]; then
    echo "File not found: $file_path"
    exit 1
fi

dir_path=$(dirname "$file_path")
file_name=$(basename "$file_path")

dot_date_regex='^[0-9]{4}\.[0-9]{2}\.[0-9]{2}_'
if [ $file_name = $dot_date_regex ]; then # file is already in dotdate format
    filename_dot_date="${file_name:0:10}"
    mkdir -p "$dir_path/$filename_dot_date"
    mv -n "$file_path" "$dir_path/$filename_dot_date/$file_name"
else # file is not in dotdate format
    creation_date=$(stat -f "%SB" -t "%Y.%m.%d" "$file_path")
    mkdir -p "$dir_path/$creation_date"
    mv -n "$file_path" "$dir_path/$creation_date/$file_name"
fi