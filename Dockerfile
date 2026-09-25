FROM registry.heroiclabs.com/heroiclabs/nakama:3.40.0 AS nakama

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql \
        postgresql-client \
        ca-certificates \
        bash \
        tini \
        findutils \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /home/container --shell /bin/bash container

COPY --from=nakama /nakama/nakama /usr/local/bin/nakama
COPY start.sh /usr/local/bin/start-nakama-postgres

RUN chmod 0755 /usr/local/bin/nakama /usr/local/bin/start-nakama-postgres \
    && mkdir -p /home/container/postgres /home/container/nakama/data /home/container/nakama/modules \
    && chown -R container:container /home/container

USER container
WORKDIR /home/container

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "/usr/local/bin/start-nakama-postgres"]
