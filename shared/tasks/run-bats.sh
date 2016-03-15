#!/usr/bin/env bash

set -e

source pipelines/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# preparation
export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats.yml)
export BAT_VCAP_PRIVATE_KEY=$(realpath bats-config/shared.pem)
bats_dir=$(realpath bats)

# disable host key checking for deployed VMs
mkdir -p $HOME/.ssh
cat > $HOME/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

chmod go-r ${BAT_VCAP_PRIVATE_KEY}
eval $(ssh-agent)
ssh-add ${BAT_VCAP_PRIVATE_KEY}

source "$(realpath bats-config/bats.env)"
: ${BAT_DIRECTOR:?}
: ${BAT_DNS_HOST:?}
: ${BAT_INFRASTRUCTURE:?}
: ${BAT_NETWORKING:?}
: ${BAT_VIP:?}
: ${BAT_SUBNET_ID:?}
: ${BAT_SECURITY_GROUP_NAME:?}
: ${BAT_VCAP_PASSWORD:?}
: ${BAT_RSPEC_FLAGS:=""}

pushd $bats_dir
  ./write_gemfile
  bundle install
  bundle exec rspec spec ${BATS_RSPEC_FLAGS}
popd
