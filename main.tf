provider "aws" {
  region     = "us-east-1"
}

resource "aws_cloudformation_stack" "tf_codebuild" {
  name = "tf-codebuild"

  parameters {
    ApplicationName = "<example>"
    GitHubRepository = "<example>"
    GitHubBranch = "branch"
    ArtifactS3Bucket = "<example>"
    CloudflareEmail = "jarv@example.com"
    CloudflareParameterName = "<example>"
    FastlyParameterName = "<example>"
  }
  region     = "${var.region}"
  allowed_account_ids = [
    "${var.account_id}"
  ]
}

resource "aws_cloudformation_stack" "central_microservices" {
  name = "${var.codecommit_name}-${var.env}-cf-central-microservices"

  parameters {
    StackCreationRoleArn = "<example>"
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]

  # Original from: https://s3.amazonaws.com/solutions-reference/aws-cloudformation-validation-pipeline/latest/central-microservices.template
  template_body = "${file("${path.module}/cloudformation/central-microservices.json")}"
}

resource "aws_cloudformation_stack" "cf_main_pipeline" {
  name = "${var.codecommit_name}-${var.env}-cf-main-pipeline"
  depends_on = ["aws_cloudformation_stack.central_microservices"]

  parameters {
    EmailPrimary	    = "${var.email_notify}"
    SourceRepoBranch	    = "${var.branch}"
    CodeCommitRepoName	    = "${var.codecommit_name}"
    BuildSpec		    = "${var.buildspec}"
    ApplicationName	    = "${var.codecommit_name}"
    CloudflareEmail	    = "${var.cloudflare_email}"
    CloudflareParameterName = "${var.cloudflare_param_name}"
    FastlyParameterName	    = "${var.fastly_param_name}"
  }
  capabilities = ["CAPABILITY_IAM"]

  # Original from: https://s3.amazonaws.com/solutions-reference/aws-cloudformation-validation-pipeline/latest/main-pipeline.template
  template_body = "${file("${path.module}/cloudformation/main-pipeline.json")}"
}
