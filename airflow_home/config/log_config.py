"""Switch Airflow webserver and DAG processor (scheduler) to format their logs
in JSON. Keep Airflow task logs written to files as they are, but add a
handler that writes task logs to STDOUT in JSON format
"""
from copy import deepcopy
import sys
from airflow.config_templates.airflow_local_settings import DEFAULT_LOGGING_CONFIG

LOG_CONFIG = deepcopy(DEFAULT_LOGGING_CONFIG)
LOG_CONFIG["formatters"]["json"] = {
    "class": "pythonjsonlogger.jsonlogger.JsonFormatter",
    "format": "[%%(asctime)s] {{%%(filename)s:%%(lineno)d}} %%(levelname)s - %%(message)s",
}

STREAM_HANDLER_CONFIG = {
    "class": "logging.StreamHandler",
    "formatter": "json",
    "stream": sys.stdout,
}
LOG_CONFIG["handlers"]["stream"] = STREAM_HANDLER_CONFIG

LOG_CONFIG["handlers"]["console"]["formatter"] = "json"  # used by FAB
LOG_CONFIG["handlers"]["processor"]["formatter"] = "json"  # used by DAG processor
LOG_CONFIG["handlers"]["processor_to_stdout"]["formatter"] = "json"  # same as above
LOG_CONFIG["loggers"]["airflow.task"]["handlers"] = ["task", "stream"]
