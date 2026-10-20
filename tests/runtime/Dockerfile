FROM python:3.12-slim

RUN apt-get update \
    && apt-get install --no-install-recommends -y haproxy socat jq git

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml

WORKDIR /repo
CMD ["bash", "tests/runtime/run.sh"]
