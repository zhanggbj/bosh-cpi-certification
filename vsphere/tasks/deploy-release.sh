#!/usr/bin/env bash

set -e

: ${delete_deployment_when_done:?}
: ${director_password:?}
: ${director_username:?}
: ${stemcell_name:?}
: ${BOSH_VSPHERE_VCENTER_VLAN:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
stemcell_dir=$(realpath stemcell)
release_dir=$(realpath pipelines/vsphere/assets/certification-release)

env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
echo Using environment: \'${env_name}\'
export DIRECTOR_IP=$(                  env_attr "${metadata}" "directorIP")
export BOSH_VSPHERE_VCENTER_CIDR=$(    env_attr "${network1}" "vCenterCIDR")
export BOSH_VSPHERE_VCENTER_GATEWAY=$( env_attr "${network1}" "vCenterGateway")
export BOSH_VSPHERE_DNS=$(             env_attr "${metadata}" "DNS")
export STATIC_IP=$(                    env_attr "${network1}" "staticIP-1")
export RESERVED_RANGE=$(               env_attr "${network1}" "reservedRange")
export STATIC_RANGE=$(                 env_attr "${network1}" "staticRange")

bosh -n target ${DIRECTOR_IP}
bosh login ${director_username} ${director_password}

cat > deployment.yml <<EOF
---
name: certification
director_uuid: $(bosh status --uuid)

releases:
  - name: certification
    version: latest

compilation:
  reuse_compilation_vms: true
  workers: 1
  network: private
  cloud_properties:
    cpu: 2
    ram: 1024
    disk: 10240

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 3

resource_pools:
  - name: default
    stemcell:
      name: ${stemcell_name}
      version: latest
    network: private
    cloud_properties:
      cpu: 2
      ram: 1024
      disk: 10240

networks:
  - name: private
    type: manual
    subnets:
      - range: ${BOSH_VSPHERE_VCENTER_CIDR}
        gateway: ${BOSH_VSPHERE_VCENTER_GATEWAY}
        dns: [${BOSH_VSPHERE_DNS}]
        cloud_properties: {name: ${BOSH_VSPHERE_VCENTER_VLAN}}
        reserved: [${RESERVED_RANGE}]
        static: [${STATIC_RANGE}]

jobs:
  - name: simple
    template: simple
    instances: 1
    resource_pool: default
    networks:
      - name: private
        default: [dns, gateway]
        static_ips: [${STATIC_IP}]
EOF

pushd $release_dir
  bosh -n create release --force
  bosh -n upload release --skip-if-exists
popd

bosh -n upload stemcell stemcell/stemcell.tgz --skip-if-exists
bosh -d deployment.yml -n deploy

if [ "${delete_deployment_when_done}" = "true" ]; then
  bosh -n delete deployment certification
fi

bosh -n cleanup --all
