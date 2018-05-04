variable "region" {
  default     = "us-east-1"
  description = "Region to create pipeline in."
}

variable "account_id" {
  description = "AWS account ID"
}

variable "appname" {
  description = "App name"
}

variable "env" {
  description = "Environment name"
}

variable "email_notify" {
  description = "Email used to send pipeline results to"
}

variable "buildspec" {
  description = "The path in the source repo where to find buildspec.yml"
  default = "./buildspec.yml" 
}

variable "branch" {
  description = "Branch to use for pipeline source"
}

variable "cloudflare_email" {
  description = "Value to set for CLOUDFLARE_EMAIL in the CodeBuild environment"
}

variable "cloudflare_param_name" {
  description = "The SSM parameter name of where to find the CLOUDFLARE_TOKEN secret"
}

variable "fastly_param_name" {
  description = "The SSM parameter name of where to find the FASTLY_API_KEY secret"
}

