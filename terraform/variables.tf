variable "project" {
  default = "neo4j-infra"
}

variable "docker_project" {
  default = "neo4j-docker"
}

variable "application" {
  default = "neo4j-infra"
}

variable "cert_name" {
  default = "wildcard-internal"
}

variable "common_tags" {
  description = "Tags attributed to the instance"
  default = {
    sensitivity       = "Confidential"
    owner             = "QPPFC Security Sub-Team"
    email             = "qppfc@flexion.us"
    "pagerduty email" = "qpp-foundational-components-general@cms-qpp.pagerduty.com"
  }
}

variable "business" {
  default = "ccsq"
}

variable "container_version" {
  default = "4.0"
}

variable "dbms_security_auth_enabled" {
  default = "false"
}

variable "aws_accounts" {
  default = [
    "aws-hhs-cms-ccsq-qpp-qppg",
    "aws-hhs-cms-amg-qpp-cm",
    "aws-hhs-cms-amg-qpp-costscoring",
    "aws-hhs-cms-amg-qpp-selfn",
    "aws-hhs-cms-ccsq-qpp-navadevops",
    "aws-hhs-cms-ccsq-qpp-semanticbits",
    "aws-hhs-cms-mip",
    "aws-hhs-cms-amg-qpp-targetreview"
  ]
}

variable "scheduled_events" {
  description = "CloudWatch scheduled events"
  type        = map
  default = {
    SHUTDOWN = "cron(30 23 ? * MON-FRI *)",
    WAKEUP   = "cron(45 11 ? * MON-FRI *)"
  }
}

locals {
  compute_type         = "BUILD_GENERAL1_SMALL"
  custom_compute_image = "codebuild-al2:latest"
  region               = "us-east-1"
  bucket-name          = "neo4j-build-output"
  cron_expression      = "cron(45 11 ? * MON-FRI *)"
  app_subnet_filter    = ["*app"]
  vpc_id               = "vpc-05a676a9f7913930d"
  neo4j_uri            = "neo4j.qpp.internal"
  neo4j_web_port       = 7474
  neo4j_bolt_port      = 7687
  source_version       = "v1.0.2"
}
