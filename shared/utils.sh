#!/usr/bin/env bash

env_attr() {
  local json=$1
  echo $json | jq --raw-output --arg attribute $2 '.[$attribute]'
}
