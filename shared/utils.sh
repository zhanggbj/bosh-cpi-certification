#!/usr/bin/env bash

check_for_rogue_vm() {
  local ip=$1
  set +e
  nc -vz -w10 $ip 22
  status=$?
  set -e
  if [ "${status}" == "0" ]; then
    echo "aborting due to vm existing at ${ip}"
    exit 1
  fi
}

env_attr() {
  local json=$1
  echo $json | jq --raw-output --arg attribute $2 '.[$attribute]'
}
