# POC Deploy Sentry with Docker Swarm

Start Vagrant Ubuntu VM and install Docker on this servers `infra01.example.com` and `infra02.example.com`:

Note:

- 2 Vagrant servers are created but Sentry is only installed on the first server. The second server created only to test Swarm placement constraints feature


## Prerequisites

- [Docker Engine](https://docs.docker.com/engine/) (tested with `18.09.8-ce`)
- Virtualbox (tested with `6.0.10`)
- Vagrant (tested with `2.2.4`)
- [vagrant-hostmanager](https://github.com/devopsgroup-io/vagrant-hostmanager) plugin (tested with `1.8.9`)

On *macOS* you can install prerequisites with [Brew](https://brew.sh/index_fr):

```sh
$ brew cask install docker vagrant virtualbox
$ vagrant plugin install vagrant-hostmanager --plugin-version 1.8.9
```

## Create VM and Initialize Docker Swarm

```
$ vagrant up
```

Add Vagrant private ssh key to your ssh agent:

```
$ ssh-add -k .vagrant/machines/infra01/virtualbox/private_key
$ ssh-add -k .vagrant/machines/infra02/virtualbox/private_key
```

Check remote docker-engine access via ssh:

```
$ docker -H ssh://vagrant@infra01.example.com info
Containers: 0
 Running: 0
 Paused: 0
...
```

```
$ docker -H ssh://vagrant@infra02.example.com info
Containers: 0
 Running: 0
 Paused: 0
...
```

Initialize Swarm on `infra01`:

```
$ docker -H ssh://vagrant@infra01.example.com swarm init --advertise-addr 172.28.128.19 >> /dev/null
$ docker -H ssh://vagrant@infra01.example.com swarm join-token -q worker > swarm-token-worker
$ docker -H ssh://vagrant@infra02.example.com swarm join --token $(cat swarm-token-worker) 172.28.128.19:2377
```

```
$ docker -H ssh://vagrant@infra01.example.com node ls
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
tldrnrw81ydp9p17klsppfrxy *   infra01             Ready               Active              Leader              18.09.8
485qf00sd1bvdxo634hef3pgt     infra02             Ready               Active                                  18.09.8
```

## Deploy Sentry

First load `DOCKER_HOST` variable env to avoid to use `docker -H...`:

```
$ export DOCKER_HOST=ssh://vagrant@infra01.example.com
```

```
$ docker stack deploy -c sentry/sentry.yml sentry
```

Stop Sentry service because it is fresh installation and database isn't initialized:

```
$ docker service scale sentry_sentry=0 sentry_cron=0 sentry_worker=0
```

```
$ docker stack ls
NAME                SERVICES            ORCHESTRATOR
sentry              5                   Swarm
```

```
$ docker stack ps sentry
ID                  NAME                IMAGE                  NODE                DESIRED STATE       CURRENT STATE              ERROR                              PORTS
btqd9ovhhsw3        sentry_postgres.1   postgres:10.4-alpine   infra01             Running             Running 7 minutes ago
qkuudko6f8hw        sentry_redis.1      redis:4.0-alpine       infra01             Running             Running 7 minutes ago
tqwysleklrsj        sentry_worker.1     sentry:9.1.1                               Shutdown            Pending 14 minutes ago   "no suitable node (scheduling …"
a7vxguruhm42        sentry_postgres.1   postgres:10.4-alpine                       Shutdown            Pending 14 minutes ago   "no suitable node (scheduling …"
skhi2nhmxjwz        sentry_redis.1      redis:4.0-alpine                           Shutdown            Pending 14 minutes ago   "no suitable node (scheduling …"
```

```
$ docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                  PORTS
yk8kpl3cjelb        sentry_cron         replicated          0/0                 sentry:9.1.1
tgn7mbxplzlq        sentry_postgres     replicated          0/1                 postgres:10.4-alpine
b71se6y51hr9        sentry_redis        replicated          0/1                 redis:4.0-alpine
yrv0j8kx95fs        sentry_sentry       replicated          0/0                 sentry:9.1.1
t641ktyu1xye        sentry_worker       replicated          0/0                 sentry:9.1.1
```

Wait images downloading...

```
$ docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                  PORTS
ID                  NAME                MODE                REPLICAS            IMAGE                  PORTS
yk8kpl3cjelb        sentry_cron         replicated          0/0                 sentry:9.1.1
tgn7mbxplzlq        sentry_postgres     replicated          1/1                 postgres:10.4-alpine
b71se6y51hr9        sentry_redis        replicated          1/1                 redis:4.0-alpine
yrv0j8kx95fs        sentry_sentry       replicated          0/0                 sentry:9.1.1
t641ktyu1xye        sentry_worker       replicated          0/0                 sentry:9.1.1
```

Sentry Database initialization:

```
$ cat sentry/init.sql | docker exec -i $(./sentry/postgres-container-id.sh) psql -U sentry sentry
```

Start Sentry:

```
$ docker service scale sentry_sentry=1 sentry_cron=1 sentry_worker=1
```

```
$ docker stack ps sentry
ID                  NAME                IMAGE                  NODE                DESIRED STATE       CURRENT STATE            ERROR                              PORTS
jl8kicsg9y7c        sentry_worker.1     sentry:9.1.1           infra01             Running             Running 18 seconds ago
xfzqeoe3i9zt        sentry_cron.1       sentry:9.1.1           infra01             Running             Running 18 seconds ago
mfbuyluak35w        sentry_sentry.1     sentry:9.1.1           infra01             Running             Running 18 seconds ago                                      *:9000->9000/tcp
btqd9ovhhsw3        sentry_postgres.1   postgres:10.4-alpine   infra01             Running             Running 33 minutes ago
qkuudko6f8hw        sentry_redis.1      redis:4.0-alpine       infra01             Running             Running 33 minutes ago
```

```
$ docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                  PORTS
yk8kpl3cjelb        sentry_cron         replicated          1/1                 sentry:9.1.1
tgn7mbxplzlq        sentry_postgres     replicated          1/1                 postgres:10.4-alpine
b71se6y51hr9        sentry_redis        replicated          1/1                 redis:4.0-alpine
yrv0j8kx95fs        sentry_sentry       replicated          1/1                 sentry:9.1.1
t641ktyu1xye        sentry_worker       replicated          1/1                 sentry:9.1.1
```

```
$ docker exec -it $(./sentry/sentry-container-id.sh) sentry upgrade
09:23:04 [WARNING] sentry.utils.geo: settings.GEOIP_PATH_MMDB not configured.
09:23:08 [INFO] sentry.plugins.github: apps-not-configured
Syncing...
Creating tables ...
Installing custom SQL ...
Installing indexes ...
Installed 0 object(s) from 0 fixture(s)
Migrating...
Running migrations for sentry:
- Nothing to migrate.
...
 - sentry_plugins.jira_ac
Creating missing DSNs
Correcting Group.num_comments counter
```

Configure admin user:

```
$ docker exec -it $(./sentry/sentry-container-id.sh) sentry createuser \
    --email admin@example.com \
    --password password \
    --superuser --no-input > /dev/null
```

Go to http://infra01.example.com:9000/auth/login/sentry/ (`admin@example.com` / `password`)

## Destroy Sentry

```
$ docker stack rm sentry
```

Wait...

```
$ docker stack ps sentry
nothing found in stack: sentry
```

Delete database content:

```
$ docker volume ls
DRIVER              VOLUME NAME
local               sentry_sentry_postgres
$ docker volume rm sentry_sentry_postgres
```
