#!/usr/bin/env bash

set -e

: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

source this/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# preparation
cp ./director-config/* .

shared_key="shared.pem"
chmod go-r ${shared_key}
eval $(ssh-agent)
ssh-add ${shared_key}

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat director-state.json
  echo "=========================================="

  cp director{.*,-state.json} ${shared_key} director-state/
  cp -r $HOME/.bosh_init director-state/
}
trap finish ERR

bosh_init=$(realpath bosh-init/bosh-init-*)
chmod +x $bosh_init

echo "using bosh-init CLI version..."
$bosh_init version

echo "deploying BOSH..."
$bosh_init deploy ./director.yml

trap - ERR
finish
