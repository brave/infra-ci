resource "aws_s3_bucket" "codepipeline" {
  bucket = "brave-${local.region_code}-${var.appname}-${var.env}-codepipeline"

  force_destroy = true

  tags {
    "app" = "${var.appname}"
    "env" = "${var.env}"
  }
}

resource "aws_iam_role" "codepipeline" {
  name = "${local.region_code}-${var.appname}-${var.env}-codepipeline"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "codepipeline" {
  name = "${local.region_code}-${var.appname}-${var.env}-codepipeline"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:ListBucket",
        "s3:ListObjects",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline.arn}",
        "${aws_s3_bucket.codepipeline.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "${aws_lambda_function.tfplan_notify.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:ListFunctions"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codeCommit:GetUploadArchiveStatus",
        "codecommit:CancelUploadArchive",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetUploadStatus",
        "codecommit:UploadArchive"
      ],
      "Resource": "${aws_codecommit_repository.app.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  policy_arn = "${aws_iam_policy.codepipeline.arn}"
  role = "${aws_iam_role.codepipeline.name}"
}

resource "aws_codepipeline" "terraform" {
  name     = "${local.region_code}-${var.appname}-${var.env}-terraform"
  role_arn = "${aws_iam_role.codepipeline.arn}"

  artifact_store {
    location = "${aws_s3_bucket.codepipeline.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["Source"]

      configuration {
        RepositoryName = "${aws_codecommit_repository.app.repository_name}"
        BranchName     = "${var.branch}"
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["Source"]
      version         = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.terraform.name}"
      }

      output_artifacts = ["TFPlan"]
    }
  }

  stage {
    name = "Notify"

    action {
      name = "Notify"
      category = "Invoke"
      owner = "AWS"
      provider = "Lambda"
      input_artifacts = ["TFPlan"]
      version = "1"

      configuration {
        FunctionName = "${aws_lambda_function.tfplan_notify.function_name}"
        UserParameters = <<EOF
{
  "file":"plan.txt",
  "artifact":"TFPlan"
}
EOF
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name            = "Approval"
      category        = "Approval"
      owner           = "AWS"
      provider        = "Manual"
      version         = "1"
      configuration {
        NotificationArn = "${aws_sns_topic.approval.arn}"
        CustomData = "Terraform plan output: ${aws_s3_bucket.codepipeline.bucket_domain_name}/plan.txt"
      }
    }
  }

  stage {
    name = "Apply"

    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["TFPlan"]
      version         = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.apply.name}"
      }

      #output_artifacts = ["TFApply"]
    }
  }
}

resource "aws_sns_topic" "approval" {
  name = "brave-${local.region_code}-${var.appname}-${var.env}-codepipeline-approval"
}


resource "aws_sns_topic_policy" "approval" {
  arn = "${aws_sns_topic.approval.arn}"

  policy = "${data.aws_iam_policy_document.approval.json}"
}


data "aws_iam_policy_document" "approval" {
  statement {
    actions = [
      "SNS:Publish"
    ]

    condition {
      test = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        "${data.aws_caller_identity.sub_account.account_id}",
      ]
    }

    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "${aws_sns_topic.approval.arn}",
    ]
  }
}

resource "aws_cloudformation_stack" "approval_email" {

  name = "${var.appname}-${var.env}-approval"
  parameters {
    Email    = "${var.email_notify}"
    TopicArn = "${aws_sns_topic.approval.arn}"
  }
  template_body = <<EOF

{
  "AWSTemplateFormatVersion" : "2010-09-09",
  "Description"              : "Create a VPC containing two subnets and an auto scaling group containing instances with Internet access.",
  "Parameters"               : {
      "TopicArn" : {
          "Type"        : "String"
      },
      "Email" : {
          "Type"        : "String"
      }
  },
  "Resources"                : {
    "MySubscription" : {
      "Type" : "AWS::SNS::Subscription",
      "Properties" : {
        "Endpoint" : {"Ref" : "Email"},
        "Protocol" : "email",
        "TopicArn" : {"Ref" : "TopicArn"}
      }
    }
  }
}
EOF
}


resource "aws_iam_role" "codepipeline_lambda" {
  name = "${var.appname}-${var.env}-codepipeline-lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "codepipeline_lambda" {
  name = "${local.region_code}-${var.appname}-${var.env}-codepipeline-lambda"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:ListBucket",
        "s3:ListObjects",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline.arn}",
        "${aws_s3_bucket.codepipeline.arn}/*"
      ]
    },
    {
      "Action": [
        "codepipeline:PutJobSuccessResult",
        "codepipeline:PutJobFailureResult"
        ],
        "Effect": "Allow",
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codepipeline_lambda" {
  policy_arn = "${aws_iam_policy.codepipeline_lambda.arn}"
  role = "${aws_iam_role.codepipeline_lambda.name}"
}

resource "aws_iam_role_policy_attachment" "codepipeline_lambda_exec" {
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaExecute"
  role = "${aws_iam_role.codepipeline_lambda.name}"
}

data "archive_file" "tfplan_notify" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/tfplan_notify"
  output_path = "${path.module}/lambda/tfplan_notify.zip"
}

resource "aws_lambda_function" "tfplan_notify" {
  filename         = "${data.archive_file.tfplan_notify.output_path}"
  function_name    = "${var.appname}-${var.env}-codepipeline-tfplan-notify"
  role             = "${aws_iam_role.codepipeline_lambda.arn}"
  handler          = "main.lambda_handler"
  source_code_hash = "${data.archive_file.tfplan_notify.output_base64sha256}"
  runtime          = "python2.7"
  timeout          = "30"
}