"""Generate a JSON for network configurations
"""
from helpers import getenv_or_exit, list_subnet_ids, generate_network_config
import json
import boto3

if __name__ == "__main__":
    session = boto3.Session()
    vpc_id = getenv_or_exit("VPC_ID")
    ecs_security_group = getenv_or_exit("ECS_SG_ID")
    
    subnet_ids = list_subnet_ids(vpc_id, session.client("ec2"))

    network_config = generate_network_config(ecs_security_group, subnet_ids)
    print(json.dumps(network_config))
