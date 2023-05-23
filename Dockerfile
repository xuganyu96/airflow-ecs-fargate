ARG BASE_IMG="apache/airflow:2.5.3-python3.10"

FROM ${BASE_IMG}

# Extend system requirements
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip jq \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && sudo ./aws/install \
    && apt-get autoremove -yqq --purge \
    && apt-get clean
RUN usermod -aG root airflow
# Set the wrapper script; note that the wrapper script must have root permissions
COPY wrapper.sh /wrapper.sh
RUN chmod a+x /wrapper.sh
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/wrapper.sh"]
USER airflow

# User requirements
COPY requirements.txt ./requirements.txt

RUN pip install --upgrade pip wheel setuptools \
    && pip install -r requirements.txt

COPY airflow_home/dags /opt/airflow/dags
COPY airflow_home/plugins /opt/airflow/plugins
COPY airflow_home/config /opt/airflow/config
COPY airflow_home/webserver_config.py /opt/airflow/webserver_config.py

