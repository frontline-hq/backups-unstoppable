#!/bin/bash

# Check if a directory is provided
if [ $# -eq 0 ]; then
    echo "Please provide a directory path."
    exit 1
fi

# Export required environment variables
export SFTP_HOST_PUBKEY=$(cat "./vars/test/host_id_ed25519.pub")
export SFTP_USER_PRIVKEY=$(cat "./vars/test/user_id_ed25519")

docker build -t rustic-image:latest --build-arg ENV="test" ./src
docker-compose --env-file ./vars/test/.env -f ./test/docker-compose.yaml up \
    --detach \
    --remove-orphans

# Provide information about the running environment
echo "Docker containers are now running in the background."
echo "You have access to the host system shell."
echo "Use 'docker ps' to see running containers."
echo "When you're done, type 'exit' to stop the containers and clean up."
echo

source vars/test/.env
source "$1/.env"
export SFTP_HOST_PUBKEY=$(cat "./vars/test/host_id_ed25519.pub")
export SFTP_USER_PRIVKEY=$(cat "./vars/test/user_id_ed25519")
# create bucket, credentials and policy
docker run --rm --network test-net-external --entrypoint=/bin/sh minio/mc -c "\
    mc alias set myminio http://minio:9000 ${REMOTE_ADMIN_USER} ${REMOTE_ADMIN_PASSWORD} && \
    mc mb myminio/${REMOTE_BUCKET_NAME} && \
    mc admin user add myminio ${REMOTE_ACCESS_KEY_ID} ${REMOTE_SECRET_ACCESS_KEY} && \
    mc admin policy attach myminio readwrite --user ${REMOTE_ACCESS_KEY_ID}
    "
docker-compose --env-file ./vars/test/.env --env-file "$1/.env" run rustic sh
docker-compose down --remove-orphans --volumes

# When the user exits the shell, run the cleanup command
echo "Cleaning up..."
docker-compose -f ./test/docker-compose.yaml down --volumes

echo "Done."