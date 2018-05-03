#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0: <region> <bucket_name>"
    exit 1
fi

REGION=$1
BUCKET=$2

aws --region "${REGION}" s3 mb "s3://${BUCKET}"
aws --region "${REGION}" s3api put-bucket-versioning --bucket "${BUCKET}" --versioning-configuration Status=Enabled
aws --region "${REGION}" s3api put-bucket-encryption --bucket "${BUCKET}" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

cat > tf_backend.tf <<EOF
terraform {
  backend "s3" {
    bucket = "${BUCKET}"
    key    = "terraform.tfstate"
    region = "${REGION}"
  }
}
EOF

echo "Added backend, make sure to save ./tf_backend.tf to your repository"
