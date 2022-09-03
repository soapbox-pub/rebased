#!/bin/bash

set -e

DATABASE_URL=${DATABASE_URL:-"postgres://${DB_USER:-postgres}:${DB_PASS:-postgres}@${DB_HOST:-db}:5432/${DB_NAME:-postgres}"}

echo "-- Waiting for database..."
while ! pg_isready -d $DATABASE_URL -t 1; do
    sleep 1s
done

echo "-- Running migrations..."
$HOME/bin/pleroma_ctl migrate

echo "-- Starting!"
exec $HOME/bin/pleroma start
