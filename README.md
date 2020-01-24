# AWS_Neo4j_Shadow
Dump AWS Schemas into Neo4j


## Provisioning the Neo4j Docker container
Run the Terraform configuration to create the cluster and security group
```sh
cd terraform
terraform apply
```
Deploy the container in the cluster
```sh
./deploy.py --stage impl
ecs-cli configure --cluster neo4j-infra --default-launch-type FARGATE --config-name neo4j --region us-east-1
ecs-cli compose --project-name neo4j service up --create-log-groups --cluster-config neo4j
```
