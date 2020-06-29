{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:StartBuild"
            ],
            "Resource": [
                "arn:aws:codebuild:${region}:${account_id}:project/${docker-project}",
                "arn:aws:codebuild:${region}:${account_id}:project/${infra-project}"
            ]
        }
    ]
}
