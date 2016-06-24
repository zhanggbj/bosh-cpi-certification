#!/usr/bin/env bash

set -ex

source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
input_dir=$(realpath director-config/)
stemcell_dir=$(realpath stemcell/)
bosh_dir=$(realpath bosh-release/)
cpi_dir=$(realpath cpi-release/)

# outputs
output_dir=$(realpath director-state/)
cp ${input_dir}/* ${output_dir}

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

  cp -r $HOME/.bosh_init ${output_dir}
}
trap finish EXIT

bosh_init=$(realpath bosh-init/bosh-init-*)
chmod +x $bosh_init

echo "using bosh-init CLI version..."
$bosh_init version

pushd ${output_dir} > /dev/null
  echo "deploying BOSH..."
  $bosh_init deploy ./director.yml
popd > /dev/null
