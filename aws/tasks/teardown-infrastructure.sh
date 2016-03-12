#!/usr/bin/env bash

set -e

: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}

source this/shared/utils.sh
source this/aws/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

cmd="aws cloudformation delete-stack --stack-name ${AWS_STACK_NAME}"
echo "Running: ${cmd}"; ${cmd}

while true; do
  status=$(stack_status)
  echo "StackStatus ${status}"
  if [[ -z "${status}" ]]; then # get empty status due to stack not existed on aws
    echo "No stack found"; break
    break
  elif [ ${status} == 'DELETE_IN_PROGRESS' ]; then
    echo "${status}: sleeping 5s"; sleep 5s
  else
    echo "Expecting the stack to either be deleted or in the process of being deleted but was ${status}"
    echo $(stack_data)
    exit 1
  fi
done
