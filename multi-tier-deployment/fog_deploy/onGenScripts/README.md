# onGenScripts

This folder is the **VM1 / load-generator host** side of the
[fog deployment](../README.md) campaign. The shell script in here is the
main entry point: it brings the **VM2** FIWARE NGSI-LD stack up, runs the
load generator that sends raw parking images to the Discovery cluster
GPU node over Tailscale, then pulls Prometheus metrics and IoT-Agent
container logs back for offline analysis. All orchestrated phases are
driven by `fog_deploy_runner.sh`; the other files in the folder are the
pieces it composes.

> The Discovery cluster node itself is **not** orchestrated by this
> runner — it is provisioned and torn down manually via
> [`../onCluster/`](../onCluster/). The runner only sends requests to the
> cluster's `/predict` endpoint over Tailscale.

The full data-flow narrative and the experimental design live in the
parent [`../README.md`](../README.md); this README is a developer
reference for the scripts in this folder only.

## Orchestrator pipeline

```mermaid
flowchart TD
    A["fog_deploy_runner.sh<br/>(runs on VM1)"] --> B["Phase 1 — VM2 bring-up<br/>docker compose up + healthy wait"]
    B --> C["Phase 2 — IoT provisioning<br/>0_healthy_waiting → 1_…indices → 2_…service_group → 3_…provision → 4_…verify"]
    C --> D["Phase 3 — Load generator<br/>load_generator.py → POST images to cluster :8000/predict"]
    D --> E["Phase 4 — Prometheus metrics<br/>get_metrics_posttest.py → query_range"]
    E --> F["Phase 5 — Log collection<br/>IoT-Agent logs (VM2)"]

    G["Cluster (manual)<br/>see ../onCluster/"] -. "serves /predict" .-> D

    classDef host fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue
    classDef core fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef store fill:#FFB6C1,stroke:#DC143C,stroke:#2px,color:black
    classDef manual fill:#D3D3D3,stroke:#333,stroke-width:2px,color:black,stroke-dasharray: 5 5

    class A host
    class B,C core
    class D,E,F store
    class G manual
```

## File reference

The subsections below are ordered by when each file runs at runtime.

### `fog_deploy_runner.sh`

Main entry point. Usage: `./fog_deploy_runner.sh [config_file]` (defaults
to `./fog_deploy.conf`).

Behaviour:

- `set -euo pipefail` and `IFS=$'\n\t'`.
- Sources the config via a filtered `grep … | source` so that only lines
  matching `^[A-Za-z_][A-Za-z0-9_]*=` are evaluated (comments and blanks
  are skipped).
- Validates that every required variable is set: `M N seed alpha beta
  Cluster_tailscale_domain_name VM_tailscale_domain_name VM_tailscale_IPv4
  VM_username VM_password VM_dir LM_dir onVM_dir onGen_dir onInfra_dir`.
- Builds the per-run output directory
  `fog_deploy_test_M_{M}_N_{N}_seed_{seed}_alpha_{alpha}_beta_{beta}`
  under `${LM_dir}/${onGen_dir}/` and `tee`s every line of stdout+stderr
  into `<DIRNAME>.log` inside it.
- Runs the orchestrated phases in order, over `sshpass` to VM2, then
  `scp`s the per-target artefacts back into the per-run directory. The
  cluster phases are intentionally left out — they are handled
  manually on the cluster node and the runner header documents why.

The phases correspond exactly to the mermaid diagram above. Logs from
the IoT-Agent container on VM2 are filtered with
`docker ps -a --format '{{.Names}}' | grep 'fiware-iot-agent'`; if the
match fails, the runner prints a warning and continues.

### `fog_deploy.conf` / `fog_deploy.conf.example`

Shell-sourceable config. `fog_deploy.conf` is the real, gitignored file
with Tailscale IPs and SSH credentials; `fog_deploy.conf.example` is the
committed template.

```bash
# Template workflow (do NOT edit the .example in place)
cp fog_deploy.conf.example fog_deploy.conf
$EDITOR fog_deploy.conf
```

Variables (grouped):

| Group | Key | Meaning |
|---|---|---|
| Test | `M` | Number of virtual devices simulated per cycle. |
| Test | `N` | Number of seconds (bins) the cycle is spread over. |
| Test | `seed` | RNG seed for the Beta-distribution allocation (1..`seed` cycles are run). |
| Test | `alpha` | Beta-distribution α (workload shape). |
| Test | `beta` | Beta-distribution β (workload shape). |
| Cluster Tailscale | `Cluster_tailscale_domain_name` | Tailscale MagicDNS name of the Discovery cluster GPU node (load-gen target `<host>:8000/predict`). |
| VM2 Tailscale | `VM_tailscale_domain_name` | Tailscale MagicDNS name of VM2 (used in URLs and Prometheus target). |
| VM2 Tailscale | `VM_tailscale_IPv4` | Tailscale IPv4 of VM2 (used for `sshpass ssh`). |
| VM2 Tailscale | `VM_username` / `VM_password` | SSH credentials for VM2. |
| Paths | `VM_dir` | Repo root on VM2 (parent of `onVMScripts/`, `infra/`). |
| Paths | `LM_dir` | Repo root on the VM1 / load-generator host (parent of `onGenScripts/`). |
| Paths | `onVM_dir` | VM2-side scripts dir, relative to `VM_dir`. |
| Paths | `onGen_dir` | This folder, relative to `LM_dir`. |
| Paths | `onInfra_dir` | VM2 Compose stack dir, relative to `VM_dir`. |

### `load_generator.py`

Multi-threaded HTTP load generator that uploads a parking image to the
cluster node for every simulated device. CLI flags:

| Flag | Default | Meaning |
|---|---|---|
| `--M` | required | Number of virtual devices. |
| `--N` | required | Number of seconds (bins) per cycle. |
| `--seeds` | required | Number of cycles. Uses seeds `1..seeds`. |
| `--alpha` | `5.0` | Beta-distribution α. |
| `--beta` | `5.0` | Beta-distribution β. |
| `--max-workers` | `100` | Max threads in the `ThreadPoolExecutor`. |
| `--out-dir` | `.` | Output directory. |
| `--url` | `http://localhost:7896/iot/json` | Target URL. **In the fog runner this is overridden to `<cluster>:8000/predict`.** |
| `--timeout` | `300` | Per-request timeout in seconds. |
| `--image` | required | Path to the image uploaded with every request. |

Behaviour worth knowing about for the fog deployment:

- The HTTP body is a **`multipart/form-data`** upload, not a JSON body.
  The image is sent as the `file` field and the NGSI-LD entity id as a
  form field:
  ```text
  POST <cluster>:8000/predict
  Content-Type: multipart/form-data
  file=@test.jpg
  entity_id=urn:ngsi-ld:OffStreetParking:<device_id>
  ```
  This is what makes the FastAPI service on the cluster node able to
  forward the count back to the right IoT-Agent device downstream.
- For each seed the script draws a Beta-distribution across `N` seconds,
  rounds to integer request counts, and rebalances the rounding residual
  using `np.random.default_rng(seed=seed_val)`.
- The CSV is opened once per seed and flushed per second; a sentinel
  row `Seed=0, Status=200, ResponseTime=0` is prepended at start and
  appended at end so timestamp range parsing by
  `get_metrics_posttest.py` is robust to early/late out-of-order events.
- On exit, fires a desktop notification via `notify-send -u critical
  "The program  ended."` (failures swallowed; this is the only place
  the binary is invoked).

Outputs (under `--out-dir`):

- `response_times_M_{M}_N_{N}_seed_{seeds}_alpha_{alpha}_beta_{beta}.csv`
  with columns `Seed, Timestamp, DeviceID, EntityID, Status, ResponseTime(ms)`.
- `load_generator_M_{M}_N_{N}_seed_{seeds}_alpha_{alpha}_beta_{beta}.log`
  with full DEBUG-level request traces.

### `get_metrics_posttest.py`

Post-test Prometheus scraper. CLI flags:

| Flag | Default | Meaning |
|---|---|---|
| `--out-dir` | `./results` | Directory containing `response_times_*.csv` and the destination for `metrics_*.csv`. |
| `--prom-url` | `http://localhost:9090` | Prometheus base URL. **In the fog runner this is overridden to `<vm2_tailscale>:9090`.** |
| `--interval` | `15s` | Rate / irate window used inside the PromQL templates. |
| `--containers` | (built-in default) | Comma-separated container names to monitor. Overrides the built-in default. |
| `--max-workers` | `16` | Max parallel `query_range` calls per file. |
| `--step` | `1s` | Query resolution step for `query_range`. |
| `--max-points` | `11000` | Prometheus max points per timeseries; the time window is split into chunks so each chunk has at most this many points. |

Behaviour:

- Discovers the **Node Exporter** `instance`/`job` pair and the
  **cAdvisor** `instance` from Prometheus via `/api/v1/series`.
- Builds PromQL for ~40 host-level metrics (CPU usage, load, PSI, RAM,
  swap, disk reads/writes/queue/flush/TRIM, network Rx/Tx and
  utilisation) plus per-container cAdvisor metrics for the default
  container list:
  `nginx-reverse-proxy, fiware-orion, fiware-iot-agent, fiware-ld-context, db-mongo, cadvisor, node-exporter, prometheus-monitor`.
- For each `response_times_*.csv` under `--out-dir`, derives the window
  `[first_timestamp - 10s, last_timestamp + 10s]`, splits that window
  into chunks of `<= step_seconds * (max_points - 1)` so each
  timeseries stays under Prometheus's point cap, fans them out across
  the thread pool, then writes one row per second.
- One `metrics_{M_x_N_x_seed_x_TR_x_alpha_x_beta_x}.csv` per response
  file; the `TR` segment in the key is expected by the regex but is
  not part of the fog filename — the script falls back to a copy of
  the response-file stem if no key is matched.

### `mean_inference_time.sh`

Single-purpose helper. Usage:

```bash
./mean_inference_time.sh path/to/inference_times.csv
```

Averages column 1 of the CSV (skipping the header) with `awk -F','` and
prints `Mean inference_time_s: <value>`. Returns `NaN` if the file is
empty. Intended for one-off sanity checks on cluster-side inference
latencies that arrive in a separate CSV; the orchestrator does not call
it.

### `requirements.txt`

Pinned Python dependencies for the load-generator host venv:

```text
numpy==1.26.4
requests==2.31.0
scipy==1.13.1
pandas
```

Install inside a fresh venv on the load-generator host:

```bash
python3 -m venv "${LM_dir}/${onGen_dir}/venv"
source "${LM_dir}/${onGen_dir}/venv/bin/activate"
pip install -r "${LM_dir}/${onGen_dir}/requirements.txt"
```

> Unlike `mist_deploy/onGeneratorScripts/`, this folder does **not** ship
> a pre-built `venv/`; you are expected to create it locally.

### `test.jpg`

Sample parking image uploaded as the `file` field of every request by
`load_generator.py` (the runner passes `--image ./test.jpg`). It is kept
in the repo so the harness works out of the box without the operator
having to provision their own fixture; replace it with a different
fixture if you need a specific camera angle or resolution for a
particular test.

## Quick start

```bash
# On the load-generator host, from this folder
cd multi-tier-deployment/fog_deploy/onGenScripts

# 1. Create your local config (never commit)
cp fog_deploy.conf.example fog_deploy.conf
$EDITOR fog_deploy.conf            # fill in Tailscale + SSH credentials

# 2. Build the Python venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Manually bring the cluster node up (see ../onCluster/) and verify
#    that <cluster>:8000/predict responds. The runner does not do this.

# 4. Run a single experiment
./fog_deploy_runner.sh
```

## Run output

A successful run creates a single timestamped directory named
`fog_deploy_test_M_{M}_N_{N}_seed_{seed}_alpha_{alpha}_beta_{beta}/`
under this folder. It contains:

- `<DIRNAME>.log` — `tee`'d stdout+stderr of the whole runner.
- `response_times_*.csv` / `load_generator_*.log` — load-generator
  output, written by `load_generator.py`.
- `metrics_*.csv` — Prometheus host + per-container metrics for the
  load window, written by `get_metrics_posttest.py`.
- `raw_logs_fiware-iot-agent_*.log-agent` — IoT-Agent container logs
  collected over SSH from VM2.

The exact `DIRNAME` template is significant: downstream helpers glob on
that prefix, so do not rename it.

## See also

- [`../README.md`](../README.md) — fog_deploy campaign overview,
  data-flow diagram, and experimental design.
- [`../onCluster/`](../onCluster/) — the Discovery cluster node setup
  (TensorRT export procedure, FastAPI `/predict` service, manual
  bring-up / tear-down steps). This folder is the inference target
  the runner posts to; it is *not* orchestrated by the runner.
- [`../onVMScripts/`](../onVMScripts/) — the numbered
  `0_..4_/7_` provisioning and measurement scripts that the runner
  invokes over SSH on VM2.
- [`../infra/`](../infra/) — the VM2-side Docker Compose stack
  (Orion-LD, IoT Agent JSON, MongoDB, NGINX, Prometheus, Grafana,
  cAdvisor, node-exporter).
