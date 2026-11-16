# =============================================================================
# Multi-stage Dockerfile for TimescaleDB + CloudNativePG (Bookworm base)
# =============================================================================

ARG PG_MAJOR=17

# Install TimescaleDB & TimescaleDB Toolkit (Bookworm)
FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-standard-bookworm AS timescaledb-builder

ARG PG_MAJOR
ARG TS_VERSION=""
ARG KEEP_PREV_VERSIONS=3

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release; \
    install -d -m 0755 /usr/share/keyrings; \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/timescaledb.list; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    apt-get update; \
    if [ -n "${TS_VERSION}" ]; then \
        apt-get install -y --no-install-recommends \
            "timescaledb-2-postgresql-${PG_MAJOR}=${TS_VERSION}" \
            "timescaledb-2-loader-postgresql-${PG_MAJOR}=${TS_VERSION}" \
            "timescaledb-toolkit-postgresql-${PG_MAJOR}"; \
    else \
        apt-get install -y --no-install-recommends \
            "timescaledb-2-postgresql-${PG_MAJOR}" \
            "timescaledb-toolkit-postgresql-${PG_MAJOR}"; \
    fi; \
    # Retain .so and .sql files from recent previous versions so existing clusters
    # can restart cleanly and run ALTER EXTENSION timescaledb UPDATE across image updates
    if [ "${KEEP_PREV_VERSIONS}" -gt 0 ]; then \
        installed_ver="$(dpkg-query -W -f='${Version}' "timescaledb-2-postgresql-${PG_MAJOR}")"; \
        mkdir -p /tmp/ts-prev; \
        cd /tmp/ts-prev; \
        count=0; \
        for ver in $(apt-cache madison "timescaledb-2-postgresql-${PG_MAJOR}" | awk '{print $3}'); do \
            if dpkg --compare-versions "$ver" lt "$installed_ver"; then \
                if apt-get -o APT::Sandbox::User=root download "timescaledb-2-postgresql-${PG_MAJOR}=${ver}"; then \
                    dpkg-deb -x "timescaledb-2-postgresql-${PG_MAJOR}_"*.deb /tmp/ts-prev/extracted; \
                    cp -n /tmp/ts-prev/extracted/usr/lib/postgresql/${PG_MAJOR}/lib/timescaledb*.so \
                        /usr/lib/postgresql/${PG_MAJOR}/lib/ || true; \
                    cp -n /tmp/ts-prev/extracted/usr/share/postgresql/${PG_MAJOR}/extension/timescaledb*.sql \
                        /usr/share/postgresql/${PG_MAJOR}/extension/ || true; \
                    rm -rf /tmp/ts-prev/extracted *.deb; \
                    count=$((count + 1)); \
                    if [ "$count" -ge "${KEEP_PREV_VERSIONS}" ]; then \
                        break; \
                    fi; \
                fi; \
            fi; \
        done; \
        cd /; \
        rm -rf /tmp/ts-prev; \
    fi; \
    rm -rf /var/lib/apt/lists/*

FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-standard-bookworm

ARG PG_MAJOR

USER root

# Copy TimescaleDB and TimescaleDB Toolkit extension artifacts
# Includes compiled .so libraries, SQL migration files, and .control files
COPY --from=timescaledb-builder \
    /usr/lib/postgresql/${PG_MAJOR}/lib/timescaledb*.so \
    /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=timescaledb-builder \
    /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb*.sql \
    /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=timescaledb-builder \
    /usr/share/postgresql/${PG_MAJOR}/extension/timescaledb*.control \
    /usr/share/postgresql/${PG_MAJOR}/extension/

USER 26

LABEL org.opencontainers.image.title="CloudNativePG TimescaleDB (Bookworm)"
LABEL org.opencontainers.image.description="PostgreSQL ${PG_MAJOR} with TimescaleDB and TimescaleDB Toolkit for time-series and monitoring workloads on Kubernetes"
LABEL org.opencontainers.image.source="https://github.com/Fabienjulio/CloudNativePG-TimescaleDB"
