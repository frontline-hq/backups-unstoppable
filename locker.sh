#!/bin/bash

# Function to show usage
usage() {
    echo "Usage: $0 <mode>"
    echo "  <mode>: Either 'lock' or 'unlock'"
    echo ""
    echo "Note: The key should be stored in a .env file in the same directory as this script."
    echo "The .env file should contain a line like: PASSWORD=<your-256-bit-key-in-hex>"
    echo ""
    echo "Tip: To generate a suitable 256-bit key, you can use the following command:"
    echo "  botan rng --format=hex 32"
    exit 1
}

# Check if one argument is provided
if [ $# -ne 1 ]; then
    usage
fi

# Assign argument to variable
MODE="$1"

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Read the key from the .env file
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "Error: .env file not found in the script directory."
    exit 1
fi

# Check if the PASSWORD variable is set
if [ -z "$PASSWORD" ]; then
    echo "Error: PASSWORD not found in .env file."
    exit 1
fi

# Validate the key (hex encoded 256-bit key is 64 characters long)
if ! [[ $PASSWORD =~ ^[0-9A-Fa-f]{64}$ ]]; then
    echo "Error: Invalid key in .env file. Please provide a 256-bit key in hexadecimal format (64 characters)."
    echo "Tip: You can generate a suitable key using: botan rng --format=hex 32"
    exit 1
fi

# Change to the vars directory
cd "$SCRIPT_DIR/vars" || { echo "Error: ./vars directory not found."; exit 1; }

# Function to lock directories
lock() {
    for dir in */; do
        if [ -d "$dir" ]; then
            echo "Locking $dir"
            "$SCRIPT_DIR/encrypt_decrypt.sh" "$dir" encrypt "$PASSWORD"
        fi
    done
}

# Function to unlock directories
unlock() {
    for dir in */; do
        if [ -d "$dir" ]; then
            echo "Unlocking $dir"
            "$SCRIPT_DIR/encrypt_decrypt.sh" "$dir" decrypt "$PASSWORD"
        fi
    done
}

# Perform the requested operation
case "$MODE" in
    lock)
        lock
        ;;
    unlock)
        unlock
        ;;
    *)
        echo "Error: Invalid mode. Use 'lock' or 'unlock'."
        usage
        ;;
esac