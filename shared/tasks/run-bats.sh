#!/usr/bin/env bash

set -e

source this/shared/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

# preparation
cp ./bats-config/* .
source bats.env

shared_key="shared.pem"
chmod go-r ${shared_key}
eval $(ssh-agent)
ssh-add ${shared_key}

pushd "$(realpath bats)"
  ./write_gemfile
  bundle install
  bundle exec rspec spec
popd
