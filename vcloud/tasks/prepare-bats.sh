#!/usr/bin/env bash

set -e

: ${BATS_STEMCELL_NAME:?}
: ${VCLOUD_VLAN:?}
: ${VCLOUD_VAPP:?}
: ${NETWORK_CIDR:?}
: ${NETWORK_GATEWAY:?}
: ${BATS_DIRECTOR_IP:?}
: ${BATS_IP1:?}
: ${BATS_IP2:?}
: ${BATS_RESERVED_RANGE1:?}
: ${BATS_RESERVED_RANGE2:?}
: ${BATS_STATIC_RANGE:?}

source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
stemcell_dir=$(realpath stemcell)
bats_dir=$(realpath bats)

echo "using bosh CLI version..."
bosh version
bosh -n target $BATS_DIRECTOR_IP

export BAT_INFRASTRUCTURE=vcloud
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD=c1oudc0w
export BAT_DNS_HOST=$BATS_DIRECTOR_IP
export BAT_DIRECTOR=$BATS_DIRECTOR_IP
export BAT_STEMCELL="${stemcell_dir}/stemcell.tgz"
export BAT_DEPLOYMENT_SPEC="${PWD}/bats-config.yml"

cat > ${BAT_DEPLOYMENT_SPEC} <<EOF
---
cpi: vcloud
properties:
  uuid: $(bosh status --uuid)
  second_static_ip: ${BATS_IP2}
  pool_size: 1
  stemcell:
    name: ${BATS_STEMCELL_NAME}
    version: latest
  instances: 1
  networks:
    - name: static
      static_ip: ${BATS_IP1}
      type: manual
      cidr: ${NETWORK_CIDR}
      reserved:
        - ${BATS_RESERVED_RANGE1}
        - ${BATS_RESERVED_RANGE2}
      static: [${BATS_STATIC_RANGE}]
      gateway: ${NETWORK_GATEWAY}
      vlan: ${VCLOUD_VLAN}
  vapp_name: ${VCLOUD_VAPP}
EOF

ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa
