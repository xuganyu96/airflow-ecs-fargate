ARG BASE_IMG="apache/airflow:2.5.3-python3.10"

FROM ${BASE_IMG}

COPY requirements.txt ./requirements.txt

COPY airflow_home/dags /opt/airflow/dags
COPY airflow_home/plugins /opt/airflow/plugins
COPY airflow_home/config /opt/airflow/config
COPY airflow_home/webserver_config.py /opt/airflow/webserver_config.py

RUN pip install --upgrade pip wheel setuptools \
    && pip install -r requirements.txt
