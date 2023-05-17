import time
import boto3
from helpers import getenv_or_exit, list_tasks, tasks_all_stopped


if __name__ == "__main__":
    session = boto3.Session()
    ecs = session.client("ecs")
    cluster_name = getenv_or_exit("ECS_CLUSTER_NAME")

    task_arns = list_tasks(cluster_name, ecs)

    for task_arn in task_arns:
        ecs.stop_task(
            cluster=cluster_name,
            task=task_arn
        )
        print(f"Attempted to stop task {task_arn}")
    
    while not tasks_all_stopped(cluster_name, task_arns, ecs):
        time.sleep(5)
    print("Tasks all stopped")
