#!/bin/bash

set -e

alias_name=$1

key_id=$(aws kms describe-key --key-id $alias_name --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "")

echo "{\"key_id\":\"$key_id\"}"
