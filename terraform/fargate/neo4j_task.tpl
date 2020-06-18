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
      },
      {
        "name": "NEO4J_dbms_connector_bolt_advertised__address",
        "value": "${bolt_advertised_address}:${bolt_port}"
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
    "image": "${image}",
    "name": "neo4j"
  }
]
