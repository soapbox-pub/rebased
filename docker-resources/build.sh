#!/bin/sh

docker compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g) pleroma
docker compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g) db

