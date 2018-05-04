resource "aws_s3_bucket" "codebuild" {
  bucket = "brave-${local.region_code}-${var.appname}-${var.env}-codebuild-cache"

  force_destroy = true

  tags {
    "app" = "${var.appname}"
    "env" = "${var.env}"
  }
}

resource "aws_iam_role" "codebuild" {
  name = "${local.region_code}-${var.appname}-${var.env}-codebuild-read-all"
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

resource "aws_iam_policy" "codebuild" {
  name        = "${local.region_code}-${var.appname}-${var.env}-codebuild"
  path        = "/service-role/"
  description = "Policy used in trust relationship with CodeBuild"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "arn:aws:logs:us-east-2:${data.aws_caller_identity.sub_account.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.terraform.name}",
        "arn:aws:logs:us-east-2:${data.aws_caller_identity.sub_account.account_id}:log-group:/aws/codebuild/${aws_codebuild_project.terraform.name}:*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.codebuild.arn}"
      ],
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "codebuild_policy_attachment" {
  name       = "${local.region_code}-${var.appname}-${var.env}-codebuild"
  policy_arn = "${aws_iam_policy.codebuild.arn}"
  roles      = ["${aws_iam_role.codebuild.id}"]
}

resource "aws_iam_role_policy_attachment" "codepipeline_read_all" {
  role       = "${aws_iam_role.codebuild.name}"
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}


resource "aws_codebuild_project" "terraform" {
  name          = "${local.region_code}-${var.appname}-${var.env}-codebuild"
  description   = "${var.appname} ${var.env} codebuild project"
  build_timeout = "20"
  service_role  = "${aws_iam_role.codebuild.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.codebuild.bucket}"
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
    buildspec = "${var.buildspec}"
  }

  tags {
    "app" = "${var.appname}"
    "env" = "${var.env}"
  }
}