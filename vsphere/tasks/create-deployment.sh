#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh

: ${BOSH_CLIENT:?}
: ${BOSH_CLIENT_SECRET:?}
: ${RELEASE_NAME:?}
: ${DEPLOYMENT_NAME:?}

# inputs
env_name=$(cat environment/name)
stemcell_dir=$(realpath stemcell)
manifest_dir=$(realpath deployment-manifest)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
deployment_release=$(realpath pipelines/shared/assets/certification-release)
bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

echo "Using environment: \'${env_name}\'"
: ${DIRECTOR_IP:=$(env_attr "${metadata}" "directorIP" )}

export BOSH_ENVIRONMENT="${DIRECTOR_IP//./-}.sslip.io"

pushd ${deployment_release}
  time $bosh_cli -n create-release --force --name ${RELEASE_NAME}
  time $bosh_cli -n upload-release
popd

time $bosh_cli -n upload-stemcell ${stemcell_dir}/*.tgz
time $bosh_cli -n deploy -d ${DEPLOYMENT_NAME} ${manifest_dir}/deployment.yml
