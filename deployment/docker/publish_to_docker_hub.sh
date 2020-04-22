#!/bin/bash

DIR=$(dirname $0)
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
docker-compose -f ${DIR}/docker-compose-build.prod.yaml push