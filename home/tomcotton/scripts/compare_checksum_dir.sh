#!/bin/zsh

# This script will calculate the checksum of all files in a directory  
# and compare the checksums to a file.

echo "usage: compare_checksum_dir.sh <directory> <input file>"
echo "Calculating sha256 checksums for all files in $1, writing $2"

mtree -p $1 < $2 || echo fail