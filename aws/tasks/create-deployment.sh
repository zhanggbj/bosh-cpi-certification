#!/usr/bin/env bash

set -e -x

source pipelines/shared/utils.sh
source pipelines/aws/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${RELEASE_NAME:?}
: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

# configuration
: ${DIRECTOR_IP:=$( stack_info "DirectorEIP" )}
deployment_release=$(realpath pipelines/shared/assets/certification-release)

time bosh -n target ${DIRECTOR_IP}
time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}

pushd ${deployment_release}
  time bosh -n create release --force --name ${RELEASE_NAME}
  time bosh -n upload release #it's a failure of a precondition for the release to have been uploaded
popd

time bosh -n upload stemcell stemcell/*.tgz  #it's a failure of a precondition for the stemcell to have been uploaded
time bosh deployment deployment-manifest/deployment.yml
time bosh -n deploy
