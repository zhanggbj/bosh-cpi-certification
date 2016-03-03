#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
bosh_release_dir=$(realpath bosh-release)
cpi_release_dir=$(realpath bosh-cpi-release)
stemcell_dir=$(realpath stemcell)
bosh_init_dir=$(realpath bosh-init)
deployment_dir=$(realpath deployment)

cp ${bosh_release_dir}/*.tgz ./bosh-release.tgz
cp ${cpi_release_dir}/*.tgz ./cpi-release.tgz
cp ${stemcell_dir}/*.tgz ./stemcell.tgz

cp $deployment_dir/director{.yml,-state.json} ./
cp -r $deployment_dir/.bosh_init $HOME/

bosh_init=$(echo ${bosh_init_dir}/bosh-init-*)
chmod +x $bosh_init

echo "using bosh-init CLI version..."
$bosh_init version

echo "deleting existing BOSH Director VM..."
$bosh_init delete director.yml
