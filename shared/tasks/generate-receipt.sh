#!/usr/bin/env bash

set -e

: ${CPI_RELEASE_NAME:?}
: ${STEMCELL_NAME:?}

BOSH_RELEASE_VERSION=$(cat bosh-release/version)
CPI_RELEASE_VERSION=$(cat cpi-release/version)
STEMCELL_VERSION=$(cat stemcell/version)

timestamp=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
contents_hash=$(echo bosh-${BOSH_RELEASE_VERSION}-${CPI_RELEASE_NAME}-${CPI_RELEASE_VERSION}-${stemcell_name}-${STEMCELL_VERSION} | md5sum | cut -f1 -d ' ')

certify-artifacts                                   \
  --release bosh/$BOSH_RELEASE_VERSION              \
  --release $CPI_RELEASE_NAME/$CPI_RELEASE_VERSION  \
  --stemcell $STEMCELL_NAME/$STEMCELL_VERSION       \
  > certification-receipt/${timestamp}-${contents_hash}-receipt.json
