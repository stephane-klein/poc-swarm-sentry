#!/usr/bin/env bash
set -e

cd $(dirname "$0")


    pg_dump -U admin_spacefill -h spacefill-production.cwlralkfkokc.eu-west-3.rds.amazonaws.com -p 5432 --no-owner --no-privileges --inserts -f /export/prod.sql spacefill

export DOCKER_HOST=ssh://vagrant@infra01.example.com

docker exec -i $(./postgres-container-id.sh) pg_dump -U sentry --no-owner --no-privileges --inserts sentry > dump.sql