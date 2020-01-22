terraform {
  backend "s3" {
    bucket         = "aws-hhs-cms-amg-qpp-secops-terraform-us-east-1"
    key            = "neo4j-infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "neo4j-infra-lock"
  }
}

locals {
  default_tags = merge(
    var.common_tags,
    map(
      "application", "${var.application}",
      "business", "${var.business}",
      "project", "${var.project}",
    )
  )
}

data "aws_caller_identity" "current" {}

data "template_file" "neo4j-buildspec" {
  template = file("codebuild/buildspec.tpl")
}

#CodeBuild role and policies
data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "template_file" "codebuild_base_policy" {
  template = file("policies/codebuild-base.tpl")
  vars = {
    region     = local.region
    account_id = data.aws_caller_identity.current.account_id
  }
}

data "template_file" "codebuild_cloudwatch_policy" {
  template = file("policies/codebuild-cloudwatch.tpl")
  vars = {
    region     = local.region
    account_id = data.aws_caller_identity.current.account_id
  }
}

resource "aws_iam_role_policy" "codebuild_ecr_policy" {
  name   = "CodeBuildECSPolicy-neo4j-${local.region}"
  policy = file("policies/codebuild-ecr.json")
  role   = aws_iam_role.codebuild_neo4j_role.id
}
