#!/usr/bin/env python3
import argparse
import boto3
import jinja2
import os
from botocore.exceptions import ClientError

REGION = 'us-east-1'
subnets_ids = list()
sg_ids = list()
client = boto3.client('ec2')

TEMPLATE_FILE = "ecs-params.yml.j2"
RENDERED_FILE = "ecs-params.yml"

script_path = os.path.dirname(os.path.abspath(__file__))
template_file_path = os.path.join(script_path, TEMPLATE_FILE)
rendered_file_path = os.path.join(script_path, RENDERED_FILE)

parser = argparse.ArgumentParser(description="Deploy Neo4j to Fargate")
parser.add_argument("--stage", default="impl", help="dev,dev-pre,impl,prod")
args = parser.parse_args()

session = boto3.Session(region_name=REGION)
ssm = session.client('ssm')
parameter_path = os.path.join('/Neo4j', (args.stage).lower())
p = ssm.get_parameters_by_path(Path=parameter_path, WithDecryption=True)

# Get VPC id
regex = ["*{}*".format(args.stage)]
try:
    vpcs = client.describe_vpcs(
        Filters=[
            {
                'Name': 'tag:Name',
                'Values': regex
            }
        ]
    )
except ClientError as e:
    print(e)

vpc_id = vpcs['Vpcs'][0]['VpcId']

# Get subnet ids
try:
    subnets = client.describe_subnets(Filters=[
            {
                'Name': 'vpc-id',
                'Values': [vpc_id]
            },
            {
                'Name': 'tag:Name',
                'Values': ['*app*']
            }

        ]
    )
except ClientError as e:
    print(e)

for i in range(len(subnets['Subnets'])):
    subnets_ids.append(subnets['Subnets'][i]['SubnetId'])

# Get security group id(s)
sg_name = ("neo4j")
try:
    sgs = client.describe_security_groups(Filters=[
            {
                'Name': 'group-name',
                'Values': [sg_name]
            },
            {
                'Name': 'vpc-id',
                'Values': [vpc_id]
            }
        ]
    )
except ClientError as e:
    print(e)

for i in range(len(sgs['SecurityGroups'])):
    sg_ids.append(sgs['SecurityGroups'][i]['GroupId'])

# Create the ecs-params.yml
environment = jinja2.Environment(loader=jinja2.FileSystemLoader(script_path))
output_text = environment.get_template(TEMPLATE_FILE).render(ids=subnets_ids, sg_ids=sg_ids)
with open(rendered_file_path, "w") as result_file:
    result_file.write(output_text)
