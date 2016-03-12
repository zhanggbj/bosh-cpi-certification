#!/usr/bin/env bash

set -e

# environment
: ${BOSH_RELEASE_URI:?}
: ${CPI_RELEASE_URI:?}
: ${STEMCELL_URI:?}
: ${BOSH_DIRECTOR_USERNAME:?}
: ${BOSH_DIRECTOR_PASSWORD:?}
: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}
: ${AWS_STACK_PREFIX:?}
: ${PUBLIC_KEY_NAME:?}
: ${PRIVATE_KEY_DATA:?}

# if the X_SHA1 variable is set, use that; else, compute from input resource.
: ${BOSH_RELEASE_SHA1:=$( compute_sha ./bosh-release/release.tgz )}
: ${CPI_RELEASE_SHA1:=$(  compute_sha ./cpi-release/release.tgz )}
: ${STEMCELL_SHA1:=$(     compute_sha ./stemcell/stemcell.tgz )}

source this/shared/utils.sh
source this/aws/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# configuration
: ${SECURITY_GROUP:=$(      aws ec2 describe-security-groups --group-ids $(stack_info "SecurityGroupID") | jq -r '.SecurityGroups[] .GroupName' ) }
: ${DIRECTOR_EIP:=$(        stack_info "DirectorEIP" )}
: ${SUBNET_ID:=$(           stack_info "SubnetID" )}
: ${AVAILABILITY_ZONE:=$(   stack_info "AvailabilityZone" )}
: ${AWS_NETWORK_CIDR:=$(    stack_info "CIDR" )}
: ${AWS_NETWORK_GATEWAY:=$( stack_info "Gateway" )}
: ${DIRECTOR_STATIC_IP:=$(  stack_info "DirectorStaticIP" )}

# keys
shared_key="shared.pem"
echo "${PRIVATE_KEY_DATA}" > "./director-config/${shared_key}"

# env file generation
cat > "./director-config/director.env" <<EOF
#!/usr/bin/env bash

export DIRECTOR_IP=${DIRECTOR_EIP}
EOF

# manifest generation
cat > "./director-config/director.yml" <<EOF
---
name: bats-director

releases:
  - name: bosh
    url: ${BOSH_RELEASE_URI}
    sha1: ${BOSH_RELEASE_SHA1}
  - name: bosh-vsphere-cpi
    url: ${CPI_RELEASE_URI}
    sha1: ${CPI_RELEASE_SHA1}

resource_pools:
  - name: default
    network: private
    stemcell:
      url: ${STEMCELL_URI}
      sha1: ${STEMCELL_SHA1}
    cloud_properties:
      instance_type: m3.medium
      availability_zone: ${AVAILABILITY_ZONE}
      ephemeral_disk:
        size: 25000
        type: gp2

disk_pools:
  - name: default
    disk_size: 25_000
    cloud_properties: {type: gp2}

networks:
  - name: private
    type: manual
    subnets:
    - range:    ${AWS_NETWORK_CIDR}
      gateway:  ${AWS_NETWORK_GATEWAY}
      dns:      [8.8.8.8]
      cloud_properties: {subnet: ${SUBNET_ID}}
  - name: public
    type: vip

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
      - {name: registry, release: bosh}
      - {name: aws_cpi, release: bosh-aws-cpi}

    resource_pool: default
    persistent_disk_pool: default

    networks:
      - name: private
        static_ips: [${DIRECTOR_STATIC_IP}]
        default: [dns, gateway]
      - name: public
        static_ips: [${DIRECTOR_EIP}]

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

      registry:
        address: ${DIRECTOR_STATIC_IP}
        host: ${DIRECTOR_STATIC_IP}
        db: *db
        http: {user: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}, port: 25777}
        username: ${BOSH_DIRECTOR_USERNAME}
        password: ${BOSH_DIRECTOR_PASSWORD}
        port: 25777

      blobstore:
        provider: dav
        port: 25250
        address: ${DIRECTOR_STATIC_IP}
        director: {user: director, password: director-password}
        agent: {user: agent, password: agent-password}

      director:
        address: 127.0.0.1
        name: bats-director
        db: *db
        cpi_job: aws_cpi
        user_management:
          provider: local
          local:
            users:
              - {name: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}

      hm:
        http: {user: hm, password: hm-password}
        director_account: {user: ${BOSH_DIRECTOR_USERNAME}, password: ${BOSH_DIRECTOR_PASSWORD}}

      dns:
        address: 127.0.0.1
        db: *db

      agent: {mbus: "nats://nats:nats-password@${DIRECTOR_STATIC_IP}:4222"}

      ntp: &ntp
        - 0.north-america.pool.ntp.org
        - 1.north-america.pool.ntp.org

      aws: &aws
        access_key_id: ${AWS_ACCESS_KEY}
        secret_access_key: ${AWS_SECRET_KEY}
        default_key_name: ${PUBLIC_KEY_NAME}
        default_security_groups: ["${SECURITY_GROUP}"]
        region: "${AWS_REGION}"

cloud_provider:
  template: {name: aws_cpi, release: bosh-aws-cpi}

  ssh_tunnel:
    host: ${DIRECTOR_EIP}
    port: 22
    user: vcap
    private_key: ${shared_key}

  mbus: "https://mbus:mbus-password@${DIRECTOR_IP}:6868"

  properties:
    aws: *aws

    # Tells CPI how agent should listen for requests
    agent: {mbus: "https://mbus-user:mbus-password@0.0.0.0:6868"}

    blobstore:
      provider: local
      path: /var/vcap/micro_bosh/data/cache

    ntp: *ntp
EOF
