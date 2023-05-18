#!/bin/bash

# Globally required variables
if [[ -z $AWS_ACCOUNT_ID ]]; then
    echo "Please set AWS_ACCOUNT_ID"
    exit 1
fi
if [[ -z $AWS_REGION ]]; then
    echo "Please set AWS_REGION"
    exit 1
fi
if [[ -z $ECR_REPO_NAME ]]; then
    echo "Please set ECR_REPO_NAME"
    exit 1
fi
if [[ -z $IMAGE_TAG ]]; then
    echo "Please set IMAGE_TAG"
    exit 1
fi
if [[ -z $RDS_SG_ID ]]; then
    echo "Please set RDS_SG_ID"
    exit 1
fi
if [[ -z $ECS_SG_ID ]]; then
    echo "Please set ECS_SG_ID"
    exit 1
fi
if [[ -z $RDS_INSTANCE_ID ]]; then
    echo "Please set RDS_INSTANCE_ID"
    exit 1
fi
if [[ -z $AIRFLOW_RDS_USER ]]; then
    echo "Please set AIRFLOW_RDS_USER"
    exit 1
fi
if [[ -z $AIRFLOW_RDS_PASSWORD ]]; then
    echo "Please set AIRFLOW_RDS_PASSWORD"
    exit 1
fi
if [[ -z $ECS_CLUSTER_NAME ]]; then
    echo "Please set ECS_CLUSTER_NAME"
    exit 1
fi
if [[ -z $ECS_LOG_GROUP ]]; then
    echo "Please set ECS_LOG_GROUP"
    exit 1
fi
if [[ -z $REMOTE_LOGGING_BUCKET ]]; then
    echo "Please set REMOTE_LOGGING_BUCKET"
    exit 1
fi
if [[ -z $REMOTE_LOGGING_CONN_ID ]]; then
    echo "Please set REMOTE_LOGGING_CONN_ID"
    exit 1
fi
if [[ -z $ECS_TASK_ROLE ]]; then
    echo "Please set ECS_TASK_ROLE"
    exit 1
fi
if [[ -z $AIRFLOW_CORE_TASK_DEF ]]; then
    echo "Please set AIRFLOW_CORE_TASK_DEF"
    exit 1
fi
if [[ -z $AIRFLOW_WORKER_TASK_DEF ]]; then
    echo "Please set AIRFLOW_WORKER_TASK_DEF"
    exit 1
fi

case $1 in
"create-ecr-repository")
    aws ecr create-repository --repository-name "${ECR_REPO_NAME}"
;;
"deploy-docker-image")
    REGISTRY_URL=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    aws ecr get-login-password --region ${AWS_REGION} \
    | docker login --username AWS --password-stdin ${REGISTRY_URL}
    docker build -t ${REGISTRY_URL}/${ECR_REPO_NAME}:${IMAGE_TAG} .
    docker push ${REGISTRY_URL}/${ECR_REPO_NAME}:${IMAGE_TAG}
;;
"delete-ecr-repository")
    aws ecr delete-repository --repository-name ${ECR_REPO_NAME} --force
;;
"create-rds-instance")
    aws rds create-db-instance --db-instance-identifier ${RDS_INSTANCE_ID} \
    --db-name "airflow" \
    --db-instance-class "db.t4g.micro" \
    --engine postgres \
    --master-username ${AIRFLOW_RDS_USER} \
    --master-user-password ${AIRFLOW_RDS_PASSWORD} \
    --allocated-storage 10 \
    --vpc-security-group-ids ${RDS_SG_ID}
;;
"get-rds-endpoint")
    export RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier ${RDS_INSTANCE_ID} \
    --query "DBInstances[0].Endpoint.Address" \
    | tr -d '"')
    echo "$(date): RDS Endpoint is ${RDS_ENDPOINT}"
    while [[ ${RDS_ENDPOINT} == "null" ]]
    do
        export RDS_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier ${RDS_INSTANCE_ID} \
        --query "DBInstances[0].Endpoint.Address" \
        | tr -d '"')
        echo "$(date): RDS Endpoint is ${RDS_ENDPOINT}"
        sleep 30
    done
;;
"airflow-initialize")
    export RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier ${RDS_INSTANCE_ID} \
    --output text \
    --no-paginate \
    --query "DBInstances[0].Endpoint.Address" \
    | tr -d '"')
    export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${AIRFLOW_RDS_USER}:${AIRFLOW_RDS_PASSWORD}@${RDS_ENDPOINT}:5432/airflow"
    export AIRFLOW_HOME=$(pwd)/airflow_home

    # TODO: Make airflow-initialize idempotent: check if airflow is
    # already initialized and only initialize if not initialized already
    airflow db init
    airflow users create \
        --email admin@airflow.org \
        --firstname Apache \
        --lastname Airflow \
        --role Admin \
        --username airflow \
        --password airflow
    airflow connections add \
        --conn-type aws \
        remote_log_s3
    exit 0
;;
"login-to-rds")
    export RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier ${RDS_INSTANCE_ID} \
    --output text \
    --no-paginate \
    --query "DBInstances[0].Endpoint.Address" \
    | tr -d '"')
    PGPASSWORD=${AIRFLOW_RDS_PASSWORD} \
    psql -h ${RDS_ENDPOINT} -U ${AIRFLOW_RDS_USER} -d airflow
;;
"delete-rds-instance")
    aws rds delete-db-instance \
    --db-instance-identifier ${RDS_INSTANCE_ID} \
    --skip-final-snapshot \
    --delete-automated-backups
;;
"create-ecs-cluster")
    aws ecs create-cluster --cluster-name ${ECS_CLUSTER_NAME}
;;
"delete-ecs-cluster")
    aws ecs delete-cluster --cluster ${ECS_CLUSTER_NAME}
;;
"create-task-role")
    aws iam create-role --role-name ${ECS_TASK_ROLE} \
        --assume-role-policy-document file://$(pwd)/trust-relationships.json
    aws iam attach-role-policy \
        --role-name ${ECS_TASK_ROLE} \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    aws iam attach-role-policy \
        --role-name ${ECS_TASK_ROLE} \
        --policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    aws iam attach-role-policy \
        --role-name ${ECS_TASK_ROLE} \
        --policy-arn "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
;;
"delete-task-role")
    aws iam detach-role-policy \
        --role-name ${ECS_TASK_ROLE} \
        --policy-arn "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
    aws iam detach-role-policy \
        --role-name ${ECS_TASK_ROLE} \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    aws iam detach-role-policy \
        --role-name ${ECS_TASK_ROLE} \
        --policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    aws iam delete-role \
        --role-name ${ECS_TASK_ROLE}
;;
"create-ecs-log-group")
    aws logs create-log-group --log-group-name ${ECS_LOG_GROUP}
;;
"delete-ecs-log-group")
    aws logs delete-log-group --log-group-name ${ECS_LOG_GROUP}
;;
"create-remote-logging-bucket")
    aws s3api create-bucket --bucket ${REMOTE_LOGGING_BUCKET} \
        --create-bucket-configuration "LocationConstraint=${AWS_REGION}"
;;
"check-remote-logging-bucket")
    aws s3api head-bucket --bucket ${REMOTE_LOGGING_BUCKET}
    if [[ $? == "0" ]]; then
        echo "s3://${REMOTE_LOGGING_BUCKET} can be reached"
    fi
;;
"delete-remote-logging-bucket")
    aws s3 rm --recursive s3://${REMOTE_LOGGING_BUCKET}
    aws s3api delete-bucket --bucket ${REMOTE_LOGGING_BUCKET}
;;
"register-task-definition")
    python generate_airflow_core_task_def.py > task_def.json
    aws ecs register-task-definition --cli-input-json file://$(pwd)/task_def.json
    rm task_def.json

    python generate_airflow_worker_task_def.py > task_def.json
    aws ecs register-task-definition --cli-input-json file://$(pwd)/task_def.json
    rm task_def.json
;;
"deregister-task-definition")
    # NOTE: Kind of optional since task definitions are free
    # TODO: teardown all active revisions of ${TASK_DEFINITION_FAMILY}
;;
"run-task")
    python generate_ecs_network_config.py > network_config.json
    
    export TASK_ARN=$(aws ecs run-task \
        --cluster ${ECS_CLUSTER_NAME} \
        --count 1 \
        --launch-type "FARGATE" \
        --network-configuration file://$(pwd)/network_config.json \
        --task-definition ${AIRFLOW_CORE_TASK_DEF} \
        --query "tasks[0].taskArn" | tr -d '"')
    rm network_config.json
    
    # Block until task is running
    export LAST_STATUS=$(aws ecs describe-tasks \
        --cluster ${ECS_CLUSTER_NAME} \
        --tasks ${TASK_ARN} --query "tasks[0].lastStatus" | tr -d '"'
    )
    while [[ ${LAST_STATUS} != "RUNNING" ]]
    do
        export LAST_STATUS=$(aws ecs describe-tasks \
            --cluster ${ECS_CLUSTER_NAME} \
            --tasks ${TASK_ARN} --query "tasks[0].lastStatus" | tr -d '"'
        )
        echo "`date` Task ${TASK_ARN}'s last status is ${LAST_STATUS}"
        sleep 10
    done

;;
"stop-all-tasks")
    python stop_all_tasks.py
;;
*)
    echo "Bad command"
    exit 1
;;
esac
