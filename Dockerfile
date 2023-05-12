ARG BASE_IMG="apache/airflow:2.5.3-python3.10"

FROM ${BASE_IMG}

COPY requirements.txt ./requirements.txt

RUN pip install --upgrade pip wheel setuptools \
    && pip install -r requirements.txt