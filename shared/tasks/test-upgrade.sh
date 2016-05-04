#!/usr/bin/env bash

set -e -x

source /etc/profile.d/chruby.sh
chruby 2.1.7

: ${DEPLOYMENT_NAME:?}

# inputs
existing_director_config=$(realpath director-config/)
existing_director_state=$(realpath director-state/)
stemcell_dir=$(realpath stemcell/)
bosh_dir=$(realpath bosh-release/)
cpi_dir=$(realpath cpi-release/)

# outputs
output_dir=$(realpath new-director-state/)

source ${existing_director_config}/director.env
: ${BOSH_DIRECTOR_IP:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

cp ${existing_director_config}/* ${output_dir}
cp ${existing_director_state}/* ${output_dir}

# deployment manifest references releases and stemcells relative to itself...make it true
# these resources are also used in the teardown step
mkdir -p ${output_dir}/{stemcell,bosh-release,cpi-release}
cp ${stemcell_dir}/*.tgz ${output_dir}/stemcell/
cp ${bosh_dir}/*.tgz ${output_dir}/bosh-release/
cp ${cpi_dir}/*.tgz ${output_dir}/cpi-release/

bosh_init=$(realpath bosh-init/bosh-init-*)
chmod +x ${bosh_init}

echo "using bosh-init CLI version..."
${bosh_init} version

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat "${output_dir}/director-state.json"
  echo "=========================================="

  cp -r $HOME/.bosh_init ${output_dir}
}
trap finish EXIT

echo "upgrading existing BOSH Director VM..."
pushd ${output_dir} > /dev/null
  time ${bosh_init} deploy director.yml
popd > /dev/null

time bosh -n target ${BOSH_DIRECTOR_IP}
time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}
time bosh download manifest ${DEPLOYMENT_NAME} ${DEPLOYMENT_NAME}-manifest
time bosh deployment ${DEPLOYMENT_NAME}-manifest

echo "recreating existing BOSH Deployment..."
time bosh -n deploy --recreate
