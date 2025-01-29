#!/usr/bin/env bats

# Helper function to perform the test
perform_test() {
    local test_dir="$1"
    export SFTP_HOST_PUBKEY=$(cat "./vars/test/host_id_ed25519.pub")
    export SFTP_USER_PRIVKEY=$(cat "./vars/test/user_id_ed25519")
    docker-compose --env-file ./vars/test/.env --env-file "$test_dir/.env" up \
        --abort-on-container-exit \
        --renew-anon-volumes \
        --remove-orphans
}

setup_file() {
    docker build -t rustic-image:latest ./src
    docker-compose --env-file ./vars/test/.env -f ./test/docker-compose.yaml up \
        --detach \
        --remove-orphans
}

teardown_file() {
    docker-compose -f ./test/docker-compose.yaml down --volumes
}


# Dynamically register tests for each subdirectory in /vars/test
for dir in ./vars/test/*; do
    if [ -d "$dir" ]; then
        bats_test_function --description "Basic docker-compose for $(basename $dir)" \
            -- perform_test $dir
    fi
done