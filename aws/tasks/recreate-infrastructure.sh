#!/usr/bin/env bash

set -e

: ${AWS_ACCESS_KEY:?}
: ${AWS_SECRET_KEY:?}
: ${AWS_REGION_NAME:?}
: ${AWS_STACK_NAME:?}

source pipelines/shared/utils.sh
source pipelines/aws/utils.sh
source /etc/profile.d/chruby.sh
chruby 2.1.7

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
export AWS_DEFAULT_REGION=${AWS_REGION_NAME}

# if the stack exists, clear out the related s3 blobstore
if [ "$(stack_status)" == "CREATE_COMPLETE" ] ; then
  bucket=$(stack_info 'BlobstoreBucketName')
  cmd="aws s3 rm s3://${bucket} --recursive --include '*'"
  echo "Clearing blobstore: ${bucket}"
  echo "Running: ${cmd}"; ${cmd}
fi

# delete the stack (idempotent)
cmd="aws cloudformation delete-stack --stack-name ${AWS_STACK_NAME}"
echo "Deleting stack: ${AWS_STACK_NAME}"
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

# create the stack
cmd="aws cloudformation create-stack \
    --stack-name      ${AWS_STACK_NAME} \
    --parameters      ParameterKey=TagName,ParameterValue=${AWS_STACK_NAME} \
    --template-body   file:///${PWD}/pipelines/aws/assets/cloudformation-generic.template.json \
    --capabilities    CAPABILITY_IAM"

echo "Creating stack: ${AWS_STACK_NAME}"
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
