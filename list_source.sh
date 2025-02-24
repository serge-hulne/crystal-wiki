#!/bin/bash
# Usage: ./list_source.sh [directory]
# Defaults to the current directory if none is specified.

DIR="${1:-.}"

# Use find to get all regular files, skipping files with these extensions
find "$DIR" -type f \
  ! -iname '*.db' \
  ! -iname '*.png' \
  ! -iname '*.jpg' \
  ! -iname '*.jpeg' \
  ! -iname '*.gif' \
  ! -iname '*.exe' \
  ! -iname '*.pdf' | while read -r file; do
    echo "Filename: $file"
    echo "-----------------------"
    cat "$file"
    echo -e "\n\n\n"  # Three blank lines as a separator
done
