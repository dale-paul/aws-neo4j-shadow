[
  {
    "portMappings": [
      {
        "hostPort": ${http_port},
        "protocol": "tcp",
        "containerPort": ${http_port}
      },
      {
        "hostPort": ${bolt_port},
        "protocol": "tcp",
        "containerPort": ${bolt_port}
      }
    ],
    "environment": [
      {
        "name": "NEO4J_dbms_security_auth__enabled",
        "value": "${auth_enabled}"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "neo4j-services",
        "awslogs-region": "${region}",
        "awslogs-stream-prefix": "neo4j"
      }
    },
    "image": "neo4j:${container_version}",
    "name": "neo4j"
  }
]
