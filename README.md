# CloudNativePG TimescaleDB

[![Build](https://img.shields.io/github/actions/workflow/status/Fabienjulio/CloudNativePG-TimescaleDB/docker-publish.yml?branch=main&label=build)](https://github.com/Fabienjulio/CloudNativePG-TimescaleDB/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fghcr-badge.elias.eu.org%2Fapi%2FFabienjulio%2FCloudNativePG-TimescaleDB%2Fcloudnativepg-timescaledb&query=downloadCount&label=docker%20pulls&color=2496ed&logo=docker&logoColor=white)](https://github.com/Fabienjulio/CloudNativePG-TimescaleDB/pkgs/container/cloudnativepg-timescaledb)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17%20%7C%2018-4169E1?logo=postgresql&logoColor=white)](#images)
[![Last Commit](https://img.shields.io/github/last-commit/Fabienjulio/CloudNativePG-TimescaleDB)](https://github.com/Fabienjulio/CloudNativePG-TimescaleDB/commits/main)

PostgreSQL container images built on the official [CloudNativePG](https://cloudnative-pg.io/) images with [TimescaleDB](https://github.com/timescale/timescaledb) and [TimescaleDB Toolkit](https://github.com/timescale/timescaledb-toolkit) preinstalled.

## Images

Published to GitHub Container Registry at `ghcr.io/fabienjulio/cloudnativepg-timescaledb`.

| PostgreSQL | Base Image | Floating Tags |
| --- | --- | --- |
| 17 | `ghcr.io/cloudnative-pg/postgresql:17-standard-bookworm` | `pg17`, `pg17-latest`, `pg17.<minor>` |
| 18 | `ghcr.io/cloudnative-pg/postgresql:18-standard-trixie` | `pg18`, `pg18-latest`, `pg18.<minor>` |

- **Extensions**: `timescaledb` and `timescaledb_toolkit`, installed from the official Timescale Debian repository.
- **Upgrade compatibility**: Retains shared libraries (`.so`) and migration scripts (`.sql`) from the previous 3 TimescaleDB releases (`KEEP_PREV_VERSIONS=3`) so existing clusters can restart across image updates and run `ALTER EXTENSION timescaledb UPDATE`.

## Usage

Requires the [CloudNativePG operator](https://cloudnative-pg.io/documentation/current/installation_upgrade/) installed in your Kubernetes cluster.

### 1. Create an `ImageCatalog`

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ImageCatalog
metadata:
  name: timescaledb
  namespace: monitoring
spec:
  images:
    - major: 17
      image: ghcr.io/fabienjulio/cloudnativepg-timescaledb:pg17-latest
    - major: 18
      image: ghcr.io/fabienjulio/cloudnativepg-timescaledb:pg18-latest
```

### 2. Deploy a `Cluster`

Reference the `ImageCatalog`, preload `timescaledb` in `shared_preload_libraries`, and enable the extensions during bootstrap:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: timescaledb-cluster
  namespace: monitoring
spec:
  instances: 2

  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ImageCatalog
    name: timescaledb
    major: 17

  storage:
    size: 10Gi

  postgresql:
    shared_preload_libraries:
      - timescaledb

  bootstrap:
    initdb:
      database: app
      owner: app
      postInitApplicationSQL:
        - CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
        - CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit CASCADE;
```

### 3. Verify

```bash
kubectl get cluster timescaledb-cluster -n monitoring
kubectl exec -n monitoring timescaledb-cluster-1 -- psql -U postgres -d app -c "\dx"
```

## Example Manifests & Scripts

This repository includes ready-to-use manifests and helper scripts for a 2-node cluster in the `monitoring` namespace:

- [kubernetes/namespace.yaml](kubernetes/namespace.yaml) — `monitoring` namespace
- [kubernetes/imagecatalog-timescaledb.yaml](kubernetes/imagecatalog-timescaledb.yaml) — `ImageCatalog` for PostgreSQL 17 and 18
- [kubernetes/cluster-timescaledb.yaml](kubernetes/cluster-timescaledb.yaml) — 2-node `Cluster` with memory and TimescaleDB parameters tuned for 2 GiB pods
- [cluster-setup.sh](cluster-setup.sh) — applies the manifests and waits for cluster readiness
- [initialize-db.sh](initialize-db.sh) — ensures both extensions are enabled and runs a rolled-back hypertable smoke test

```bash
./cluster-setup.sh
./initialize-db.sh
```

## Building Locally

```bash
docker build \
  --build-arg PG_MAJOR=18 \
  --build-arg OS_CODENAME=trixie \
  -t cloudnativepg-timescaledb:pg18 .
```

| Build Argument | Default | Description |
| --- | --- | --- |
| `PG_MAJOR` | `17` | PostgreSQL major version (`17`, `18`) |
| `OS_CODENAME` | `bookworm` | Debian codename matching the CNPG base image (`bookworm`, `trixie`) |
| `TS_VERSION` | *(latest)* | Pin a specific `timescaledb-2-postgresql-<major>` Debian package version |
| `KEEP_PREV_VERSIONS` | `3` | Previous TimescaleDB releases retained for in-place upgrades (`0` to disable) |

## References

- Adapted from [timescale/TimescaleDB-CloudNativePG-VectorSearch](https://github.com/timescale/TimescaleDB-CloudNativePG-VectorSearch) ([TigerData blog post](https://www.tigerdata.com/blog/deploying-timescaledb-vector-search-cloudnativepg-kubernetes-operator)), scoped to TimescaleDB and TimescaleDB Toolkit.
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/current/) & [cloudnative-pg/postgres-containers](https://github.com/cloudnative-pg/postgres-containers)
- [TimescaleDB](https://github.com/timescale/timescaledb) & [TimescaleDB Toolkit](https://github.com/timescale/timescaledb-toolkit)
