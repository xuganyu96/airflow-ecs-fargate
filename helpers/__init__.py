import os
import sys

def getenv_or_exit(name: str):
    val = os.getenv(name, None)
    if val is None:
        print(f"Missing environment variable {name}", file=sys.stderr)
        exit(1)
    return val

def list_tasks(cluster_name: str, ecs) -> list[str]:
    """Return a list of Task Arns
    """
    resp = ecs.list_tasks(cluster=cluster_name)
    return resp["taskArns"]

def tasks_all_stopped(cluster_name: str, task_arns: list[str], ecs) -> bool:
    """Return true if the input task has stopped
    """
    if len(task_arns) == 0:
        return True
    resp = ecs.describe_tasks(
        cluster=cluster_name,
        tasks=task_arns,
    )
    task_statuses = [t["lastStatus"] for t in resp["tasks"]]
    return all([s == "STOPPED" for s in task_statuses])

def list_subnet_ids(vpc_id, ec2):
    """Return the IDs of the subnets associated with the input VPC
    """
    resp = ec2.describe_subnets(
        Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
    )
    return [sn["SubnetId"] for sn in resp["Subnets"]]


def generate_network_config(
    ecs_security_group: str,
    subnet_ids: list[str],
):
    return {
        "awsvpcConfiguration": {
            "subnets": subnet_ids,
            "securityGroups": [ecs_security_group],
            "assignPublicIp": "ENABLED"
        }
    }

def get_rds_endpoint(rds_instance_id: str, rds) -> str | None:
    """Given an RDS client, return the endpoint of the RDS instance. If the
    instance exists but does not have an endpoint, return None. If the instance
    does not exist, let the boto3 client throw a DBInstanceNotFoundFault

    :param rds: boto3.session.client("rds")
    """
    resp = rds.describe_db_instances(DBInstanceIdentifier=rds_instance_id)
    db_instance = resp["DBInstances"][0]
    if "Endpoint" in db_instance:
        return db_instance["Endpoint"]["Address"]
    return None

def generate_airflow_core_task_def(
    image_uri: str,
    aws_account_id: str,
    airflow_rds_user: str,
    airflow_rds_password: str,
    airflow_rds_db: str,
    rds_endpoint: str,
    subnet_ids: list[str],
):
    """Return a dictionary that defines the task definition for the Airflow
    cluster
    """
    sqla_uri = f"postgresql+psycopg2://" \
    f"{airflow_rds_user}:{airflow_rds_password}" \
    f"@{rds_endpoint}:5432/{airflow_rds_db}"
    remote_logging_bucket = getenv_or_exit("REMOTE_LOGGING_BUCKET")
    remote_logging_conn_id = getenv_or_exit("REMOTE_LOGGING_CONN_ID")
    ecs_task_role = getenv_or_exit("ECS_TASK_ROLE")

    env_vars = [
        {
            "name": "AIRFLOW__CORE__EXECUTOR",
            "value": "aws_executors_plugin.AwsEcsFargateExecutor"
        },
        {
            "name": "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION",
            "value": "true"
        },
        {
            "name": "AIRFLOW__CORE__LOAD_EXAMPLES",
            "value": "false"
        },
        {
            "name": "AIRFLOW__CORE__PARALLELISM",
            "value": "4"
        },
        {
            "name": "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN",
            "value": sqla_uri
        },
        {
            "name": "AIRFLOW__DATABASE__LOAD_DEFAULT_CONNECTIONS",
            "value": "false"
        },
        {
            "name": "AIRFLOW__LOGGING__LOGGING_CONFIG_CLASS",
            "value": "log_config.LOG_CONFIG",
        },
        {
            "name": "AIRFLOW__LOGGING__REMOTE_LOGGING",
            "value": "True",
        },
        {
            "name": "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER",
            "value": f"s3://{remote_logging_bucket}/stage_airflow",
        },
        {
            "name": "AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID",
            "value": remote_logging_conn_id,
        },
        {
            "name": "AIRFLOW__LOGGING__ENCRYPT_S3_LOG",
            "value": "False",
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__REGION",
            "value": getenv_or_exit("AWS_REGION"),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__CLUSTER",
            "value": getenv_or_exit("ECS_CLUSTER_NAME"),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__CONTAINER_NAME",
            "value": "worker",
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__TASK_DEFINITION",
            "value": getenv_or_exit("AIRFLOW_WORKER_TASK_DEF"),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__SECURITY_GROUPS",
            "value": getenv_or_exit("ECS_SG_ID"),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__SUBNETS",
            "value": ",".join(subnet_ids),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__ASSIGN_PUBLIC_IP",
            "value": "ENABLED",
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__LAUNCH_TYPE",
            "value": "FARGATE",
        },

    ]

    return {
        "family": getenv_or_exit("AIRFLOW_CORE_TASK_DEF"),
        "containerDefinitions": [
            {
                "name": "webserver",
                "image": image_uri,
                "cpu": 0,
                "portMappings": [
                    {
                        "containerPort": 8080,
                        "hostPort": 8080,
                        "protocol": "tcp",
                    }
                ],
                "essential": True,
                "command": [
                    "webserver"
                ],
                "environment": env_vars,
                "environmentFiles": [],
                "mountPoints": [],
                "volumesFrom": [],
                "ulimits": [],
                "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                        "awslogs-group": getenv_or_exit("ECS_LOG_GROUP"),
                        "awslogs-create-group": "true",
                        "awslogs-region": getenv_or_exit("AWS_REGION"),
                        "awslogs-stream-prefix": "ecs"
                    }
                }
            },
            {
                "name": "scheduler",
                "image": image_uri,
                "cpu": 0,
                "portMappings": [],
                "essential": True,
                "command": [
                    "scheduler"
                ],
                "environment": env_vars,
                "environmentFiles": [],
                "mountPoints": [],
                "volumesFrom": [],
                "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                        "awslogs-group": getenv_or_exit("ECS_LOG_GROUP"),
                        "awslogs-create-group": "true",
                        "awslogs-region": getenv_or_exit("AWS_REGION"),
                        "awslogs-stream-prefix": "ecs"
                    }
                }
            }
        ],
        "taskRoleArn": f"arn:aws:iam::{aws_account_id}:role/{ecs_task_role}",
        "executionRoleArn": f"arn:aws:iam::{aws_account_id}:role/{ecs_task_role}",
        "networkMode": "awsvpc",
        "requiresCompatibilities": [
            "FARGATE"
        ],
        "cpu": "1024",
        "memory": "8192",
        "runtimePlatform": {
            "cpuArchitecture": "X86_64",
            "operatingSystemFamily": "LINUX"
        }
    }

def generate_airflow_worker_task_def(
    image_uri: str,
    aws_account_id: str,
    airflow_rds_user: str,
    airflow_rds_password: str,
    airflow_rds_db: str,
    rds_endpoint: str,
    subnet_ids: list[str],
):
    """Return a dictionary that defines the task definition for the Airflow
    cluster
    """
    sqla_uri = f"postgresql+psycopg2://" \
    f"{airflow_rds_user}:{airflow_rds_password}" \
    f"@{rds_endpoint}:5432/{airflow_rds_db}"
    remote_logging_bucket = getenv_or_exit("REMOTE_LOGGING_BUCKET")
    remote_logging_conn_id = getenv_or_exit("REMOTE_LOGGING_CONN_ID")
    ecs_task_role = getenv_or_exit("ECS_TASK_ROLE")

    env_vars = [
        {
            "name": "AIRFLOW__CORE__EXECUTOR",
            "value": "aws_executors_plugin.AwsEcsFargateExecutor"
        },
        {
            "name": "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION",
            "value": "true"
        },
        {
            "name": "AIRFLOW__CORE__LOAD_EXAMPLES",
            "value": "false"
        },
        {
            "name": "AIRFLOW__CORE__PARALLELISM",
            "value": "4"
        },
        {
            "name": "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN",
            "value": sqla_uri
        },
        {
            "name": "AIRFLOW__DATABASE__LOAD_DEFAULT_CONNECTIONS",
            "value": "false"
        },
        {
            "name": "AIRFLOW__LOGGING__LOGGING_CONFIG_CLASS",
            "value": "log_config.LOG_CONFIG",
        },
        {
            "name": "AIRFLOW__LOGGING__REMOTE_LOGGING",
            "value": "True",
        },
        {
            "name": "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER",
            "value": f"s3://{remote_logging_bucket}/stage_airflow",
        },
        {
            "name": "AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID",
            "value": remote_logging_conn_id,
        },
        {
            "name": "AIRFLOW__LOGGING__ENCRYPT_S3_LOG",
            "value": "False",
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__REGION",
            "value": getenv_or_exit("AWS_REGION"),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__CLUSTER",
            "value": getenv_or_exit("ECS_CLUSTER_NAME"),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__CONTAINER_NAME",
            "value": "worker",
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__TASK_DEFINITION",
            "value": getenv_or_exit("AIRFLOW_WORKER_TASK_DEF"),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__SECURITY_GROUPS",
            "value": getenv_or_exit("ECS_SG_ID"),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__SUBNETS",
            "value": ",".join(subnet_ids),
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__ASSIGN_PUBLIC_IP",
            "value": "ENABLED",
        },
        {
            "name": "AIRFLOW__ECS_FARGATE__LAUNCH_TYPE",
            "value": "FARGATE",
        },
    ]

    return {
        "family": getenv_or_exit("AIRFLOW_WORKER_TASK_DEF"),
        "containerDefinitions": [
            {
                "name": "worker",
                "image": image_uri,
                "cpu": 0,
                "portMappings": [],
                "essential": True,
                "command": [
                    "scheduler"
                ],
                "environment": env_vars,
                "environmentFiles": [],
                "mountPoints": [],
                "volumesFrom": [],
                "logConfiguration": {
                    "logDriver": "awslogs",
                    "options": {
                        "awslogs-group": getenv_or_exit("ECS_LOG_GROUP"),
                        "awslogs-create-group": "true",
                        "awslogs-region": getenv_or_exit("AWS_REGION"),
                        "awslogs-stream-prefix": "ecs"
                    }
                }
            }
        ],
        "taskRoleArn": f"arn:aws:iam::{aws_account_id}:role/{ecs_task_role}",
        "executionRoleArn": f"arn:aws:iam::{aws_account_id}:role/{ecs_task_role}",
        "networkMode": "awsvpc",
        "requiresCompatibilities": [
            "FARGATE"
        ],
        "cpu": "1024",
        "memory": "8192",
        "runtimePlatform": {
            "cpuArchitecture": "X86_64",
            "operatingSystemFamily": "LINUX"
        }
    }
