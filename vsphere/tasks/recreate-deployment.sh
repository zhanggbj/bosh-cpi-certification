#!/usr/bin/env bash

set -e -x

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

env_name=$(cat environment/name)
metadata=$(cat environment/metadata)

log "Using environment: \'${env_name}\'"
${DIRECTOR_IP:=$(env_attr "${metadata}" "directorIP" )}

time bosh -n target ${DIRECTOR_IP}
time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}

time bosh deployment deployment-manifest/deployment.yml
time bosh -n deploy --recreate
