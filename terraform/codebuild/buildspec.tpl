version: 0.2
env:
  variables:
    DJANGO_REPO_NAME: "defectdojo-django"
    NGINX_REPO_NAME: "defectdojo-nginx"
phases:
  install:
    runtime-versions:
      python: 3.8
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)
      - pip install -r requirements.txt
  build:
    commands:
      - echo Build reports `date`
    commands:
      - echo `date`
