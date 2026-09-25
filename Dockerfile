FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ARG NAKAMA_VERSION=3.40.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql \
        postgresql-client \
        ca-certificates \
        curl \
        tar \
        bash \
        tini \
        findutils \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /home/container --shell /bin/bash container

RUN curl -fL \
    "https://github.com/heroiclabs/nakama/releases/download/v${NAKAMA_VERSION}/nakama-${NAKAMA_VERSION}-linux-amd64.tar.gz" \
    -o /tmp/nakama.tar.gz \
    && mkdir -p /tmp/nakama \
    && tar -xzf /tmp/nakama.tar.gz -C /tmp/nakama \
    && find /tmp/nakama -type f -name nakama -exec cp {} /usr/local/bin/nakama \; \
    && chmod 755 /usr/local/bin/nakama \
    && rm -rf /tmp/nakama /tmp/nakama.tar.gz

COPY start.sh /usr/local/bin/start-nakama-postgres

RUN chmod 755 /usr/local/bin/start-nakama-postgres \
    && mkdir -p \
        /home/container/postgres \
        /home/container/nakama/data \
        /home/container/nakama/modules \
    && chown -R container:container /home/container

USER container
WORKDIR /home/container

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "/usr/local/bin/start-nakama-postgres"]