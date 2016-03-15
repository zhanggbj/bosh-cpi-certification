#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# preparation
cp -r director-state/.bosh_init $HOME/
bosh_init=$(realpath bosh-init/bosh-init-*)
chmod +x $bosh_init

echo "using bosh CLI version..."
bosh -v

echo "using bosh-init CLI version..."
$bosh_init version

pushd director-state > /dev/null
  # configuration
  source director.env
  : ${BOSH_DIRECTOR_IP:?}
  : ${BOSH_DIRECTOR_USERNAME:?}
  : ${BOSH_DIRECTOR_PASSWORD:?}

  # teardown deployments against BOSH Director
  time bosh -n target ${BOSH_DIRECTOR_IP}
  time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}

  if [ -n "${DEPLOYMENT_NAME}" ]; then
    time bosh -n delete deployment ${DEPLOYMENT_NAME} --force
  fi
  time bosh -n cleanup --all

  echo "deleting existing BOSH Director VM..."
  $bosh_init delete director.yml
popd
