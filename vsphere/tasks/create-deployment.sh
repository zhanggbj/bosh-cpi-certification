#!/usr/bin/env bash

set -e -x

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${RELEASE_NAME:?}

env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
deployment_release=$(realpath pipelines/shared/assets/certification-release)

echo "Using environment: \'${env_name}\'"
: ${DIRECTOR_IP:=$(env_attr "${metadata}" "directorIP" )}

time bosh -n target ${DIRECTOR_IP}
time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}

pushd ${deployment_release}
  time bosh -n create release --force --name ${RELEASE_NAME}
  time bosh -n upload release #it's a failure of a precondition for the release to have been uploaded
popd

time bosh -n upload stemcell stemcell/*.tgz  #it's a failure of a precondition for the stemcell to have been uploaded
time bosh deployment deployment-manifest/deployment.yml
time bosh -n deploy
