#!/usr/bin/env bash

set -e -x

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.2

: ${director_username:?must be set}
: ${director_password:?must be set}

cpi_release_name="bosh-vsphere-cpi"

env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")

log "Using environment: \'${env_name}\'"
export DIRECTOR_IP=$(env_attr "${metadata}" "directorIP")

time cp ./bosh-cpi-release/*.tgz cpi-release.tgz
time cp ./bosh-release/*.tgz bosh-release.tgz
time cp ./stemcell/*.tgz stemcell.tgz
time cp ./deployment/director-manifest* .

bosh_init=$(echo ${PWD}/bosh-init/bosh-init-*)
chmod +x ${bosh_init}

log "using bosh-init CLI version..."
${bosh_init} version

log "upgrading existing BOSH Director VM..."
time ${bosh_init} deploy director-manifest.yml

time cp director-manifest* $deployment_dir
time cp -r $HOME/.bosh_init $deployment_dir

time bosh -n target ${DIRECTOR_IP}
time bosh login ${director_username} ${director_password}
time bosh download manifest certification deployment.yml
time bosh deployment deployment.yml

log "recreating existing BOSH Deployment..."
time bosh -n deploy --recreate

log "deleting deployment..."
time bosh -n delete deployment certification

log "cleaning up director..."
time bosh -n cleanup --all
