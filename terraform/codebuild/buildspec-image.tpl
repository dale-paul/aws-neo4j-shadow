version: 0.2
env:
  variables:
    REPO_NAME: neo4j
    CONTAINER_TAG: 4.0
phases:
  install:
    runtime-versions:
      python: 3.8
    commands:
      - nohup /usr/local/bin/dockerd --host=unix:///var/run/docker.sock --host=tcp://127.0.0.1:2375 --storage-driver=overlay2 &>/var/log/docker.log &
      - timeout 15 sh -c "until docker info; do echo .; sleep 1; done"
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
  build:
    commands:
      - echo Get the Neo4j image from the Docker registry
      - LATEST_DIGEST=$(wget -q https://registry.hub.docker.com/v2/repositories/library/neo4j/tags/$CONTAINER_TAG -O - | jq -r '.images[].digest')
      - CURRENT_DIGEST=$(aws ssm get-parameter --name '/neo4j/production/image-digest' | jq -r '.Parameter.Value')
      - |
          if [ "$LATEST_DIGEST" != "$CURRENT_DIGEST" ]; then
            docker pull $REPO_NAME:$CONTAINER_TAG
            docker tag $REPO_NAME:$CONTAINER_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$REPO_NAME:$CONTAINER_TAG
            docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$REPO_NAME:$CONTAINER_TAG
            aws ssm put-parameter --name "/neo4j/production/image-digest" --value "$LATEST_DIGEST" --type "String" --overwrite
          fi
