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
      "Type", "private",
      "layer", "App"
    )
  )
  aws_acct_count = length(var.aws_accounts)
}

data "aws_caller_identity" "current" {}


data "aws_ssm_parameter" "accounts" {
  count = local.aws_acct_count
  name  = "/accounts/qpp/${element(var.aws_accounts, count.index)}"
}

data "aws_iam_policy_document" "codebuild_crossaccount_policy" {
  statement {
    sid    = "XAcctPolicy"
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    resources = [
      for account_id in data.aws_ssm_parameter.accounts[*] :
      "arn:aws:iam::${account_id.value}:role/neo4j-iam-audit-role"
    ]
  }
}

data "template_file" "neo4j-buildspec" {
  template = file("codebuild/buildspec.tpl")
}

#CodeBuild role and policies
data "aws_iam_policy_document" "codebuild-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "events-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "template_file" "codebuild_base_policy" {
  template = file("policies/codebuild-base.tpl")
  vars = {
    region                     = local.region
    account_id                 = data.aws_caller_identity.current.account_id
    codebuild-artifacts-bucket = local.bucket-name
    subnet                     = tolist(data.aws_subnet_ids.app_subnets.ids)[0]
  }
}

data "template_file" "codebuild_cloudwatch_policy" {
  template = file("policies/codebuild-cloudwatch.tpl")
  vars = {
    region     = local.region
    account_id = data.aws_caller_identity.current.account_id
  }
}

data "template_file" "codebuild_trigger_policy" {
  template = file("policies/codebuild-trigger.tpl")
  vars = {
    region     = local.region
    account_id = data.aws_caller_identity.current.account_id
    project    = var.project
  }
}

data "template_file" "neo4j_task_definition" {
  template = file("fargate/neo4j_task.tpl")
  vars = {
    region            = local.region
    http_port         = local.neo4j_web_port
    bolt_port         = local.neo4j_bolt_port
    container_version = var.container_version
    auth_enabled      = var.dbms_security_auth_enabled
  }
}

data "aws_subnet_ids" "app_subnets" {
  vpc_id = local.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*app"]
  }
}

data "aws_subnet" "app_group_subnets" {
  count = length(data.aws_subnet_ids.app_subnets.ids)
  id    = tolist(data.aws_subnet_ids.app_subnets.ids)[count.index]
}

data "aws_route53_zone" "qpp_hosted_zone" {
  name         = "qpp.internal."
  private_zone = true
  provider     = aws.qppg
}

data "aws_ssm_parameter" "qppg_account" {
  name = "/accounts/qpp/aws-hhs-cms-ccsq-qpp-qppg"
}
#
# data "aws_ssm_parameter" "cm_account" {
#   name = "/accounts/qpp/aws-hhs-cms-amg-qpp-cm"
# }
#
# data "aws_ssm_parameter" "aws-hhs-cms-amg-qpp-costscoring" {
#   name = "/accounts/qpp/aws-hhs-cms-amg-qpp-costscoring"
# }
#
# data "aws_ssm_parameter" "aws-hhs-cms-amg-qpp-selfn" {
#   name = "/accounts/qpp/aws-hhs-cms-amg-qpp-selfn"
# }
#
# data "aws_ssm_parameter" "aws-hhs-cms-ccsq-qpp-navadevops" {
#   name = "/accounts/qpp/aws-hhs-cms-ccsq-qpp-navadevops"
# }
#
# data "aws_ssm_parameter" "aws-hhs-cms-ccsq-qpp-semanticbits" {
#   name = "/accounts/qpp/aws-hhs-cms-ccsq-qpp-semanticbits"
# }
#
# data "aws_ssm_parameter" "aws-hhs-cms-mip" {
#   name = "/accounts/qpp/aws-hhs-cms-mip"
# }
