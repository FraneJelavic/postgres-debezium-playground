FROM postgres:16.14-bookworm@sha256:64154d0babcb1741988719e703419af0382b19953706149f9872fbd0f438efa8

USER root

ENV PATH="/opt/patroni-venv/bin:${PATH}" \
    PGDATA=/var/lib/postgresql/data/pgdata \
    PATRONI_CONFIG_FILE=/etc/patroni/patroni.yml \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl python3 python3-venv \
    && python3 -m venv /opt/patroni-venv \
    && rm -rf /var/lib/apt/lists/*

COPY images/postgres-patroni/requirements.txt /tmp/requirements.txt
RUN /opt/patroni-venv/bin/pip install --no-cache-dir --require-hashes -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

COPY config/patroni/patroni.yml /etc/patroni/patroni.yml
COPY images/postgres-patroni/entrypoint.sh /usr/local/bin/patroni-entrypoint

RUN chmod 0755 /usr/local/bin/patroni-entrypoint \
    && mkdir -p /var/lib/postgresql/data \
    && chown -R postgres:postgres /var/lib/postgresql /opt/patroni-venv /etc/patroni

USER postgres

EXPOSE 5432 8008
ENTRYPOINT ["patroni-entrypoint"]
CMD ["patroni", "/etc/patroni/patroni.yml"]
