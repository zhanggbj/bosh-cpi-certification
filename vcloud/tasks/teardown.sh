#!/usr/bin/env bash

set -e

: ${VCLOUD_HOST:?}
: ${VCLOUD_USER:?}
: ${VCLOUD_PASSWORD:?}
: ${VCLOUD_ORG:?}
: ${VCLOUD_VDC:?}
: ${VCLOUD_CATALOG:?}

source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
cpi_release_dir=$(realpath bosh-cpi-release)
bosh_init_dir=$(realpath bosh-init)
director_state_dir=$(realpath director-state)

bosh_init=$(echo ${bosh_init_dir}/bosh-init-*)
chmod +x $bosh_init

cpi_tarball=$(echo ${cpi_release_dir}/*.tgz)

# outputs
deployment_dir="$(realpath deployment)"

cat > "${deployment_dir}/director.yml" <<EOF
---
name: bats-director

releases:
  - name: bosh-vcloud-cpi
    url: file://${cpi_tarball}

resource_pools: {}
disk_pools: {}
networks: {}
jobs: {}

cloud_provider:
  template: {name: vcloud_cpi, release: bosh-vcloud-cpi}

  properties:
  nats:
    address: 127.0.0.1
    user: nats
    password: nats-password
  vcd:
    url: ${VCLOUD_HOST}
    user: ${VCLOUD_USER}
    password: ${VCLOUD_PASSWORD}
    entities:
      organization: ${VCLOUD_ORG}
      virtual_datacenter: ${VCLOUD_VDC}
      vapp_catalog: ${VCLOUD_CATALOG}
      media_catalog: ${VCLOUD_CATALOG}
      media_storage_profile: '*'
      vm_metadata_key: vm-metadata-key
    control: {wait_max: 900}
  blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
EOF

echo "deleting existing BOSH Director VM..."
cp ${director_state_dir}/director-state.json ${deployment_dir}/director-state.json
$bosh_init delete ${deployment_dir}/director.yml

echo "resetting BOSH director state"
echo "{}" > ${deployment_dir}/director-state.json
