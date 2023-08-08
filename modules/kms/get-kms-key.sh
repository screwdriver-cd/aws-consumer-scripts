#!/bin/bash

set -e

alias_name=$1
region=$2

key_id=$(aws kms describe-key --key-id $alias_name --region $region --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "")

echo "{\"key_id\":\"$key_id\"}"
