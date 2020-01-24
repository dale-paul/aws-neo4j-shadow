version: 0.2
env:
  variables:
    AUDIT_RESULTS: "audit-results.json"
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
      - echo Build reports
      -  echo "NEO4J_URI='bolt://localhost:7687'"> .env
      - ./IAMPolicy-audit.py --role-name QPPMGMTRole --log-level INFO --max-threads 8 -o $AUDIT_RESULTS
artifacts:
  files:
    - $AUDIT_RESULTS
  # name: $Env:TEST_ENV_VARIABLE-$(Get-Date -UFormat "%Y%m%d-%H%M%S")
