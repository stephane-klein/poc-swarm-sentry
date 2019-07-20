# POC Deploy Sentry with Docker Swarm

Start Vagrant Ubuntu VM and install Docker on this servers `infra01.example.com` and `infra02.example.com`:

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