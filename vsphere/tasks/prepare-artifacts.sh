#!/usr/bin/env bash

set -e

cp bosh-cpi-release/*.tgz releases/bosh-cpi-release.tgz
cp bosh-release/*.tgz releases/bosh-release.tgz
cp stemcell/*.tgz stemcells/stemcell.tgz
cp bosh-init/bosh-init* executables/bosh-init
