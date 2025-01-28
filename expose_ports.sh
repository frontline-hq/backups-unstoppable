#!/bin/bash

# Function to run commands in parallel and display output
run_parallel() {
    local pids=()

    # Iterate over the commands
    for i in "${!labels[@]}"; do
        label="${labels[$i]}"
        cmd="${commands[$i]}"
        # Use a subshell to run each command and prefix its output with the label
        (
            while IFS= read -r line; do
                echo "[$label] $line"
            done < <(eval "$cmd" 2>&1)
        ) &
        pids+=($!)
    done

    # Setup trap to handle SIGINT (Ctrl+C)
    trap 'echo "Terminating..."; kill ${pids[@]} 2>/dev/null; exit 1' INT

    # Wait for user to terminate (this will run indefinitely)
    wait
}

# Define arrays for labels and commands
labels=(
    "MINIO-PERSISTED"
    "MINIO-TEMPORARY"
)

commands=(
    "kubectl port-forward -n minio-persisted svc/minio-persisted-console 9001:9001"
    "kubectl port-forward -n minio-temporary svc/minio-temporary-console 8001:9001"
)

# Run commands in parallel
run_parallel

echo "All commands have been terminated."