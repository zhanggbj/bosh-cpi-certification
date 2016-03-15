#!/usr/bin/env bash

set -e

: ${BAT_STEMCELL_NAME:?}
: ${BAT_VCAP_PASSWORD:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# outputs
output_dir=$(realpath bats-config)
bats_spec="${output_dir}/bats-config.yml"
bats_env="${output_dir}/bats.env"

# inputs
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
network2=$(env_attr "${metadata}" "network2")

: ${BAT_VLAN:=$(                          env_attr "${network1}" "vCenterVLAN")}
: ${BAT_STATIC_IP:=$(                     env_attr "${network1}" "staticIP-1")}
: ${BAT_SECOND_STATIC_IP:=$(              env_attr "${network1}" "staticIP-2")}
: ${BAT_CIDR:=$(                          env_attr "${network1}" "vCenterCIDR")}
: ${BAT_RESERVED_RANGE:=$(                env_attr "${network1}" "reservedRange")}
: ${BAT_STATIC_RANGE:=$(                  env_attr "${network1}" "staticRange")}
: ${BAT_GATEWAY:=$(                       env_attr "${network1}" "vCenterGateway")}
: ${BAT_SECOND_NETWORK_VLAN:=$(           env_attr "${network2}" "vCenterVLAN")}
: ${BAT_SECOND_NETWORK_STATIC_IP:=$(      env_attr "${network2}" "staticIP-1")}
: ${BAT_SECOND_NETWORK_CIDR:=$(           env_attr "${network2}" "vCenterCIDR")}
: ${BAT_SECOND_NETWORK_RESERVED_RANGE:=$( env_attr "${network2}" "reservedRange")}
: ${BAT_SECOND_NETWORK_STATIC_RANGE:=$(   env_attr "${network2}" "staticRange")}
: ${BAT_SECOND_NETWORK_GATEWAY:=$(        env_attr "${network2}" "vCenterGateway")}

# Exported variables are required by bats
director_ip=$(env_attr "${metadata}" "directorIP")
export BAT_INFRASTRUCTURE=vsphere
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD

# env file generation
cat > "${bats_env}" <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${director_ip}
export BAT_DNS_HOST=${director_ip}
export BAT_INFRASTRUCTURE=vsphere
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
EOF

# vsphere uses user/pass and the cdrom drive, not a reverse ssh tunnel
# the SSH key is required for the `bosh ssh` command to work properly
ssh_key="$output_dir/shared.pem"
ssh-keygen -N "" -t rsa -b 4096 -f $ssh_key

echo "using bosh CLI version..."
bosh version

bosh -n target $BAT_DIRECTOR

BOSH_UUID="$(bosh status --uuid)"

cat > "${bats_spec}" <<EOF
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
