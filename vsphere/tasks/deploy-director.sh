#!/usr/bin/env bash

set -e

: ${BOSH_INIT_LOG_LEVEL:?}
: ${BOSH_VSPHERE_VCENTER:?}
: ${BOSH_VSPHERE_VCENTER_USER:?}
: ${BOSH_VSPHERE_VCENTER_PASSWORD:?}
: ${BOSH_VSPHERE_VERSION:?}
: ${BOSH_VSPHERE_VCENTER_DC:?}
: ${BOSH_VSPHERE_VCENTER_CLUSTER:?}
: ${BOSH_VSPHERE_VCENTER_VM_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER:?}
: ${BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN:?}
: ${BOSH_VSPHERE_VCENTER_DISK_PATH:?}
: ${BOSH_VSPHERE_VCENTER_VLAN:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# inputs
bosh_release_dir=$(realpath bosh-release)
cpi_release_dir=$(realpath bosh-cpi-release)
stemcell_dir=$(realpath stemcell)
bosh_init_dir=$(realpath bosh-init)

env_name=$(cat environment/name)
metadata=$(cat environment/metadata)
network1=$(env_attr "${metadata}" "network1")
echo Using environment: \'${env_name}\'
export DIRECTOR_IP=$(                  env_attr "${metadata}" "directorIP")
export BOSH_VSPHERE_VCENTER_CIDR=$(    env_attr "${network1}" "vCenterCIDR")
export BOSH_VSPHERE_VCENTER_GATEWAY=$( env_attr "${network1}" "vCenterGateway")
export BOSH_VSPHERE_DNS=$(             env_attr "${metadata}" "DNS")

echo "verifying no BOSH deployed VM exists at target IP: $DIRECTOR_IP"
check_for_rogue_vm $DIRECTOR_IP

# # TODO... (govc, rbvmomi, other?)
# echo "verifying target vSphere version matches $BOSH_VSPHERE_VERSION"
# pushd ${release_dir}/src/vsphere_cpi
#   bundle install
#   bundle exec rspec spec/integration/bats_env_spec.rb
# popd

cp ${bosh_release_dir}/*.tgz ./bosh-release.tgz
cp ${cpi_release_dir}/*.tgz ./cpi-release.tgz
cp ${stemcell_dir}/*.tgz ./stemcell.tgz

# outputs
deployment_dir="$(realpath deployment)"

cat > "./director.yml" <<EOF
---
name: certification-director

releases:
  - name: bosh
    url: file://bosh-release.tgz
  - name: bosh-vsphere-cpi
    url: file://cpi-release.tgz

resource_pools:
  - name: vms
    network: private
    stemcell:
      url: file://stemcell.tgz
    cloud_properties:
      cpu: 2
      ram: 4_096
      disk: 20_000

disk_pools:
  - name: disks
    disk_size: 20_000

networks:
  - name: private
    type: manual
    subnets:
      - range: ${BOSH_VSPHERE_VCENTER_CIDR}
        gateway: ${BOSH_VSPHERE_VCENTER_GATEWAY}
        dns: [${BOSH_VSPHERE_DNS}]
        cloud_properties: {name: ${BOSH_VSPHERE_VCENTER_VLAN}}

jobs:
  - name: bosh
    instances: 1

    templates:
      - {name: nats, release: bosh}
      - {name: redis, release: bosh}
      - {name: postgres, release: bosh}
      - {name: blobstore, release: bosh}
      - {name: director, release: bosh}
      - {name: health_monitor, release: bosh}
      - {name: powerdns, release: bosh}
      - {name: vsphere_cpi, release: bosh-vsphere-cpi}

    resource_pool: vms
    persistent_disk_pool: disks

    networks:
      - {name: private, static_ips: [${DIRECTOR_IP}]}

    properties:
      nats:
        address: 127.0.0.1
        user: nats
        password: nats-password

      redis:
        listen_addresss: 127.0.0.1
        address: 127.0.0.1
        password: redis-password

      postgres: &db
        host: 127.0.0.1
        user: postgres
        password: postgres-password
        database: bosh
        adapter: postgres

      blobstore:
        address: ${DIRECTOR_IP}
        port: 25250
        provider: dav
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}

      director:
        address: 127.0.0.1
        name: certification-director
        db: *db
        cpi_job: vsphere_cpi
        user_management:
          provider: local
          local:
            users:
              - {name: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}
        resurrector_enabled: true

      agent: {mbus: "nats://nats:nats-password@${DIRECTOR_IP}:4222"}

      dns:
        address: 127.0.0.1
        db: *db

      vcenter: &vcenter
        address: ${BOSH_VSPHERE_VCENTER}
        user: ${BOSH_VSPHERE_VCENTER_USER}
        password: ${BOSH_VSPHERE_VCENTER_PASSWORD}
        datacenters:
          - name: ${BOSH_VSPHERE_VCENTER_DC}
            vm_folder: ${BOSH_VSPHERE_VCENTER_VM_FOLDER}
            template_folder: ${BOSH_VSPHERE_VCENTER_TEMPLATE_FOLDER}
            datastore_pattern: ${BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN}
            persistent_datastore_pattern: ${BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN}
            disk_path: ${BOSH_VSPHERE_VCENTER_DISK_PATH}
            clusters: [${BOSH_VSPHERE_VCENTER_CLUSTER}]

cloud_provider:
  template: {name: vsphere_cpi, release: bosh-vsphere-cpi}

  mbus: "https://mbus:mbus-password@${DIRECTOR_IP}:6868"

  properties:
    vcenter: *vcenter
    agent: {mbus: "https://mbus:mbus-password@0.0.0.0:6868"}
    blobstore: {provider: local, path: /var/vcap/micro_bosh/data/cache}
    ntp: [0.pool.ntp.org, 1.pool.ntp.org]
EOF

function finish {
  echo "Final state of director deployment:"
  echo "=========================================="
  cat director-state.json
  echo "=========================================="

  cp director{.yml,-state.json} $deployment_dir
  cp -r $HOME/.bosh_init $deployment_dir
}
trap finish ERR

bosh_init=$(echo ${bosh_init_dir}/bosh-init-*)
chmod +x $bosh_init

echo "using bosh-init CLI version..."
$bosh_init version

echo "deploying BOSH..."
$bosh_init deploy ./director.yml

trap - ERR
finish
