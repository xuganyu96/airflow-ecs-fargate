- [ ] Setup a sample code base
    - [ ] A simple DAG, simple `Flask-AppBuilder` plugin, Airflow config, and `webserver_config`
    - [ ] Validate with local setup

- [ ] A barebone cluster
    - [ ] Upload `dags`, `plugins`, `configs`, and `webserver_config.py` to AWS S3
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