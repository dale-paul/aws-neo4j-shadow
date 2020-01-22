provider "aws" {
  region = local.region
}

resource "aws_iam_role" "codebuild_neo4j_role" {
  name               = "codebuild-neo4j-service-role"
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

resource "aws_iam_role_policy" "codebuild_base_policy" {
  name   = "CodeBuildBasePolicy-neo4j-${local.region}"
  policy = data.template_file.codebuild_base_policy.rendered
  role   = aws_iam_role.codebuild_neo4j_role.id
}

resource "aws_iam_role_policy" "codebuild_cloudwatch_policy" {
  name   = "CodeBuildCloudWatchLogsPolicy-neo4j-${local.region}"
  policy = data.template_file.codebuild_cloudwatch_policy.rendered
  role   = aws_iam_role.codebuild_neo4j_role.id
}

resource "aws_codebuild_project" "neo4j_build" {
  name          = var.project
  build_timeout = 10
  badge_enabled = true
  service_role  = aws_iam_role.codebuild_neo4j_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  source {
    type                = "GITHUB_ENTERPRISE"
    location            = "https://github.cms.gov/qpp/AWS_Neo4j_Shadow"
    git_clone_depth     = 1
    report_build_status = true
    insecure_ssl        = false
    buildspec           = data.template_file.neo4j-buildspec.rendered
  }

  environment {
    compute_type                = local.compute_type
    image                       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.custom_compute_image}"
    image_pull_credentials_type = "SERVICE_ROLE"
    privileged_mode             = true
    type                        = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild"
      stream_name = "${var.project}-build"
    }
  }

  tags = local.default_tags
}
