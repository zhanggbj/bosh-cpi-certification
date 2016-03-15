#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

# preparation
input_dir=$(realpath director-config/)
output_dir=$(realpath director-state/)
cp ./director-config/* ${output_dir}

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
