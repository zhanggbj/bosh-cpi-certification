#!/usr/bin/env bash

set -e

: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# preparation
cp ./director-manifest/director.yml .

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat director-state.json
  echo "=========================================="

  cp director{.yml,-state.json} director-state/
  cp -r $HOME/.bosh_init director-state/
}
trap finish ERR

bosh_init="bosh-init/bosh-init"
chmod +x $bosh_init

echo "using bosh-init CLI version..."
$bosh_init version

echo "deploying BOSH..."
$bosh_init deploy ./director.yml

trap - ERR
finish
