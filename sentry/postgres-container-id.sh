#!/usr/bin/env bash
set -e

cd $(dirname "$0")

docker inspect $(docker service ps -q --filter desired-state=running sentry_postgres) --format "{{ .Status.ContainerStatus.ContainerID }}"