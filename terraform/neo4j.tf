resource "aws_ecs_cluster" "neo4j" {
  name = var.project
}

resource "aws_ecs_task_definition" "neo4j" {
  family                   = "neo4j-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  task_role_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"
  cpu                      = 4096
  memory                   = 8192
  container_definitions    = <<DEFINITION
[
  {
    "portMappings": [
      {
        "hostPort": 7474,
        "protocol": "tcp",
        "containerPort": 7474
      },
      {
        "hostPort": 7687,
        "protocol": "tcp",
        "containerPort": 7687
      }
    ],
    "environment": [
      {
        "name": "NEO4J_dbms_security_auth__enabled",
        "value": "false"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "neo4j-services",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "neo4j"
      }
    },
    "image": "neo4j:latest",
    "name": "neo4j"
  }
]
DEFINITION
}

resource "aws_lb_target_group" "neo4j_web_tg" {
  name        = "neo4j-web-tg"
  port        = local.neo4j_web_port
  protocol    = "TCP"
  vpc_id      = local.vpc_id
  target_type = "ip"
  # slow_start  = 30
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = merge(
    local.default_tags,
    map(
      "Type", "private",
      "layer", "App"
    )
  )
}

resource "aws_lb_target_group" "neo4j_bolt_tg" {
  name        = "neo4j-bolt-tg"
  port        = local.neo4j_bolt_port
  protocol    = "TCP"
  vpc_id      = local.vpc_id
  target_type = "ip"
  tags = merge(
    local.default_tags,
    map(
      "Type", "private",
      "layer", "App"
    )
  )
}

resource "aws_cloudwatch_log_group" "neo4j-log-group" {
  name = "neo4j-services"

  tags = merge(
    local.default_tags,
    map(
      "Type", "private",
      "layer", "App"
    )
  )
}

resource "aws_ecs_service" "neo4j_ecs_service" {
  name          = "neo4j"
  cluster       = aws_ecs_cluster.neo4j.id
  desired_count = 1
  launch_type   = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.neo4j_sec_gp.id]
    subnets         = data.aws_subnet.app_group_subnets.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.neo4j_web_tg.id
    container_name   = "neo4j"
    container_port   = local.neo4j_web_port
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.neo4j_bolt_tg.id
    container_name   = "neo4j"
    container_port   = local.neo4j_bolt_port
  }

  # Track the latest ACTIVE revision
  task_definition = aws_ecs_task_definition.neo4j.arn
}

resource "aws_lb" "neo4j_nlb" {
  name                       = "neo4j-lb"
  load_balancer_type         = "network"
  subnets                    = data.aws_subnet.app_group_subnets.*.id
  enable_deletion_protection = true
  tags = merge(
    local.default_tags,
    map(
      "Type", "private",
      "layer", "App"
    )
  )
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.neo4j_nlb.arn
  port              = local.neo4j_web_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.neo4j_web_tg.arn
  }
}

# Bolt protocol thru the NLB
resource "aws_lb_listener" "bolt_listener" {
  load_balancer_arn = aws_lb.neo4j_nlb.arn
  port              = local.neo4j_bolt_port
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.neo4j_bolt_tg.arn
  }
}

resource "aws_route53_record" "neo4j_dns" {
  zone_id  = data.aws_route53_zone.qpp_hosted_zone.id
  name     = local.neo4j_uri
  type     = "CNAME"
  ttl      = "300"
  records  = [aws_lb.neo4j_nlb.dns_name]
  provider = aws.qppg
}
