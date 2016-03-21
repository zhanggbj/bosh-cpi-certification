#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
input_dir=$(realpath director-state/)
stemcell_dir=$(realpath stemcell/)
bosh_dir=$(realpath bosh-release/)
cpi_dir=$(realpath cpi-release/)

# deployment manifest references releases and stemcells relative to itself...make it true
ln -s ${stemcell_dir} ${input_dir}
ln -s ${bosh_dir} ${input_dir}
ln -s ${cpi_dir} ${input_dir}

cp -r ${input_dir}/.bosh_init $HOME/
bosh_init=$(realpath bosh-init/bosh-init-*)
chmod +x $bosh_init

echo "using bosh CLI version..."
bosh -v

echo "using bosh-init CLI version..."
$bosh_init version

pushd ${input_dir} > /dev/null
  # configuration
  source director.env
  : ${BOSH_DIRECTOR_IP:?}
  : ${BOSH_DIRECTOR_USERNAME:?}
  : ${BOSH_DIRECTOR_PASSWORD:?}

  # Don't exit on failure to target the BOSH director
  set +e
    # teardown deployments against BOSH Director
    time bosh -n target ${BOSH_DIRECTOR_IP}
    time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}

    if [ -n "${DEPLOYMENT_NAME}" ]; then
      time bosh -n delete deployment ${DEPLOYMENT_NAME} --force
    fi
    time bosh -n cleanup --all
  set -e

  echo "deleting existing BOSH Director VM..."
  $bosh_init delete director.yml
popd
