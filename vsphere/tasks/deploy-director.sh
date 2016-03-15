#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# preparation
output_dir=$(realpath director-state/)
state_file=$(realpath director-state/director-state.json)
shared_key="$(realpath director-state/shared.pem)"
if [ -e "${shared_key}" ]; then
  chmod go-r ${shared_key}
  eval $(ssh-agent)
  ssh-add ${shared_key}
fi

cp ./director-manifest/director.yml ${output_dir}
cp ./director-manifest/director.env ${output_dir}

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat $state_file
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
