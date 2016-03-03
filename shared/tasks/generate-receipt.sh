#!/usr/bin/env bash

set -e

: ${cpi_release_name:?must be set}
: ${stemcell_name:?must be set}

timestamp=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
bosh_release_version=$(cat bosh-release/version)
cpi_release_version=$(cat bosh-cpi-release/version)
stemcell_version=$(cat stemcell/version)

contents_hash=$(echo bosh-${bosh_release_version}-${cpi_release_name}-${cpi_release_version}-${stemcell_name}-${stemcell_version} | md5sum | cut -f1 -d ' ')

certify-artifacts --release bosh/$bosh_release_version \
                  --release $cpi_release_name/$cpi_release_version \
                  --stemcell $stemcell_name/$stemcell_version \
                  > certification-receipt/${timestamp}-${contents_hash}-receipt.json
