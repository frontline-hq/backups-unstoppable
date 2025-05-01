#!/bin/bash

# Common variables
export SFTP_HOST_PUBKEY=$(cat "${PROJECT_ROOT}/vars/test/host_id_ed25519.pub")
export SFTP_USER_PRIVKEY=$(cat "${PROJECT_ROOT}/vars/test/user_id_ed25519")

# Common functions
setup_environment() {
    local detach=false

    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --detach)
                detach=true
                ;;
        esac
        shift
    done

    docker build -t rustic-image:latest \
        --build-arg ENV="test" \
        --build-arg USER_ID=$(id -u) \
        --build-arg GROUP_ID=$(id -g) "${PROJECT_ROOT}/src"
    local docker_compose_base_cmd="docker-compose --env-file \"${PROJECT_ROOT}/vars/test/.env\" -f \"${PROJECT_ROOT}/test/docker-compose.yaml\""
    local docker_compose_up_cmd="${docker_compose_base_cmd} up --remove-orphans"

    # Add --detach flag if specified
    if $detach; then
        docker_compose_up_cmd="$docker_compose_up_cmd --detach --wait"
    fi

    # Start all services
    eval $docker_compose_up_cmd
}

teardown_environment() {
    docker-compose -f "${PROJECT_ROOT}/test/docker-compose.yaml" down --volumes
}

setup_minio() {
    local interactive=false
    local create_new_bucket=""
    local clear_bucket=false

    while [[ "$#" -gt 1 ]]; do
        case $1 in
            --interactive) interactive=true ;;
            --create-new-bucket) create_new_bucket="$2"; shift ;;
            --clear-bucket) clear_bucket=true ;;
            *) echo "Unknown parameter: $1"; return 1 ;;
        esac
        shift
    done

    local dir="${!#}"

    if [[ -z "$dir" ]]; then
        echo "Error: Directory parameter is required"
        return 1
    fi

    echo "Debug: Directory: $dir"
    echo "Debug: Interactive mode: $interactive"
    echo "Debug: Create new bucket condition: $create_new_bucket"
    echo "Debug: Clear bucket: $clear_bucket"

    source "${PROJECT_ROOT}/vars/test/.env"
    source "$dir/.env"

    echo "Debug: REMOTE_ENDPOINT: $REMOTE_ENDPOINT"
    echo "Debug: REMOTE_BUCKET_NAME: $REMOTE_BUCKET_NAME"
    echo "Debug: REMOTE_ACCESS_KEY_ID: $REMOTE_ACCESS_KEY_ID"
    echo "Debug: REMOTE_PATH: $REMOTE_PATH"

    local docker_cmd="docker run --rm --network test-net-external"

    if $interactive; then
        docker_cmd+=" -it"
        echo "Debug: Running in interactive mode"
    else
        echo "Debug: Running in non-interactive mode"
    fi

    docker_cmd+=" --entrypoint=/bin/sh minio/mc -c"

    local minio_cmds="mc alias set myminio ${REMOTE_ENDPOINT} ${REMOTE_ADMIN_ACCESS_KEY_ID:-${REMOTE_ACCESS_KEY_ID}} ${REMOTE_ADMIN_SECRET_ACCESS_KEY:-${REMOTE_SECRET_ACCESS_KEY}}"

    if [[ -n "$create_new_bucket" && "$REMOTE_ENDPOINT" == ${create_new_bucket}* ]]; then
        echo "Debug: REMOTE_ENDPOINT matches condition. Creating new bucket and setting up user."
        minio_cmds+=" && \
        mc mb myminio/${REMOTE_BUCKET_NAME} && \
        mc admin user add myminio ${REMOTE_ACCESS_KEY_ID} ${REMOTE_SECRET_ACCESS_KEY} && \
        mc admin policy attach myminio readwrite --user ${REMOTE_ACCESS_KEY_ID}"
    else
        echo "Debug: REMOTE_ENDPOINT does not match condition or --create-new-bucket not specified. Skipping bucket creation and user setup."
    fi

    if $clear_bucket; then
        echo "Debug: Clearing bucket path: ${REMOTE_PATH}"
        minio_cmds+=" && mc rm -r --force myminio/${REMOTE_BUCKET_NAME}${REMOTE_PATH}"
    fi

    if $interactive; then
        minio_cmds+=" && /bin/sh"
    fi

    echo "Debug: Docker command: $docker_cmd"
    echo "Debug: MinIO commands: $minio_cmds"

    echo "Debug: Executing Docker command..."
    $docker_cmd "$minio_cmds"
    echo "Debug: Docker command execution completed"
}

run_test() {
    local test_dir="$1"
    setup_minio --clear-bucket --create-new-bucket "http://minio:9000" "$test_dir"
    docker-compose --env-file "${PROJECT_ROOT}/vars/test/.env" --env-file "$test_dir/.env" up \
        --abort-on-container-exit \
        --renew-anon-volumes \
        --remove-orphans \
        --force-recreate
}
