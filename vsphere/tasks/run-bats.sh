#!/usr/bin/env bash

set -e

: ${BAT_STEMCELL_NAME:?}
: ${BAT_VCAP_PASSWORD:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
bats_dir=$(realpath bats)

metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
network2=$(env_attr "${metadata}" "network2")

: ${BAT_DIRECTOR:=$(                      env_attr "${metadata}" "directorIP")}
: ${BAT_DNS_HOST:=$(                      env_attr "${metadata}" "directorIP")}
: ${BAT_VLAN:=$(                          env_attr "${network1}" "vCenterVLAN"}
: ${BAT_STATIC_IP:=$(                     env_attr "${network1}" "staticIP-1")}
: ${BAT_SECOND_STATIC_IP:=$(              env_attr "${network1}" "staticIP-2")}
: ${BAT_CIDR:=$(                          env_attr "${network1}" "vCenterCIDR")}
: ${BAT_RESERVED_RANGE:=$(                env_attr "${network1}" "reservedRange")}
: ${BAT_STATIC_RANGE:=$(                  env_attr "${network1}" "staticRange")}
: ${BAT_GATEWAY:=$(                       env_attr "${network1}" "vCenterGateway")}
: ${BAT_SECOND_NETWORK_VLAN:=$(           env_attr "${network2}" "vCenterVLAN"}
: ${BAT_SECOND_NETWORK_STATIC_IP:=$(      env_attr "${network2}" "staticIP-1")}
: ${BAT_SECOND_NETWORK_CIDR:=$(           env_attr "${network2}" "vCenterCIDR")}
: ${BAT_SECOND_NETWORK_RESERVED_RANGE:=$( env_attr "${network2}" "reservedRange")}
: ${BAT_SECOND_NETWORK_STATIC_RANGE:=$(   env_attr "${network2}" "staticRange")}
: ${BAT_SECOND_NETWORK_GATEWAY:=$(        env_attr "${network2}" "vCenterGateway")}

: ${BAT_STEMCELL:=$(realpath stemcell/stemcell.tgz)}
: ${BAT_DEPLOYMENT_SPEC:="${PWD}/bats-config.yml"}
: ${BAT_INFRASTRUCTURE:=vsphere}
: ${BAT_NETWORKING:=manual}

# vsphere uses user/pass and the cdrom drive, not a reverse ssh tunnel
# the SSH key is required for the `bosh ssh` command to work properly
eval $(ssh-agent)

mkdir -p ${PWD}/keys
ssh_key="${PWD}/keys/bats.pem"
ssh-keygen -N "" -t rsa -b 4096 -f $ssh_key
chmod go-r $ssh_key
ssh-add $ssh_key

echo "using bosh CLI version..."
bosh version

bosh -n target $BAT_DIRECTOR

BOSH_UUID="$(bosh status --uuid)"

# disable host key checking for deployed VMs
mkdir -p $HOME/.ssh

cat > $HOME/.ssh/config << EOF
Host ${BAT_STATIC_IP}
    StrictHostKeyChecking no
Host ${BAT_SECOND_STATIC_IP}
    StrictHostKeyChecking no
EOF

cat > "${BAT_DEPLOYMENT_SPEC}" <<EOF
---
cpi: vsphere
properties:
  uuid: ${BOSH_UUID}
  pool_size: 1
  instances: 1
  second_static_ip: ${BAT_SECOND_STATIC_IP}
  stemcell:
    name: ${BAT_STEMCELL_NAME}
    version: latest
  networks:
    - name: static
      type: manual
      static_ip: ${BAT_STATIC_IP}
      cidr: ${BAT_CIDR}
      reserved: [${BAT_RESERVED_RANGE}]
      static: [${BAT_STATIC_RANGE}]
      gateway: ${BAT_GATEWAY}
      vlan: ${BAT_VLAN}
    - name: second
      type: manual
      static_ip: ${BAT_SECOND_NETWORK_STATIC_IP}
      cidr: ${BAT_SECOND_NETWORK_CIDR}
      reserved: [${BAT_SECOND_NETWORK_RESERVED_RANGE}]
      static: [${BAT_SECOND_NETWORK_STATIC_RANGE}]
      gateway: ${BAT_SECOND_NETWORK_GATEWAY}
      vlan: ${BAT_SECOND_NETWORK_VLAN}
EOF

pushd "${bats_dir}"
  ./write_gemfile
  bundle install
  bundle exec rspec spec
popd
