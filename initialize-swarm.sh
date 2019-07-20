#!/usr/bin/env bash
set -e

cd $(dirname "$0")

ssh-keygen -R infra01.example.com
ssh-keygen -R infra02.example.com

ssh-add -k .vagrant/machines/infra01/virtualbox/private_key
ssh-add -k .vagrant/machines/infra02/virtualbox/private_key

ssh-keyscan -H infra01.example.com >> ~/.ssh/known_hosts
ssh-keyscan -H infra02.example.com >> ~/.ssh/known_hosts

export INFRA01_IP=$(ping -c 1 infra01.example.com | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')

docker -H ssh://vagrant@infra01.example.com swarm init --advertise-addr ${INFRA01_IP} >> /dev/null
docker -H ssh://vagrant@infra01.example.com swarm join-token -q worker > swarm-token-worker
docker -H ssh://vagrant@infra02.example.com swarm join --token $(cat swarm-token-worker)  ${INFRA01_IP}:2377

docker node ls