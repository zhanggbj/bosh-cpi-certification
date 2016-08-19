#!/usr/bin/env bash

set -e -x

: ${DEPLOYMENT_NAME:?}

# inputs
existing_director_config=$(realpath director-config/)
existing_director_state=$(realpath director-state/)
stemcell_dir=$(realpath stemcell/)
bosh_dir=$(realpath bosh-release/)
cpi_dir=$(realpath cpi-release/)
bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

# outputs
output_dir=$(realpath new-director-state/)

source ${existing_director_config}/director.env
: ${BOSH_DIRECTOR_IP:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

cp -r ${existing_director_config}/* ${output_dir}
cp -r ${existing_director_state}/* ${output_dir}

# deployment manifest references releases and stemcells relative to itself...make it true
# these resources are also used in the teardown step
mkdir -p ${output_dir}/{stemcell,bosh-release,cpi-release}
cp ${stemcell_dir}/*.tgz ${output_dir}/stemcell/
cp ${bosh_dir}/*.tgz ${output_dir}/bosh-release/
cp ${cpi_dir}/*.tgz ${output_dir}/cpi-release/

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat "${output_dir}/director-state.json"
  echo "=========================================="

  cp -r $HOME/.bosh ${output_dir}
}
trap finish EXIT

echo "upgrading existing BOSH Director VM..."
pushd ${output_dir} > /dev/null
  time ${bosh_cli} create-env director.yml
popd > /dev/null

time $bosh_cli -n env ${BOSH_DIRECTOR_IP//./-}.sslip.io
time $bosh_cli -n login --user=${BOSH_DIRECTOR_USERNAME} --password=${BOSH_DIRECTOR_PASSWORD}

echo "recreating existing BOSH Deployment..."
time $bosh_cli -n -d ${DEPLOYMENT_NAME} recreate
