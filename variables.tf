variable "region" {
  default     = "us-east-1"
  description = "Region to create pipeline in."
}

variable "account_id" {
  description = "AWS account ID"
}

variable "env" {
  description = "Environment name"
}

variable "email_notify" {
  description = "Email used to send pipeline results to"
}

variable "codecommit_name" {
  description = "Codecommit name used by this pipeline"
}

variable "branch" {
  description = "Branch to use for pipeline source"
}
