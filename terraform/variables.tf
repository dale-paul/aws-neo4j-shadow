variable "project" {
  default = "neo4j-infra"
}

variable "application" {
  default = "neo4j-infra"
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
}
