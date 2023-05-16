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
if [[ -z $AWS_SRC_BUCKET ]]; then
    echo "Please set AWS_SRC_BUCKET"
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
if [[ -z $SUBNETS ]]; then
    echo "Please set SUBNETS"
    exit 1
fi
if [[ -z $ECS_SG_ID ]]; then
    echo "Please set ECS_SG_ID"
    exit 1
fi


case $1 in
version)
    echo "0.1"
;;
"create-source-code-bucket")
    aws s3api create-bucket --bucket ${AIRFLOW_SRC_BUCKET} \
        --create-bucket-configuration "LocationConstraint=us-west-2"
;;
"upload-source-code")
    aws s3 cp --recursive --exclude "**__pycache__**" \
        airflow_home/dags s3://${AIRFLOW_SRC_BUCKET}/dags
    aws s3 cp --recursive --exclude "**__pycache__**" \
        airflow_home/plugins s3://${AIRFLOW_SRC_BUCKET}/plugins
    aws s3 cp --recursive --exclude "**__pycache__**" \
        airflow_home/config s3://${AIRFLOW_SRC_BUCKET}/config
    aws s3 cp airflow_home/webserver_config.py s3://${AIRFLOW_SRC_BUCKET}/webserver_config.py
;;
"delete-source-code-bucket")
    aws s3 rm s3://${AIRFLOW_SRC_BUCKET} --recursive
    aws s3api delete-bucket --bucket ${AIRFLOW_SRC_BUCKET}
;;
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
"delete-private-repository")
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
    aws rds describe-db-instances \
    --db-instance-identifier ${RDS_INSTANCE_ID} \
    --output text \
    --no-paginate \
    --query "DBInstances[0].Endpoint.Address"
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
"register-task-definition")
    sed -e "s/AWS_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" task-def.json > temp.json
    aws ecs register-task-definition \
    --cli-input-json file://$(pwd)/temp.json \
    --query "taskDefinition.revision"
    rm temp.json
;;
*)
    echo "Bad command"
    exit 1
;;
esac
