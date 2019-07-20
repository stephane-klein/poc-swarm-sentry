#!/usr/bin/env bash
set -e

cd $(dirname "$0")

export DOCKER_HOST=ssh://vagrant@infra01.example.com

docker stack deploy -c sentry.yml sentry
docker service scale sentry_sentry=0 sentry_cron=0 sentry_worker=0

until docker service ps --filter desired-state=running sentry_postgres 2>&1 >> /dev/null
do
    echo "wait sentry_postgres up..."
    sleep 1
done

cat init.sql | docker exec -i $(./postgres-container-id.sh) psql -U sentry sentry

docker service scale sentry_sentry=1 sentry_cron=1 sentry_worker=1

until docker service ps --filter desired-state=running sentry_sentry 2>&1 >> /dev/null
do
    echo "wait sentry_sentry up..."
    sleep 1
done

docker exec -it $(./sentry-container-id.sh) sentry upgrade --noinput

docker exec -it $(./sentry-container-id.sh) sentry createuser \
    --email admin@example.com \
    --password password \
    --superuser --no-input > /dev/null