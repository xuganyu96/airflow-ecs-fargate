- [x] Setup a sample code base
    - [x] A simple DAG, simple `Flask-AppBuilder` plugin, Airflow config, and `webserver_config`
    - [x] Validate with local setup

- [ ] A barebone cluster
    - [ ] Upload `dags`, `plugins`, `config`, and `webserver_config.py` to AWS S3
    - [ ] Run an AWS RDS instance and use Airflow CLI to initialize it
    - [ ] Task definition, use `LocalExecutor` at first, but separate `webserver` from `scheduler`
    - [ ] Use EFS to mount `dags`, `plugins`, `configs`, `webserver_config.py` from S3 onto the containers
    - [ ] Validation from the browser: DAG runs, plugins, CloudWatch logs
    - [ ] Teardown: S3, RDS, ECS, EFS, CloudWatch

- [ ] A branch environment
    - [ ] Run a Postgres container on ECS Fargate, use Airflow CLI to initialize it
    - [ ] Run a MySQL container on ECS, be able to connect to it

- [ ] ECS Fargate Executor
    - [ ] Switch Airflow's executor to ECS Fargate Executor

- [ ] Authentication:
    - [ ] Switch from DB authentication to OAuth
    - [ ] First-time user sign up

# Developer setup
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
AIRFLOW_EXTRAS="postgres,google"

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

# AWS Setup
We will not cover some of the most basic setup for an AWS account, such as setting up an admin account instead of using a root account all the time, and getting access keys for programmatic access. The access keys and secret keys should be stored under `~/.aws/credentials` and they should be applied using the `--profile` or the `AWS_PROFILE` environment variable. We will use AWS CLI v2 in this walkthrough.

## Create source code bucket
We will use an S3 bucket to store Airflow cluster's source code:

- `dags` directory
- `plugins` directory
- `config` directory
- `webserver_config.py` file

Creating the bucket and uploading code onto the bucket will be implemented using AWS CLI. Note that object versioning will not be enabled since this bucket is not meant to be a source of truth.

```bash
export AIRFLOW_SRC_BUCKET="69420-airflow-src-repo"

# Create the bucket
aws s3api create-bucket --bucket ${AIRFLOW_SRC_BUCKET} --create-bucket-configuration "LocationConstraint=us-west-2"

# Upload code
aws s3 cp --recursive --exclude "**__pycache__**" airflow_home/dags s3://${AIRFLOW_SRC_BUCKET}/dags
aws s3 cp --recursive --exclude "**__pycache__**" airflow_home/plugins s3://${AIRFLOW_SRC_BUCKET}/plugins
aws s3 cp --recursive --exclude "**__pycache__**" airflow_home/config s3://${AIRFLOW_SRC_BUCKET}/config
aws s3 cp airflow_home/webserver_config.py s3://${AIRFLOW_SRC_BUCKET}/webserver_config.py


# Bucket must be emptied before it can be deleted
aws s3 rm s3://${AIRFLOW_SRC_BUCKET} --recursive
aws s3api delete-bucket --bucket ${AIRFLOW_SRC_BUCKET}
```
