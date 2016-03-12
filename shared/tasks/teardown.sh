#!/usr/bin/env bash

set -e

source this/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# TODO: make this IaaS-shareable
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${DEPLOYMENT_NAME:?}

# preparation
cp ./director-state/director{.*,-state.json} .
cp -r director-state/.bosh_init $HOME/

# configuration
source director.env
: ${DIRECTOR_IP:=?}

# teardown deployments against BOSH Director
time bosh -n target ${DIRECTOR_IP}
time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}

time bosh -n delete deployment ${DEPLOYMENT_NAME} --force
time bosh -n cleanup --all

# teardown BOSH Director
bosh_init=$(realpath bosh-init/bosh-init-*)
chmod +x $bosh_init

echo "using bosh-init CLI version..."
$bosh_init version

echo "deleting existing BOSH Director VM..."
$bosh_init delete director.yml
