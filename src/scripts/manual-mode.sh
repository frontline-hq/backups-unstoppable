#!/bin/bash

export PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "${PROJECT_ROOT}/src/scripts/common.sh"

# Parse arguments
directory=""

# Show usage message
usage() {
    echo "Usage: $0 <directory_path>"
}

# Check if exactly one argument is provided
if [ $# -ne 1 ]; then
    echo "Error: This script requires exactly one directory path."
    usage
    exit 1
fi

# Validate the directory exists
directory="$1"
if [ ! -d "$directory" ]; then
    echo "Error: '$directory' does not exist or is not a directory."
    exit 1
fi

# Check if a directory is provided
if [ -z "$directory" ]; then
    echo "Error: Please provide a directory path."
    usage
    exit 1
fi

setup_environment --detach

# Provide information about the running environment
echo "Docker containers are now running in the background."
echo "You have access to the host system shell."
echo "Use 'docker ps' to see running containers."
echo "When you're done, type 'exit' to stop the containers and clean up."
echo

echo "Setting up MinIO..."
setup_minio --create-new-bucket "http://minio:9000" "$directory"

echo "Starting rustic shell..."
docker-compose --env-file "${PROJECT_ROOT}/vars/test/.env" --env-file "$directory/.env" run rustic sh

# When the user exits the shell, run the cleanup command
echo "Cleaning up..."
teardown_environment

echo "Done."
