import sys
import json
import boto3
from helpers import getenv_or_exit, get_rds_endpoint, generate_task_definition

if __name__ == "__main__":
    session = boto3.Session()
    aws_account_id = getenv_or_exit("AWS_ACCOUNT_ID")
    image_tag = getenv_or_exit("IMAGE_TAG")
    aws_region = getenv_or_exit("AWS_REGION")
    image_uri = f"{aws_account_id}.dkr.ecr.{aws_region}.amazonaws.com/airflow:{image_tag}"
    rds_instance_id = getenv_or_exit("RDS_INSTANCE_ID")
    rds_endpoint = get_rds_endpoint(rds_instance_id, session.client("rds"))
    if rds_endpoint is None:
        print(f"RDS {rds_instance_id} is not ready", file=sys.stderr)
        exit(1)

    task_definition = generate_task_definition(
        image_uri,
        aws_account_id,
        airflow_rds_user=getenv_or_exit("AIRFLOW_RDS_USER"),
        airflow_rds_password=getenv_or_exit("AIRFLOW_RDS_PASSWORD"),
        airflow_rds_db="airflow",
        rds_endpoint=rds_endpoint,
    )
    print(json.dumps(task_definition))
