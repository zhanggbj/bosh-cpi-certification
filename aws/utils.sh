#!/usr/bin/env bash

stack_data() {
  echo "$(aws cloudformation describe-stacks)" | \
  jq --arg stack_name ${AWS_STACK_NAME} '.Stacks[] | select(.StackName=="\($stack_name)")'
}

stack_info() {
  if [ "${AWS_STACK_INFO}" == "" ] ; then
    AWS_STACK_INFO="$(stack_data)"
  fi

  local key="$1"
  echo "${AWS_STACK_INFO}" | jq -r --arg key ${key} '.Outputs[] | select(.OutputKey=="\($key)").OutputValue'
}

stack_status() {
  echo "$(stack_data)" | jq -r '.StackStatus'
}
