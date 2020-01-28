variable "project" {
  default = "neo4j-infra"
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

locals {
  compute_type         = "BUILD_GENERAL1_SMALL"
  custom_compute_image = "codebuild-al2-impl:latest"
  region               = "us-east-1"
  bucket-name          = "neo4j-build-output"
  cron_expression      = "cron(0 5 ? * MON-FRI *)"
  app_subnet_filter    = ["*app"]
  vpc_id               = "vpc-05a676a9f7913930d"
  neo4j_uri            = "bolt://10.246.85.100"
  neo4j_web_port       = 7474
  neo4j_bolt_port      = 7687
}
