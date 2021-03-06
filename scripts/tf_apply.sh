#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
    echo "usage: $0 <aws_profile>"
    exit 1
fi

PROFILE=$1

AWS_ACCESS_KEY_ID=$(aws configure --profile $PROFILE get aws_access_key_id) \
AWS_SECRET_ACCESS_KEY==$(aws configure --profile $PROFILE get aws_secret_access_key) \
    docker-compose run -w /tf -v $(pwd):/tf terraform init &&
    docker-compose run -w /tf -v /Users/rgerstenkorn/Code/infra-ci:/tf terraform apply
