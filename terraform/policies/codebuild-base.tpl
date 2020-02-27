{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:logs:${region}:${account_id}:log-group:/aws/codebuild/neo4j-build",
                "arn:aws:logs:${region}:${account_id}:log-group:/aws/codebuild/neo4j-build:*"
            ],
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::codepipeline-${region}*",
                "arn:aws:s3:::${codebuild-artifacts-bucket}/*"
            ],
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ]
        },
        {
            "Action": [
              "events:*",
              "iam:PassRole",
              "ec2:CreateNetworkInterface",
              "ec2:DescribeDhcpOptions",
              "ec2:DescribeNetworkInterfaces",
              "ec2:DeleteNetworkInterface",
              "ec2:DescribeSubnets",
              "ec2:DescribeSecurityGroups",
              "ec2:DescribeVpcs"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterfacePermission"
            ],
            "Resource": "arn:aws:ec2:${region}:${account_id}:network-interface/*",
            "Condition": {
                "StringEquals": {
                    "ec2:Subnet": [
                        "arn:aws:ec2:${region}:${account_id}:subnet/${subnet}"
                    ],
                    "ec2:AuthorizedService": "codebuild.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:CreateReportGroup",
                "codebuild:CreateReport",
                "codebuild:UpdateReport",
                "codebuild:BatchPutTestCases"
            ],
            "Resource": [
                "arn:aws:codebuild:${region}:${account_id}:report-group/neo4j-build*"
            ]
        },
        {
            "Effect": "Allow",
            "Action":[
              "sts:AssumeRole"
            ],
            "Resource": [
                "arn:aws:iam::${account_id}:role/neo4j-iam-audit-role"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": [
                "arn:aws:ssm:*:${account_id}:parameter/ldap/prod/*",
                "arn:aws:ssm:*:${account_id}:parameter/accounts/qpp/*"
            ]
        }
    ]
}
