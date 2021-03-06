provider "aws" {
  region = local.region
}

provider "aws" {
  alias  = "qppg"
  region = local.region
  assume_role {
    role_arn = "arn:aws:iam::${data.aws_ssm_parameter.qppg_account.value}:role/tf-devops-role"
  }
}

resource "aws_security_group" "neo4j_sec_gp" {
  name        = "neo4j"
  description = "Control traffic to/from the neo4j Fargate cluster"
  vpc_id      = local.vpc_id
  tags        = local.default_tags

  ingress {
    from_port   = local.neo4j_web_port
    to_port     = local.neo4j_web_port
    protocol    = "tcp"
    cidr_blocks = data.aws_subnet.app_group_subnets.*.cidr_block
  }

  ingress {
    from_port   = local.neo4j_bolt_port
    to_port     = local.neo4j_bolt_port
    protocol    = "tcp"
    cidr_blocks = data.aws_subnet.app_group_subnets.*.cidr_block
  }

  ingress {
    from_port = local.neo4j_web_port
    to_port   = local.neo4j_web_port
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  ingress {
    from_port = local.neo4j_bolt_port
    to_port   = local.neo4j_bolt_port
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_iam_role" "codebuild_neo4j_role" {
  name               = "codebuild-neo4j-service-role"
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.codebuild-assume-role-policy.json
}

resource "aws_iam_role" "build_event_trigger_role" {
  name               = "codebuild-neo4j-trigger-role"
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.events-assume-role-policy.json
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRole-neo4j"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
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

resource "aws_iam_role_policy" "codebuild_crossaccount_policy" {
  name   = "neo4j-assume-role-inline-policy"
  policy = data.aws_iam_policy_document.codebuild_crossaccount_policy.json
  role   = aws_iam_role.codebuild_neo4j_role.id
}

resource "aws_iam_role_policy" "ecs_task_execution_policy" {
  name   = "ecsTaskExecutionRole-neo4j-policy"
  policy = data.template_file.ecs_task_execution_policy.rendered
  role   = aws_iam_role.ecs_task_execution_role.id
}

resource "aws_kms_key" "neo4j-kms-key" {
  description             = "This key is used to encrypt neo4j bucket objects"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = local.default_tags
}

resource "aws_s3_bucket" "bucket" {
  bucket = local.bucket-name
  acl    = "private"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.neo4j-kms-key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  tags = local.default_tags
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_codebuild_project" "neo4j_build" {
  name           = var.project
  build_timeout  = 60
  badge_enabled  = true
  service_role   = aws_iam_role.codebuild_neo4j_role.arn
  source_version = local.source_version

  artifacts {
    type     = "S3"
    location = local.bucket-name
    name     = "IAM_SHADOW"
    # namespace_type = "BUILD_ID"
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

    environment_variable {
      name  = "NEO4J_URI"
      type  = "PLAINTEXT"
      value = "bolt://${local.neo4j_uri}:${local.neo4j_bolt_port}"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild"
      stream_name = "${var.project}-build"
    }
  }

  vpc_config {
    vpc_id  = local.vpc_id
    subnets = [tolist(data.aws_subnet_ids.app_subnets.ids)[0]]


    security_group_ids = [
      aws_security_group.neo4j_sec_gp.id
    ]
  }
  tags = local.default_tags
}

resource "aws_cloudwatch_event_rule" "nightly_trigger" {
  name                = "${var.project}-codebuild-trigger"
  description         = "Schedule daily build of the ${var.project} codebuild project at 19:00 EST"
  schedule_expression = local.cron_expression
  tags                = local.default_tags
}

resource "aws_cloudwatch_event_target" "codebuild" {
  rule      = aws_cloudwatch_event_rule.nightly_trigger.name
  target_id = "TriggerCodeBuild"
  arn       = aws_codebuild_project.neo4j_build.arn
  role_arn  = aws_iam_role.build_event_trigger_role.arn
}

resource "aws_iam_role_policy" "codebuild_trigger_policy" {
  name   = "Invoke_CodeBuild_Neo4j"
  role   = aws_iam_role.build_event_trigger_role.id
  policy = data.template_file.codebuild_trigger_policy.rendered
}

resource "aws_iam_role_policy" "codebuild_ecr_policy" {
  name   = "CodeBuildECSPolicy-neo4j-${local.region}"
  policy = file("policies/codebuild-ecr.json")
  role   = aws_iam_role.codebuild_neo4j_role.id
}
