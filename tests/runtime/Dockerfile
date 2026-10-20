FROM python:3.12-slim

RUN apt-get update \
    && apt-get install --no-install-recommends -y haproxy socat jq \
    && pip install --no-cache-dir ansible-core==2.19.3

COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml

WORKDIR /repo
CMD ["bash", "tests/runtime/run.sh"]
