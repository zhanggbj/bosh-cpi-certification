#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
input_dir=$(realpath director-config/)
stemcell_dir=$(realpath stemcell/)
bosh_dir=$(realpath bosh-release/)
cpi_dir=$(realpath cpi-release/)

# outputs
output_dir=$(realpath director-state/)
cp ./director-config/* ${output_dir}

# deployment manifest references releases and stemcells relative to itself...make it true
ln -s ${stemcell_dir} ${output_dir}
ln -s ${bosh_dir} ${output_dir}
ln -s ${cpi_dir} ${output_dir}

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat "${output_dir}/director-state.json"
  echo "=========================================="

  cp -r $HOME/.bosh_init ${output_dir}
  rm ${output_dir}/{stemcell,bosh-release,cpi-release}
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
