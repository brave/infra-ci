resource "aws_codecommit_repository" "app" {
  repository_name = "${var.appname}-${var.env}"
  description     = "This is the Sample App Repository"
}

resource "aws_cloudwatch_event_rule" "source" {
  name        = "${var.appname}-${var.env}"
  description = "Amazon CloudWatch Events rule to automatically start your pipeline when a change occurs in the AWS CodeCommit source repository and branch. Deleting this may prevent changes from being detected in that pipeline. Read more: http://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-about- starting.html"

  event_pattern = <<EOH
{
  "source": [
    "aws.codecommit"
  ],
  "detail-type": [
    "CodeCommit Repository State Change"
  ],
  "resources": [
    "${aws_codecommit_repository.app.arn}"
  ],
  "detail": {
    "event": [
      "referenceCreated",
      "referenceUpdated"
    ],
    "referenceType": [
      "branch"
    ],
    "referenceName": [
      "master"
    ]
  }
}
EOH
}

resource "aws_cloudwatch_event_target" "app_source" {
  rule      = "${aws_cloudwatch_event_rule.source.name}"
  target_id = "CodePipeline"
  arn       = "${aws_codepipeline.terraform.arn}"
  role_arn = "${aws_iam_role.cloudwatch_app_source.arn}"
}

resource "aws_iam_role" "cloudwatch_app_source" {
  name = "${local.region_code}-${var.appname}-${var.env}-event-source"
  path = "/service-role/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "app_source_trigger" {
  name        = "${local.region_code}-${var.appname}-${var.env}-event-source"
  path        = "/service-role/"
  description = "Policy used in trust relationship with CodeBuild"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codepipeline:StartPipelineExecution"
            ],
            "Resource": [
                "${aws_codepipeline.terraform.arn}"
            ]
        }
    ]
}
EOF
}
