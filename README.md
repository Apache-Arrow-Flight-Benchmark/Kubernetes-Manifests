# Apache Arrow Flight Benchmark — Kubernetes Manifests

This repository provides **drop-in Kubernetes YAMLs** for benchmarking Apache Arrow Flight.  
It contains:

1. **`ibm-server.yaml`** – a reference IBM Flight server.
2. **Three generic benchmark Jobs** – templates for *any* Flight-compatible workload.

Use these manifests as a foundation: plug in your own Docker images, tweak CLI flags, scale pods, and compare throughput/latency across clusters.

---

## What you *must* change first

| File | Placeholder | What to put there |
|------|-------------|-------------------|
| `ibm-server.yaml` → `spec.containers[0].image` | `<your-ibm-flight-image>` | A container that runs the IBM Flight server. |
| every `benchmark_*.yaml` → `spec.containers[0].image` | `<your-benchmark-image>` | A container that runs the `benchmark` CLI. |

> **Tip:** Publish images to any registry you like (Docker Hub, GHCR, ECR…).  
> Example: `ghcr.io/apache-arrow-flight-benchmark/benchmark:latest`

---

## File overview

| File | Kind | Default purpose — feel free to repurpose |
|------|------|------------------------------------------|
| `ibm-server.yaml` | `Deployment` + `Service` | Exposes `9080` (HTTP), `9090` (gRPC) and `9443` (HTTPS); default **NodePort**. |
| `benchmark_dummy_jdbc.yaml` | `Job` | Generic “JDBC-style” workload (flags: `-s`, `-g`, `-n …`). |
| `benchmark_mocked_batch.yaml` | `Job` | Generic “mocked-batch” workload (flags: `-r …`, `-b …`). |
| `benchmark_postreSQL.yaml` | `Job` | Generic DB workload (flags: `--postgres_url …`). |

---

## Quick start

```bash
# 1 — Deploy the server
kubectl apply -f ibm-server.yaml
kubectl wait --for=condition=available deploy/ibm-server --timeout=120s

# Grab the server Pod name
POD=$(kubectl get pod -l app=ibm-server -o jsonpath='{.items[0].metadata.name}')

# Copy a CSV file that the server will serve as Arrow Flight data
kubectl cp item_padding.csv \
  "$POD":/opt/ibm/wlp/usr/servers/defaultServer/apps/expanded/wdp-connect-sdk-gen-ibmflight.war/resources/data.csv

# Copy the DummyJDBC driver used by the "dummy JDBC" scenario
kubectl cp dummyjdbc-1.3.1.jar \
  "$POD":/opt/ibm/wlp/usr/servers/defaultServer/apps/expanded/wdp-connect-sdk-gen-ibmflight.war/WEB-INF/lib/dummyjdbc-1.3.1.jar

# 2 — Launch the workloads
kubectl apply -f benchmark_dummy_jdbc.yaml
kubectl apply -f benchmark_mocked_batch.yaml
kubectl apply -f benchmark_postreSQL.yaml

# 3 — Watch logs (example: first Job)
kubectl logs job/benchmark-dummy-jdbc
```

# collect-pod-metrics.sh

A tiny helper that writes one-second snapshots of **CPU** and **memory** usage of a single Kubernetes Pod to a log file.  
If the Pod defines a CPU limit, the script also records *usage as a percentage of that limit*.

## Requirements

* `kubectl` configured for the target cluster  
* `metrics-server` (or any provider that powers `kubectl top`) installed and working  
* GNU `awk`, `sed`, and `bc` available in the shell environment

## Usage

```bash
chmod +x collect-pod-metrics.sh

# Edit these three variables at the top of the script:
POD_NAME="my-pod-abc123"
NAMESPACE="my-namespace"
OUTPUT_FILE="pod-metrics.log"

./collect-pod-metrics.sh &
