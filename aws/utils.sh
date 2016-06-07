#!/usr/bin/env bash

set -e -o pipefail

stack_data() {
  echo "$(aws cloudformation describe-stacks)" | \
  jq -e --arg stack_name ${AWS_STACK_NAME} '.Stacks[] | select(.StackName=="\($stack_name)")'
}

stack_info() {
  if [ "${AWS_STACK_INFO}" == "" ] ; then
    AWS_STACK_INFO="$(stack_data)"
  fi

  local key="$1"
  echo "${AWS_STACK_INFO}" | jq -e -r --arg key ${key} '.Outputs[] | select(.OutputKey=="\($key)").OutputValue'
}

stack_status() {
  echo "$(stack_data)" | jq -e -r '.StackStatus'
}
