import boto3
import json
import logging
from botocore.exceptions import ClientError
from time import gmtime, strftime

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.INFO)

def set_desirecount():
    desiredCount = 0
    period = strftime("%p", gmtime())
    if period == 'AM':
        desiredCount = 1
    return desiredCount

def lambda_handler(event, context):
    try:
        session = boto3.Session()
        client = boto3.client('application-autoscaling')
        capacity = set_desirecount()
        response = client.register_scalable_target(
            ServiceNamespace = 'ecs',
            ResourceId = 'service/neo4j-infra/neo4j',
            ScalableDimension='ecs:service:DesiredCount',
            MinCapacity=capacity,
            MaxCapacity=capacity
        )
        LOGGER.info(response)
        output = "Successfully set desired count to {}".format(capacity)
        LOGGER.info(output)
        return {
            'statusCode': 200,
            'body': json.dumps(output)
        }


    except (ClientError, SyntaxError) as ex:
        LOGGER.error(ex)
        return {
            'statusCode': 404,
            'body': json.dumps(ex)
        }
