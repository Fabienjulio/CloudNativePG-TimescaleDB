# CloudNativePG TimescaleDB Image

A custom PostgreSQL image packed with the **TimescaleDB** extension. It is specifically built to be used with the [CloudNativePG (CNPG)](https://cloudnative-pg.io/) operator on Kubernetes, optimized for time-series and monitoring workloads.

Find the container images at:
`ghcr.io/fabienjulio/cloudnativepg-timescaledb`

---

## Usage

To use this custom image in your Kubernetes cluster, you must be running the **CloudNativePG** operator.

### 1. Define the Image Catalog

CloudNativePG uses an `ImageCatalog` to map PostgreSQL major versions to specific container images. Create an `ImageCatalog` in your namespace that points to the ghcr image:

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
```

Apply the catalog:

```bash

kubectl apply -f imagecatalog-timescaledb.yaml
```

### 2. Deploy the Cluster

When creating your CloudNativePG `Cluster` resource, you need to:

1. Reference the custom `imageCatalogRef`.
2. Ensure the `timescaledb` library is loaded at startup.
3. Automatically create the extension during bootstrap.

Here is a minimal example.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: timescaledb-cluster
  namespace: monitoring
spec:
  instances: 2

  # 1. Reference the image catalog
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ImageCatalog
    name: timescaledb
    major: 17

  storage:
    size: 10Gi
    
  postgresql:
    # 2. Load TimescaleDB at startup
    shared_preload_libraries:
      - timescaledb
    parameters:
      # Tune memory settings for your environment
      work_mem: "128MB"
      shared_buffers: "512MB"
      max_connections: "100"

  bootstrap:
    initdb:
      database: app
      owner: app
      # 3. Create the Timescale extension automatically
      postInitApplicationSQL:
        - CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
```

Apply the cluster:

```bash
kubectl apply -f cluster-timescaledb.yaml
```

### 3. Verify the Deployment

Wait for the CloudNativePG operator to bootstrap the primary and replica pods. You can check the status of your cluster with:

```bash
kubectl get cluster timescaledb-cluster -n monitoring
```

Once ready, you can connect to the primary database pod and confirm that TimescaleDB is loaded:

```bash
kubectl exec -it timescaledb-cluster-1 -n monitoring -- psql -U app -d app -c "\dx"
```

The output should confirm that the `timescaledb` extension is installed.

## Included Templates

If you have cloned this repository, you can find the template manifests in the `kubernetes/` directory:

- `kubernetes/namespace.yaml`
- `kubernetes/imagecatalog-timescaledb.yaml`
- `kubernetes/cluster-timescaledb.yaml`

You can quickly deploy these templates using the provided bash script:

```bash
./cluster-setup.sh
```

## Note

I followed and adapted the [tutorial](https://github.com/timescale/TimescaleDB-CloudNativePG-VectorSearch) repository made by the [TimescaleDB team](https://www.tigerdata.com/blog/deploying-timescaledb-vector-search-cloudnativepg-kubernetes-operator) to only include TimescaleDB.
