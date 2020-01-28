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
      - printenv > .env
  build:
    commands:
      - echo Build reports
      - #./IAMPolicy-audit.py --account-number ${accounts}
      - ./IAMPolicy-audit.py --account-number  863249929524 941681414890
          --role-name neo4j-iam-audit-role
          --log-level WARNING
          --max-threads 8
          --neo4j
          -o $AUDIT_RESULTS
artifacts:
  files:
    - $AUDIT_RESULTS
