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
stack_template=${stack_template:-$AWS_STACK_NAME}

cmd="aws cloudformation create-stack \
    --stack-name      ${AWS_STACK_NAME} \
    --template-body   file:///${PWD}/this/aws/assets/cloudformation-${stack_template}.template.json \
    --capabilities    CAPABILITY_IAM"

echo "Running: ${cmd}"; ${cmd}
while true; do
  status=$(stack_status)
  echo "StackStatus ${status}"
  if [ $status == 'CREATE_IN_PROGRESS' ]; then
    echo "sleeping 5s"; sleep 5s
  else
    break
  fi
done

if [ $status != 'CREATE_COMPLETE' ]; then
  echo "cloudformation failed stack info:\n$(stack_data)"
  exit 1
fi
