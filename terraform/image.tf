locals {
  owner_tag           = "nlandais@flexion.us"
  ecr_list            = ["${aws_ecr_repository.neo4j.name}"]
  pagerduty_email_tag = "qpp-foundational-components-general@cms-qpp.pagerduty.com"
  ssm_param_list      = ["image-digest"]
}

# Create ECR for Neo4j image imported from DockerHub
resource "aws_ecr_repository" "neo4j" {
  name                 = "neo4j"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  tags = local.default_tags
}

# Create ssm parameter
resource "aws_ssm_parameter" "ne4oj_image_digest" {
  for_each    = toset(local.ssm_param_list)
  name        = format("/neo4j/%s/%s", local.environment, each.value)
  description = "SSM Parameter used by Codebuild Project ${var.docker_project}"
  type        = "String"
  value       = "initial seed value"
  tags = merge(
    local.default_tags,
    map(
      "owner", "${local.owner_tag}",
      "pagerduty_email", "${local.pagerduty_email_tag}"
    ),
    map(
      "sensitivity", "confidential",
      "expiry_date", "N/A",
      "environment", "${local.environment}",
      "application", "${var.docker_project}",
      "deploy_module", "terraform:qpp-tf-modules/codebuild/project",
    )
  )

  lifecycle {
    ignore_changes = [
      value,
    ]
  }
}

module "neo4j-image-codebuild" {
  source                = "git::https://github.cms.gov/qpp/qpp-tf-modules.git//codebuild/project/module?ref=1.2.0"
  region                = local.region
  environment           = local.environment
  project_name          = "${var.docker_project}"
  buildspec             = data.template_file.neo4j-image-buildspec.rendered
  ecr_list              = local.ecr_list
  owner_tag             = local.owner_tag
  pagerduty_email_tag   = local.pagerduty_email_tag
  ssm_param_list        = values(aws_ssm_parameter.ne4oj_image_digest).*.name
  environment_variables = [{ name = "CONTAINER_TAG", value = var.container_version }]
}

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.docker_project}-${local.environment}-codebuild-trigger"
  description         = "Schedule daily build of the ${var.docker_project}-${local.environment} codebuild project at 19:00 EST"
  schedule_expression = local.cron_expression
  tags                = local.default_tags
}

resource "aws_cloudwatch_event_target" "event_target" {
  rule     = aws_cloudwatch_event_rule.daily_trigger.name
  arn      = module.neo4j-image-codebuild.codebuild-project-arn
  role_arn = aws_iam_role.build_event_trigger_role.arn
}

resource "aws_cloudwatch_event_target" "codebuild_neo4j_image" {
  rule     = aws_cloudwatch_event_rule.daily_trigger.name
  arn      = module.neo4j-image-codebuild.codebuild-project-arn
  role_arn = aws_iam_role.build_event_trigger_role.arn
}

output "codebuild_project_name" {
  value = module.neo4j-image-codebuild.codebuild-project-name
}

output "codebuild_project_ssm_entry" {
  value = values(aws_ssm_parameter.ne4oj_image_digest).*.name
}
