#!/usr/bin/env bash

compute_sha() {
  path=$1
  shasum $path | cut -f1 -d' '
}

env_attr() {
  local json=$1
  echo $json | jq --raw-output --arg attribute $2 '.[$attribute]'
}
