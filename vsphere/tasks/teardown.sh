#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${DEPLOYMENT_NAME:?}

# preparation
cp ./director-state/director{.yml,-state.json} .
cp -r director-state/.bosh_init $HOME/

env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")

log "Using environment: \'${env_name}\'"
${DIRECTOR_IP:=$(env_attr "${metadata}" "directorIP" )}

# teardown deployments against BOSH Director
time bosh -n target ${DIRECTOR_IP}
time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}

time bosh -n delete deployment ${DEPLOYMENT_NAME} --force
time bosh -n cleanup --all

# teardown BOSH Director
bosh_init="bosh-init/bosh-init"
chmod +x $bosh_init

echo "using bosh-init CLI version..."
$bosh_init version

echo "deleting existing BOSH Director VM..."
$bosh_init delete director.yml
