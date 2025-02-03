#!/bin/bash

set -e

# Display note about original script
echo "Note: This script is inspired by Lars Wirzenius' original 'genbackupdata' Python script."
echo "      It aims to provide similar functionality in a bash environment."
echo "      https://git.liw.fi/genbackupdata"
echo
echo "Important: All size options (-c, -f, -k) expect values in bytes."
echo "           This script uses OpenSSL's AES-256-CTR for deterministic"
echo "           random data generation based on the provided seed."
echo

# Default values
CREATE_SIZE=$((1024 * 1024 * 1024))  # 1GB
FILE_SIZE=$((16 * 1024))  # 16KB
DEPTH=3
MAX_FILES=4
SEED=0
QUIET=false
CREATE_ARCHIVE=false

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS] OUTPUT_DIR"
    echo "Options:"
    echo "  -c, --create SIZE    Amount of data to create in bytes (default: 1073741824)"
    echo "  -f, --file-size SIZE Size of one file in bytes (default: 16384)"
    echo "  -d, --depth DEPTH    Depth of directory tree (default: 3)"
    echo "  -m, --max-files NUM  Max files/dirs per dir (default: 4)"
    echo "  -s, --seed SEED      Seed for random number generator (default: 0)"
    echo "  -q, --quiet          Do not report progress"
    echo "  -a, --archive        Create a deterministic archive of the output"
    echo "  -h, --help           Show this help message"
    echo "Note: All SIZE values are in bytes."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--create) CREATE_SIZE=$2; shift 2 ;;
        -f|--file-size) FILE_SIZE=$2; shift 2 ;;
        -d|--depth) DEPTH=$2; shift 2 ;;
        -m|--max-files) MAX_FILES=$2; shift 2 ;;
        -s|--seed) SEED=$2; shift 2 ;;
        -q|--quiet) QUIET=true; shift ;;
        -a|--archive) CREATE_ARCHIVE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) OUTPUT_DIR=$1; shift ;;
    esac
done

if [ -z "$OUTPUT_DIR" ]; then
    echo "Error: OUTPUT_DIR is required"
    usage
    exit 1
fi

# Delete the target directory if it exists
if [ -d "$OUTPUT_DIR" ]; then
    echo "Removing existing directory: $OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR"
fi

# Function to generate deterministic random data
generate_data() {
    local size=$1
    local output_file=$2
    dd if=/dev/zero bs=$size count=1 2>/dev/null | openssl enc -aes-256-ctr -pass pass:"$SEED" -nosalt -pbkdf2 > "$output_file"
}

# Function to create nested directories with fixed timestamp
create_nested_dirs() {
    local base_dir=$1
    local depth=$2
    local max_files=$3
    local current_depth=$4
    local current_num=$5

    if [ $current_depth -eq $depth ]; then
        echo "${base_dir}/${current_num}"
        return
    fi

    local dir_num=$((current_num / max_files))
    local sub_num=$((current_num % max_files))
    local new_dir="${base_dir}/${dir_num}"
    mkdir -p "$new_dir"
    touch -t 202001010000.00 "$new_dir"  # Set a fixed timestamp
    create_nested_dirs "$new_dir" $depth $max_files $((current_depth + 1)) $sub_num
}

# Main loop
total_written=0
file_counter=0

while [ $total_written -lt $CREATE_SIZE ]; do
    # Calculate remaining bytes and adjust file size if necessary
    remaining=$((CREATE_SIZE - total_written))
    current_file_size=$FILE_SIZE
    [ $remaining -lt $FILE_SIZE ] && current_file_size=$remaining

    # Generate file path
    file_path=$(create_nested_dirs "$OUTPUT_DIR" $DEPTH $MAX_FILES 0 $file_counter)
    mkdir -p "$(dirname "$file_path")"

    # Generate and write data
    generate_data $current_file_size "$file_path"
    
    if [ $? -ne 0 ]; then
        echo "Error writing to file: $file_path"
        exit 1
    fi

    total_written=$((total_written + current_file_size))

    # Set a fixed timestamp for the file
    touch -t 202001010000.00 "$file_path"

    file_counter=$((file_counter + 1))

    # Print progress
    if [ "$QUIET" = false ]; then
        printf "\rGenerated %d bytes of %d bytes (%.2f%%)" $total_written $CREATE_SIZE $(echo "scale=2; $total_written * 100 / $CREATE_SIZE" | bc)
    fi
done

echo -e "\nDone generating backup data."

# Optional: Create a deterministic archive
if [ "$CREATE_ARCHIVE" = true ]; then
    echo "Creating deterministic archive..."
    tar --sort=name \
        --owner=root:0 --group=root:0 \
        --mtime='2020-01-01 00:00:00' \
        -cf "${OUTPUT_DIR}.tar" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")"
    echo "Archive created: ${OUTPUT_DIR}.tar"
fi