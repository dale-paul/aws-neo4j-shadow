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
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}
