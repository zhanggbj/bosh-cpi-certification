#!/usr/bin/env bash

set -e

source pipelines/aws/utils.sh

: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${AWS_STACK_NAME:?}
: ${STEMCELL_NAME:?}

source /etc/profile.d/chruby.sh
chruby 2.1.2

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

# inputs
stemcell_path="$(realpath stemcell/*.tgz)"
e2e_release="$(realpath pipelines/aws/assets/e2e-test-release)"

: ${SUBNET_ID:=$(            stack_info "PublicSubnetID")}
: ${AVAILABILITY_ZONE:=$(    stack_info "AvailabilityZone")}
: ${DIRECTOR_IP:=$(          stack_info "DirectorEIP")}
: ${IAM_INSTANCE_PROFILE:=$( stack_info "IAMInstanceProfile")}
: ${ELB_NAME:=$(             stack_info "ELB")}

bosh -n target "${DIRECTOR_IP}"
bosh -n login "${BOSH_DIRECTOR_USERNAME}" "${BOSH_DIRECTOR_PASSWORD}"
bosh_uuid="$(bosh status --uuid)"

e2e_deployment_name=e2e-test
e2e_release_version=1.0.0
pushd ${e2e_release}
  time bosh -n create release --force --name ${e2e_deployment_name} --version ${e2e_release_version}
  time bosh -n upload release --skip-if-exists
popd

time bosh -n upload stemcell "${stemcell_path}" --skip-if-exists

e2e_manifest_filename=e2e-manifest.yml
cat > "${e2e_manifest_filename}" <<EOF
---
name: ${e2e_deployment_name}
director_uuid: ${bosh_uuid}

releases:
  - name: ${e2e_deployment_name}
    version: latest

compilation:
  reuse_compilation_vms: true
  workers: 1
  network: private
  cloud_properties:
    instance_type: m3.medium
    availability_zone: ${AVAILABILITY_ZONE}

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 3

resource_pools:
  - &default_resource_pool
    name: default
    stemcell:
      name: ${STEMCELL_NAME}
      version: latest
    network: private
    cloud_properties: &default_cloud_properties
      instance_type: m3.medium
      availability_zone: ${AVAILABILITY_ZONE}
  - <<: *default_resource_pool
    name: raw_ephemeral_pool
    cloud_properties:
      <<: *default_cloud_properties
      raw_instance_storage: true
  - <<: *default_resource_pool
    name: elb_registration_pool
    cloud_properties:
      <<: *default_cloud_properties
      elbs: [${ELB_NAME}]
  - <<: *default_resource_pool
    name: spot_instance_pool
    cloud_properties:
      <<: *default_cloud_properties
      spot_bid_price: 0.10 # 10x the normal bid price

networks:
  - name: private
    type: dynamic
    cloud_properties: {subnet: ${SUBNET_ID}}

jobs:
  - name: iam-instance-profile-test
    template: iam-instance-profile-test
    lifecycle: errand
    instances: 1
    resource_pool: default
    networks:
      - name: private
        default: [dns, gateway]
  - name: raw-ephemeral-disk-test
    template: raw-ephemeral-disk-test
    lifecycle: errand
    instances: 1
    resource_pool: raw_ephemeral_pool
    networks:
      - name: private
        default: [dns, gateway]
  - name: elb-registration-test
    template: elb-registration-test
    lifecycle: errand
    instances: 1
    resource_pool: elb_registration_pool
    networks:
      - name: private
        default: [dns, gateway]
  - name: spot-instance-test
    template: spot-instance-test
    lifecycle: errand
    instances: 1
    resource_pool: spot_instance_pool
    networks:
      - name: private
        default: [dns, gateway]

properties:
  iam_instance_profile: ${IAM_INSTANCE_PROFILE}
  load_balancer_name: ${ELB_NAME}
  aws_region: ${AWS_REGION_NAME}
EOF

bosh -n deployment "${e2e_manifest_filename}"
time bosh -n deploy

time bosh -n run errand iam-instance-profile-test

time bosh -n run errand raw-ephemeral-disk-test

time bosh -n run errand elb-registration-test

time bosh -n run errand spot-instance-test
