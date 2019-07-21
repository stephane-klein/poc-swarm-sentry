#!/usr/bin/env bash
set -e

cd $(dirname "$0")

export DOCKER_HOST=ssh://vagrant@infra01.example.com

docker stack deploy -c traefik.yml traefik
