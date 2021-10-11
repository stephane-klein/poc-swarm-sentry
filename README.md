# POC Deploy Sentry with Docker Swarm

Start Vagrant Ubuntu VM and install Docker on this servers `infra01.example.com` and `infra02.example.com`:

Notes:

- 2 Vagrant servers are created but Sentry is only installed on the first server. The second server created only to test Swarm placement constraints feature
- `configs` in docker-compose don't work without Docker Swarm

Roadmap:

- [x] Initialize Docker Swarm in Vagrant
- [x] Deploy Sentry
- [x] Destroy Sentry
- [ ] Upgrade Sentry
- [x] Deploy Traefik 

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

## Short version

Create VM: 

```bash
vagrant up
```

### Initialize Docker Swarm:

```bash
./initialize-swarm.sh
```
```
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
sr9cxlye7h4pgm2a0r2aujrc1 *   infra01             Ready               Active              Leader              18.09.8
4ae6vhc5gcukzk3g8hkon1znd     infra02             Ready               Active                                  18.09.8
```

### Deploy Traefik:

```bash
./traefik/deploy.sh
```

### First deployment:

```
./sentry/first-deployment.sh
```

Go to http://infra01.example.com:9000/auth/login/sentry/ (`admin@example.com` / `password`)


## Long version

### Create VM and Initialize Docker Swarm

```
vagrant up
```

### Add Vagrant private ssh key to your ssh agent:

```bash
ssh-add -k .vagrant/machines/infra01/virtualbox/private_key
ssh-add -k .vagrant/machines/infra02/virtualbox/private_key
ssh-keygen -R infra02
ssh-keygen -R infra02.example.com
ssh-keygen -R infra01
ssh-keygen -R infra01.example.com
ssh-keyscan infra01 infra01.example.com infra02 infra02.example.com >> ~/.ssh/known_hosts
```

### Check remote docker-engine access via ssh:

```bash
docker -H ssh://vagrant@infra01.example.com info
```
```
Containers: 0
 Running: 0
 Paused: 0
...
```

```bash
docker -H ssh://vagrant@infra02.example.com info
```
```
Containers: 0
 Running: 0
 Paused: 0
...
```
### Get the IP addresses from both VM's
```bash
export INFRA01_IP=$(ping -c 1 infra01.example.com | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')
export INFRA02_IP=$(ping -c 1 infra02.example.com | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')

```
### Initialize Swarm on `infra01` and join `infra02` to the cluster:

```bash
docker -H ssh://vagrant@infra01.example.com swarm init --advertise-addr $INFRA01_IP >> /dev/null
docker -H ssh://vagrant@infra01.example.com swarm join-token -q worker > swarm-token-worker
docker -H ssh://vagrant@infra02.example.com swarm join --token $(cat swarm-token-worker) $INFRA01_IP:2377
```

```bash
docker -H ssh://vagrant@infra01.example.com node ls
```
```
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
ep00nuf9qlzn2ip63w73vupbx *   infra01    Ready     Active         Leader           20.10.9
1oy2sfv0f393zzj1ohz08kcao     infra02    Ready     Active                          20.10.9

```

### Deploy Traefik

```bash
./traefik/deploy.sh
```

### Deploy Sentry

First load `DOCKER_HOST` variable env to avoid to use `docker -H...`:

```bash
export DOCKER_HOST=ssh://vagrant@infra01.example.com
```

### Then deploy the sentry stack

```bash
docker stack deploy -c sentry/sentry.yml sentry
```

### Stop Sentry service because it is fresh installation and database isn't initialized:

```bash
docker service scale sentry_sentry=0 sentry_cron=0 sentry_worker=0
```

```bash
docker stack ls
```
```
NAME      SERVICES   ORCHESTRATOR
sentry    5          Swarm
traefik   1          Swarm
```

```bash
docker stack ps sentry
```
```
ID             NAME                IMAGE                  NODE      DESIRED STATE   CURRENT STATE                ERROR     PORTS
kaffi4dswgoc   sentry_postgres.1   postgres:10.4-alpine   infra01   Running         Running about a minute ago             
p6ivf81mu3hk   sentry_redis.1      redis:4.0-alpine       infra01   Running         Running about a minute ago 
```

```bash
docker service ls
```
```
ID             NAME              MODE         REPLICAS   IMAGE                   PORTS
6omti7eew58c   sentry_cron       replicated   0/0        sentry:9.1.1            
37k1sawud7d2   sentry_postgres   replicated   1/1        postgres:10.4-alpine    
c9cv5hi4rtyn   sentry_redis      replicated   1/1        redis:4.0-alpine        
il4qrvuq3q1d   sentry_sentry     replicated   0/0        sentry:9.1.1            
ukrcfahf5igh   sentry_worker     replicated   0/0        sentry:9.1.1            
plgt5n3gy1qs   traefik_traefik   replicated   1/1        traefik:1.7.12-alpine   
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

```bash
cat sentry/init.sql | docker exec -i $(./sentry/postgres-container-id.sh) psql -U sentry sentry
```

Start Sentry:

```
docker service scale sentry_sentry=1 sentry_cron=1 sentry_worker=1
```

```bash
docker stack ps sentry
```
```
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

```bash
docker exec -it $(./sentry/sentry-container-id.sh) sentry upgrade
```
```
13:31:21 [WARNING] sentry.utils.geo: settings.GEOIP_PATH_MMDB not configured.
...
Migrated:
 - sentry
 - sentry.nodestore
 - sentry.search
 - social_auth
 - sentry.tagstore
 - sentry_plugins.hipchat_ac
 - sentry_plugins.jira_ac
Creating missing DSNs
Correcting Group.num_comments counter

```

### Configure admin user:

```
docker exec -it $(./sentry/sentry-container-id.sh) sentry createuser \
    --email admin@example.com \
    --password password \
    --superuser --no-input > /dev/null
```

Go to http://sentry.example.com (`admin@example.com` / `password`)

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
