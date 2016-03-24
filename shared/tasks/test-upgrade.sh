#!/usr/bin/env bash

set -e -x

source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
: ${DEPLOYMENT_NAME:?}

director_config=$(realpath new-director-config/)
director_state=$(realpath director-state/)
source ${director_config}/director.env
: ${BOSH_DIRECTOR_IP:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

# outputs
output_dir=$(realpath new-director-state/)

cp ${director_config}/director.yml .
cp ${director_state}/director-state.json .

initver=$(cat bosh-init/version)
initexe="bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x ${initexe}

echo "using bosh-init CLI version..."
$initexe version

echo "upgrading existing BOSH Director VM..."
time $initexe deploy director.yml

time cp ${director_config}/director.env ${output_dir}
time cp director{.yml,-state.json} ${output_dir}
time cp -r $HOME/.bosh_init ${output_dir}

time bosh -n target ${BOSH_DIRECTOR_IP}
time bosh login ${BOSH_DIRECTOR_USERNAME} ${BOSH_DIRECTOR_PASSWORD}
time bosh download manifest ${DEPLOYMENT_NAME} ${DEPLOYMENT_NAME}-manifest
time bosh deployment ${DEPLOYMENT_NAME}-manifest

echo "recreating existing BOSH Deployment..."
time bosh -n deploy --recreate
