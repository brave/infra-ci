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

resource "aws_iam_role_policy" "codepipeline" {
  name = "${local.region_code}-${var.appname}-${var.env}-codepipeline"
  role = "${aws_iam_role.codepipeline.id}"
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
        "s3:PutObject"
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
    name = "Build"

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
    name = "Approval"

    action {
      name            = "Approval"
      category        = "Approval"
      owner           = "AWS"
      provider        = "Manual"
      version         = "1"
    }
  }
}
