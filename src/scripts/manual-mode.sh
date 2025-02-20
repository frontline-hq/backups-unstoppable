#!/bin/bash

export PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "${PROJECT_ROOT}/src/scripts/common.sh"

# Check if a directory is provided
if [ $# -eq 0 ]; then
    echo "Please provide a directory path."
    exit 1
fi

setup_environment

# Provide information about the running environment
echo "Docker containers are now running in the background."
echo "You have access to the host system shell."
echo "Use 'docker ps' to see running containers."
echo "When you're done, type 'exit' to stop the containers and clean up."
echo

setup_minio --create-new-bucket "http://minio:9000" "$1"
docker-compose --env-file "${PROJECT_ROOT}/vars/test/.env" --env-file "$1/.env" run rustic sh

# When the user exits the shell, run the cleanup command
echo "Cleaning up..."
teardown_environment

echo "Done."