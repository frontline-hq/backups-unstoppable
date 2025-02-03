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
    docker build -t rustic-image:latest --build-arg ENV="test" ./src
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
        source vars/test/.env
        source $dir/.env
        # create bucket, credentials and policy
        docker run --rm --network test-net-external minio/mc /bin/sh -c "\
            mc alias set myminio http://minio:9000 ${REMOTE_ADMIN_USER} ${REMOTE_ADMIN_PASSWORD} && \
            mc mb myminio/${REMOTE_BUCKET_NAME} && \
            mc admin user add myminio ${REMOTE_ACCESS_KEY_ID} ${REMOTE_SECRET_ACCESS_KEY} && \
            mc admin policy attach myminio readwrite --user ${REMOTE_ACCESS_KEY_ID}"
        bats_test_function --description "Test in ./$(basename $dir): ${TEST_NAME}" \
            -- perform_test $dir
    fi
done