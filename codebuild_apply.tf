resource "aws_s3_bucket" "codebuild_apply" {
  bucket = "brave-${local.region_code}-${var.appname}-${var.env}-codebuild-apply-cache"

  force_destroy = true

  tags {
    "app" = "${var.appname}"
    "env" = "${var.env}"
  }
}

resource "aws_iam_role" "codebuild_apply" {
  name = "${local.region_code}-${var.appname}-${var.env}-codebuild-apply"
  path = "/service-role/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codepipeline_poweruser" {
  role       = "${aws_iam_role.codebuild.name}"
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}


resource "aws_codebuild_project" "apply" {
  name          = "${local.region_code}-${var.appname}-${var.env}-codebuild-apply"
  description   = "${var.appname} ${var.env} codebuild project"
  build_timeout = "20"
  service_role  = "${aws_iam_role.codebuild_apply.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.codebuild_apply.bucket}"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/docker:17.09.0"
    type         = "LINUX_CONTAINER"
    privileged_mode = true # docker host container runs as privliged, doesn't apply to builds

    environment_variable {
      name  = "CLOUDFLARE_EMAIL"
      value = "${var.cloudflare_email}"
    }

    environment_variable {
      type  = "PARAMETER_STORE"
      name  = "CLOUDFLARE_TOKEN"
      value = "${var.cloudflare_param_name}" // Name of SSM param not plaintext
    }

    environment_variable {
      type  = "PARAMETER_STORE"
      name  = "FASTLY_API_KEY"
      value = "${var.fastly_param_name}" // Name of SSM param not plaintext
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.buildspec_apply}"
  }

  tags {
    "app" = "${var.appname}"
    "env" = "${var.env}"
  }
}