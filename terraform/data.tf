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
  environment = "production"
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

data "template_file" "neo4j-image-buildspec" {
  template = file("codebuild/buildspec-image.tpl")
}

data "aws_iam_policy_document" "ecs_task_execution" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "template_file" "ecs_task_execution_policy" {
  template = file("policies/ecs-task-execution.tpl")
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
    region         = local.region
    account_id     = data.aws_caller_identity.current.account_id
    infra-project  = var.project
    docker-project = "${var.docker_project}-${local.environment}"
  }
}

data "template_file" "neo4j_task_definition" {
  template = file("fargate/neo4j_task.tpl")
  vars = {
    region                  = local.region
    http_port               = local.neo4j_web_port
    bolt_port               = local.neo4j_bolt_port
    image                   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region}.amazonaws.com/neo4j:${var.container_version}"
    auth_enabled            = var.dbms_security_auth_enabled
    bolt_advertised_address = local.neo4j_uri
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
  name = "/accounts/qpp/aws-hhs-cms-ccsq-isg-qpp-fc"
}

data "aws_iam_policy_document" "cost_saving_lambda_iam_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "application-autoscaling:RegisterScalableTarget",
      "logs:PutLogEvents",
      "logs:CreateLogGroup"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "cost_saving_lambda_iam_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
