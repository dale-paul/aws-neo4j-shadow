version: 0.2
env:
  variables:
    REPO_NAME: neo4j
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
      - docker pull neo4j:latest
      - echo get the image digest
      - LATEST_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' neo4j:latest)
      - CURRENT_DIGEST=$(aws ssm get-parameter --name '/neo4j/production/image-digest' --query Parameter.Value)
      - |
          if [ "$LATEST_DIGEST" != "$CURRENT_DIGEST" ]; then
            aws ssm put-parameter --name "/neo4j/production/image-digest" --value "$LATEST_DIGEST" --type "String" --overwrite
            docker tag $REPO_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$REPO_NAME:$CODEBUILD_BUILD_NUMBER
            docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$REPO_NAME:$CODEBUILD_BUILD_NUMBER
            MANIFEST=$(aws ecr batch-get-image --repository-name $REPO_NAME --image-ids imageTag=$CODEBUILD_BUILD_NUMBER --query 'images[].imageManifest' --output text)
            aws ecr put-image --repository-name $REPO_NAME --image-tag latest --image-manifest "$MANIFEST"
          fi
