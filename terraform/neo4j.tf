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

resource "aws_lb_target_group" "neo4j_tg" {
  name     = "neo4j-tg"
  port     = local.neo4j_web_port
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 30
    matcher             = "200"
    path                = "/browser"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  tags = merge(
    local.default_tags,
    map(
      "Type", "private",
      "layer", "App"
    )
  )
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
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  ingress {
    from_port   = local.neo4j_web_port
    to_port     = local.neo4j_web_port
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  ingress {
    from_port   = local.neo4j_bolt_port
    to_port     = local.neo4j_bolt_port
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

#  load_balancer {
#    target_group_arn = aws_lb_target_group.neo4j_tg.arn
#    container_name   = "neo4j"
#    container_port   = local.neo4j_web_port
#  }

  # Track the latest ACTIVE revision
  task_definition = aws_ecs_task_definition.neo4j.arn
  # task_definition = "${aws_ecs_task_definition.neo4j.family}:${max("${aws_ecs_task_definition.neo4j.revision}", "${data.aws_ecs_task_definition.neo4j.revision}")}"
}

# resource "aws_ecs_service" "neo4j_ecs_service" {
#   name            = "neo4j"
#   cluster         = aws_ecs_cluster.neo4j.id
#   task_definition = aws_ecs_task_definition.neo4j.arn
#   desired_count   = 1
#
#   load_balancer {
#     target_group_arn = aws_lb_target_group.neo4j_tg.arn
#     container_name   = "neo4j"
#     container_port   = local.neo4j_web_port
#   }
# }


resource "aws_lb" "neo4j_alb" {
  name                       = "neo4j-lb"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.neo4j_sec_gp.id]
  ip_address_type            = "ipv4"
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

resource "aws_lb_listener" "neo4j_lb_https_listener" {
  load_balancer_arn = aws_lb.neo4j_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-2019-08"
  certificate_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:server-certificate/${var.cert_name}"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.neo4j_tg.arn
  }
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "neo4j_lb_http_listener" {
  load_balancer_arn = aws_lb.neo4j_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_302"
    }
  }
}

#resource "aws_route53_record" "neo4j_dns" {
#  zone_id  = data.aws_route53_zone.qpp_hosted_zone.id
#  name     = "neo4j.qpp.internal"
#  type     = "CNAME"
#  ttl      = "300"
#  records  = [aws_lb.neo4j_alb.dns_name]
#  provider = aws.qppg
#}
