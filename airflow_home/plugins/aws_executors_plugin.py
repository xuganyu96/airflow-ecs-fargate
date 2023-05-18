from airflow.plugins_manager import AirflowPlugin
from airflow_aws_executors import AwsBatchExecutor, AwsEcsFargateExecutor


class AwsExecutorsPlugin(AirflowPlugin):
    """AWS Batch & AWS ECS & AWS FARGATE Plugin"""
    name = "aws_executors_plugin"
    executors = [AwsBatchExecutor, AwsEcsFargateExecutor]
