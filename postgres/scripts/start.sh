#!/bin/bash

set -eu
set -o pipefail

cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ..

. scripts/vars.sh

scripts/stop.sh

echo "==============================================================================="
echo "Starting Postgres container with the following parameters"
echo "-------------------------------------------------------------------------------"
echo "POSTGRES_VERSION: ${POSTGRES_VERSION}"
echo "POSTGRES_CONTAINER_NAME: ${POSTGRES_CONTAINER_NAME}"
echo "POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}"
echo "POSTGRES_DATABASE: ${POSTGRES_DATABASE}"
echo "POSTGRES_SHARED_MEMORY: ${POSTGRES_SHARED_MEMORY}"
echo "POSTGRES_USER: ${POSTGRES_USER}"
echo "POSTGRES_CSV_DIR (on the host machine):"
echo "  ${POSTGRES_CSV_DIR}"
echo "==============================================================================="

if [ ! -d ${POSTGRES_CSV_DIR} ]; then
    echo "Directory ${POSTGRES_CSV_DIR} does not exist."
    exit 1
fi

export UMBRA_CONTAINER_NAME=snb-umbra

# TODO: scratch dir

# start the container
docker run --rm \
    --publish=5432:5432 \
    --name ${UMBRA_CONTAINER_NAME} \
    --env POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    --volume=${POSTGRES_CSV_DIR}:/data \
    --volume=/home/szarnyasg/git/snb/lsqb/umb/scratch:/scratch \
    --detach \
    umbra-fedora

docker exec \
    --interactive \
    ${UMBRA_CONTAINER_NAME} \
    /umbra/bin/sql \
    --createdb /scratch/ldbc.db \
    /scratch/create-role.sql

docker exec \
    --detach \
    ${UMBRA_CONTAINER_NAME} \
    /umbra/bin/server \
    -address 0.0.0.0 /scratch/ldbc.db

echo -n "Waiting for the database to start ."
until python3 scripts/test-db-connection.py > /dev/null 2>&1; do
    echo -n " ."
    sleep 1
done
echo
echo "Database started"
