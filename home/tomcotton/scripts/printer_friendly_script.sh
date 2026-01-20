#!/bin/bash

# Check if filename argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <image_file>"
    echo "Example: $0 photo.jpg"
    exit 1
fi

input_file="$1"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' not found."
    exit 1
fi

# Extract filename without extension and extension separately
filename="${input_file%.*}"
extension="${input_file##*.}"

# Create output filename with "printer-friendly" appended
output_file="${filename}-printer-friendly.${extension}"

# Run ImageMagick command
echo "Converting '$input_file' to printer-friendly format..."
magick "$input_file" -colorspace Gray -brightness-contrast -25,40 "$output_file"

# Check if conversion was successful
if [ $? -eq 0 ]; then
    echo "Successfully created: $output_file"
else
    echo "Error: Conversion failed."
    exit 1
fi