"""A somewhat brute-force application of a JSON formatter onto all Airflow 
logging
"""
from copy import deepcopy
from airflow.config_templates.airflow_local_settings import DEFAULT_LOGGING_CONFIG

LOG_CONFIG = deepcopy(DEFAULT_LOGGING_CONFIG)
LOG_CONFIG["formatters"]["json"] = {
    "class": "pythonjsonlogger.jsonlogger.JsonFormatter",
    "format": "[%%(asctime)s] {{%%(filename)s:%%(lineno)d}} %%(levelname)s - %%(message)s",
}
LOG_CONFIG["handlers"]["console"]["formatter"] = "json"
LOG_CONFIG["handlers"]["task"]["formatter"] = "json"
LOG_CONFIG["handlers"]["processor"]["formatter"] = "json"
LOG_CONFIG["handlers"]["processor_to_stdout"]["formatter"] = "json"
