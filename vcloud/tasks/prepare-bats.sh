#!/usr/bin/env bash

set -e

: ${STEMCELL_NAME:?}
: ${BAT_VCAP_PASSWORD:=c1oudc0w}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
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

# outputs
output_dir=$(realpath bats-config)
bats_spec="${output_dir}/bats-config.yml"
bats_env="${output_dir}/bats.env"

echo "using bosh CLI version..."
bosh version
bosh -n target $BATS_DIRECTOR_IP
bosh_uuid="$(bosh status --uuid)"

cat > "${bats_env}" <<EOF
#!/usr/bin/env bash

export BAT_DIRECTOR=${BATS_DIRECTOR_IP}
export BAT_DNS_HOST=${BATS_DIRECTOR_IP}
export BAT_INFRASTRUCTURE=vcloud
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD=${BAT_VCAP_PASSWORD}
export BAT_RSPEC_FLAGS="--tag ~vip_networking --tag ~dynamic_networking --tag ~root_partition --tag ~raw_ephemeral_storage"
export BAT_DIRECTOR_USER="${BOSH_DIRECTOR_USERNAME}"
export BAT_DIRECTOR_PASSWORD="${BOSH_DIRECTOR_PASSWORD}"
EOF

cat > ${bats_spec} <<EOF
---
cpi: vcloud
properties:
  uuid: ${bosh_uuid}
  second_static_ip: ${BATS_IP2}
  pool_size: 1
  stemcell:
    name: ${STEMCELL_NAME}
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
