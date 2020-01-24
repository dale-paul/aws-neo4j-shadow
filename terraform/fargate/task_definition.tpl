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
    "image": "neo4j:latest",
    "privileged": false,
    "name": "neo4j"
    "memory": "8192",
    "taskRoleArn": null,
    "compatibilities": [
      "EC2",
      "FARGATE"
    ],
    "requiresCompatibilities": [
      "FARGATE"
    ],
    "networkMode": "awsvpc",
    "cpu": "4096"
    }
]
