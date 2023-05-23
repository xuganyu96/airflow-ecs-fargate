#!/bin/bash

export RDS_SECRET_ID="airflow_rds_conn"
export RDS_SECRET_STR=$(aws secretsmanager get-secret-value --secret-id ${RDS_SECRET_ID} --query "SecretString")
export RDS_HOST=$(echo ${RDS_SECRET_STR} | jq -r ". | fromjson | .host")
export RDS_PORT=$(echo ${RDS_SECRET_STR} | jq -r ". | fromjson | .port")
export RDS_USER=$(echo ${RDS_SECRET_STR} | jq -r ". | fromjson | .login")
export RDS_PASSWORD=$(echo ${RDS_SECRET_STR} | jq -r ". | fromjson | .password")

export AIRFLOW_CONFIG_SECRET_ID="airflow_config"
export AIRFLOW_CONFIG_SECRET_STR=$(
    aws secretsmanager get-secret-value \
    --secret-id ${AIRFLOW_CONFIG_SECRET_ID} \
    --query "SecretString")

export AIRFLOW__CORE__EXECUTOR="aws_executors_plugin.AwsEcsFargateExecutor"
export AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION="True"
export AIRFLOW__CORE__LOAD_EXAMPLES="False"
export AIRFLOW__CORE__PARALLELISM="4"
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${RDS_USER}:${RDS_PASSWORD}@${RDS_HOST}:${RDS_PORT}/airflow"
export AIRFLOW__DATABASE__LOAD_DEFAULT_CONNECTIONS="False"
export AIRFLOW__LOGGING__LOGGING_CONFIG_CLASS="log_config.LOG_CONFIG"
export AIRFLOW__LOGGING__REMOTE_LOGGING="True"
export AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER=$(
    echo ${AIRFLOW_CONFIG_SECRET_STR} | jq -r ". | fromjson | logging__remote_base_log_folder")
export AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID="remote_log_s3"
export AIRFLOW__LOGGING__ENCRYPT_S3_LOG="False"
export AIRFLOW__ECS_FARGATE__REGION="us-west-2"
export AIRFLOW__ECS_FARGATE__CLUSTER="wind-farm"
export AIRFLOW__ECS_FARGATE__CONTAINER_NAME="worker"
export AIRFLOW__ECS_FARGATE__TASK_DEFINITION="airflow-worker"
export AIRFLOW__ECS_FARGATE__SECURITY_GROUPS=$(
    echo ${AIRFLOW_CONFIG_SECRET_STR} | jq -r ". | fromjson | ecs_fargate__security_groups")
export AIRFLOW__ECS_FARGATE__SUBNETS=$(
    echo ${AIRFLOW_CONFIG_SECRET_STR} | jq -r ". | fromjson | ecs_fargate__subnets")
export AIRFLOW__ECS_FARGATE__ASSIGN_PUBLIC_IP="ENABLED"
export AIRFLOW__ECS_FARGATE__LAUNCH_TYPE="FARGATE"

/entrypoint "${@}"
