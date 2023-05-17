- [x] Setup a sample code base
    - [x] A simple DAG, simple `Flask-AppBuilder` plugin, Airflow config, and `webserver_config`
    - [x] Validate with local setup

- [x] A barebone cluster
    - [X] Extend Airflow's official image and manage the image on AWS ECR
    - [x] Run an AWS RDS instance and run an Airflow cluster against it
    - [x] Run `airflow standalone` on ECS Fargate and reach it from a browser
    - [x] Run Airflow webserver and scheduler, but using ECR and RDS as well
    - [x] Validation from the browser: DAG runs, plugins, CloudWatch logs
    - [x] Teardown: S3, ECR, RDS, ECS, EFS, CloudWatch

- [ ] ECS Fargate Executor
    - [ ] Switch Airflow's executor to ECS Fargate Executor

- [ ] A branch environment
    - [ ] Run a Postgres container on ECS Fargate, use Airflow CLI to initialize it
    - [ ] Run a MySQL container on ECS, be able to connect to it

- [ ] EFS mounting
    - [ ] Upload `dags`, `plugins`, `config`, and `webserver_config.py` to AWS S3
    - [ ] Copy the files above from S3 into an EFS volume
    - [ ] Mount the EFS volume onto containers

- [ ] Authentication:
    - [ ] Switch from DB authentication to OAuth
    - [ ] First-time user sign up

# Getting started
## Developer setup
We will stick with the simplest setup so we can focus on the deployment part.

I installed Python using `pyenv` and have Python 3.10. `venv` is used to create the virtual environment:

```bash
# From project root
python --version
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel
```

Airflow 2.5.3 is the chosen version:

```bash
AIRFLOW_VERSION="2.5.3"
PYTHON_VERSION="3.10"
AIRFLOW_EXTRAS="postgres,google,amazon"

pip install "apache-airflow[${AIRFLOW_EXTRAS}]==${AIRFLOW_VERSION}" \
--constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
```

Docker and Docker Compose will be used to run the Airflow cluster locally.

For the image, we will extend from the official `apache/airflow:2.5.3-python3.10` image to include additional requirements such as the JSON logger.

The Docker Compose YAML has been massively stripped down to keep things simple. Most notably `CeleryExecutor` was replaced with `LocalExecutor`, and the Redis server is simply removed.

For testing purposes:
- the DAGs are copied from Airflow's tutorials:
    - [Basic DAG tutorial](https://airflow.apache.org/docs/apache-airflow/2.5.3/tutorial/fundamentals.html)
    - [Taskflow API tutorial](https://airflow.apache.org/docs/apache-airflow/2.5.3/tutorial/taskflow.html)
- A simple plugin defines a route that prints "Hello, world"
- The webserver config will remain stock, but we will change it to support Google OAuth at a later time
- Within `config/` we will define a JSON formatter that log messages in jsonified strings and apply the formatter to the webserver, the scheduler, and the tasks

At this point, the code base is ready for deployment. We will move on to do things on AWS.

## Environment variables
The development environment needs the following environment variables (I choose to store in a `.env` file that is ignored by `git`) for storing potentially sensitive credentials and AWS configurations:

|name|notes|
|:--|:--|
|AWS_PROFILE|Optional|
|AWS_ACCOUNT_ID|A 12 digit ID, used for identifying ECR repository and other|
|AWS_REGION|used for constructing the ECR repository's URI|
|ECR_REPO_NAME|name of the repository to push the custom Docker image to|
|IMAGE_TAG|the tag of the image being pushed to the private ECR repository|
|RDS_SG_ID|ID of the security group attached to the RDS instance, probably with inbound traffic allowed on port 5432 (PostgreSQL)|
|ECS_SG_ID|ID of the security group attached to the ECS tasks, probably with inbound traffic allowed on port 8080 (Airflow webserver)|
|RDS_INSTANCE_ID|ID of the RDS instance, used for finding the RDS endpoint and for stopping the RDS instance|
|AIRFLOW_RDS_USER|Admin user of the RDS instance|
|AIRFLOW_RDS_PASSWORD|Admin user's password|
|ECS_CLUSTER_NAME|Name of the ECS cluster that will host the various tasks|
|VPC_ID|Name of the VPC that the containers will be placed into, used for finding the subnets when constructing network configuration for `aws ecs run-task`|

## The `run.sh` script
The TL;DR is as follows:

```bash
# chmod +x run.sh
# source .env

# Setup, in this order
./run.sh create-ecr-repository
./run.sh deploy-docker-image
./run.sh create-rds-instance
./run.sh get-rds-endpoint
./run.sh airflow-initialize
./run.sh login-to-rds
./run.sh create-ecs-cluster
./run.sh register-task-definition
./run.sh run-task

# Teardown, in this order
./run.sh stop-all-tasks
./run.sh delete-ecs-cluster
./run.sh delete-rds-instance
./run.sh delete-ecr-repository
```
