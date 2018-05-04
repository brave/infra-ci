provider "aws" {
  alias      = "root"
  region     = "${var.region}"
  allowed_account_ids = [
    "${var.account_id}"
  ]
}

locals {
  region_codes = {
    us-east-1 = "usea1"
    us-east-2 = "usea2"
    us-west-1 = "uswe1"
    us-west-2 = "uswe2"
    us-gov-west-1 = "ugwe2"
    ca-central-1 = "cace1"
    eu-west-1 = "euwe1"
    eu-west-2 = "euwe2"
    eu-central-1 = "euce1"
    ap-southeast-1 = "apse1"
    ap-southeast-2 = "apse2"
    ap-south-1 = "apso1"
    ap-northeast-1 = "apne1"
    ap-northeast-2 = "apne2"
    sa-east-1 = "saea1"
    cn-north-1 = "cnno1"
  }
  region_code = "${local.region_codes[var.region]}"
}

resource "aws_organizations_account" "account" {
  provider  = "aws.root"
  name      = "${var.appname}-${var.env}"
  email     = "${var.email_notify}"
  role_name = "CrossAccountOrgAdmin"
}

resource "aws_organizations_policy" "account" {
  provider  = "aws.root"
  name      = "${var.appname}-${var.env}-account"

  content   = <<CONTENT
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*"
  }
}
CONTENT
  type = "SERVICE_CONTROL_POLICY"
}

resource "aws_organizations_policy_attachment" "account" {
  provider = "aws.root"
  policy_id = "${aws_organizations_policy.account.id}"
  target_id = "${aws_organizations_account.account.id}"
}

provider "aws" {
  region  = "${var.region}"
  #profile = "sandbox"

  assume_role {
    role_arn     = "arn:aws:iam::${aws_organizations_account.account.id}:role/${aws_organizations_account.account.role_name}"
  }
}

data "aws_caller_identity" "sub_account" {}
output "account_id_sub" {
  value = "${data.aws_caller_identity.sub_account.account_id}"
}

data "aws_caller_identity" "root_account" {
  provider = "aws.root"
}
output "root_account_id" {
  value = "${data.aws_caller_identity.root_account.account_id}"
}
