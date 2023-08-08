#!/bin/bash

# This script is run as terraform external data source to fetch kms key id
set -e

eval "$(jq -r '@sh "alias_name=\(.alias_name) region=\(.region)"')"

RESULT=`aws kms describe-key --key-id $alias_name --region $region --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo ""`

jq -n --arg key_id "$RESULT" '{"key_id":$key_id}'
