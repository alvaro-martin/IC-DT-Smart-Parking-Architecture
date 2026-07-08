# onVMScripts — VM2 provisioning & measurement scripts

This directory holds the scripts that are executed **inside VM2**, the
remote VM that hosts the Docker Compose stack (Orion-LD, IoT Agent JSON,
MongoDB, Prometheus, etc.) during an **edge-tier** load test. The
companion orchestrator `../onGenScripts/edge_deploy_runner.sh` runs on
VM1 and invokes these scripts over SSH as part of the end-to-end test
pipeline, alongside the parallel pipeline that the runner also drives on
the **Jetson Nano** (see `../onJetson/README.md` for that side).

The scripts are intentionally numbered (`0_`…`7_`) so the orchestrator
can run them in the correct order; the two unnumbered files
(`collector_logs.sh` and `cpu_baseline.sh`) are independent utilities.

> **TL;DR** — `0` waits for the stack to be healthy, `1` prepares Mongo,
> `2`/`3`/`4` register and verify the IoT devices, the runner does a
> one-shot `docker logs` of the IoT Agent container into a
> `*.log-agent` file, and `7` converts that raw log into a CSV once the
> test finishes. `collector_logs.sh` is a stand-alone one-shot log
> collector (not in the main pipeline) and `cpu_baseline.sh` is meant
> to be run on VM2 **before** each test run, after a VM reset, to
> capture a CPU baseline.

## Table of contents

- [How this folder fits in the pipeline](#how-this-folder-fits-in-the-pipeline)
- [Execution order](#execution-order)
- [Architecture map — which script touches which component](#architecture-map--which-script-touches-which-component)
- [Script reference](#script-reference)
  - [0. `0_healthy_waiting.sh`](#0-0_healthy_waitingsh)
  - [1. `1_create_IoT_Agent_indices_MongoDB.sh`](#1-1_create_iot_agent_indices_mongodbsh)
  - [2. `2_create_service_group.sh`](#2-2_create_service_groupsh)
  - [3. `3_provision_devices.sh`](#3-3_provision_devicessh)
  - [4. `4_verify_provisioned_devices.sh`](#4-4_verify_provisioned_devicessh)
  - [5. `collector_logs.sh`](#5-collector_logssh)
  - [6. `7_process_iot_agent_logs.sh`](#6-7_process_iot_agent_logssh)
  - [7. `cpu_baseline.sh`](#7-cpu_baselinesh)
- [Log processing data flow](#log-processing-data-flow)
- [Running the scripts by hand](#running-the-scripts-by-hand)
- [Outputs produced on VM2](#outputs-produced-on-vm2)
- [Troubleshooting](#troubleshooting)

## Overview — VM1, VM2 and the Jetson

The edge-tier load-test setup spans three machines:

- **VM1 — load generator / orchestrator.** Runs
  `../onGeneratorScripts/edge_deploy_runner.sh`, `load_generator.py`,
  `get_metrics_posttest.py`, and the local virtual environment. It does
  *not* host any FIWARE component or the inference service; it only
  generates traffic (sending raw images) and collects metrics.
- **VM2 — system under test.** Runs the Docker Compose stack
  (Orion-LD, IoT Agent JSON, MongoDB, Prometheus, cAdvisor, Node
  Exporter, the nginx reverse proxy, etc.) and is where the scripts in
  this folder are executed.
- **Jetson Nano — edge inference device.** Runs the FastAPI
  TensorRT/YOLOv11n service that the load generator hits at
  `http://<jetson_domain>/predict`; the Jetson then forwards the
  resulting count to VM2 as `POST /iot/json`. The Jetson-side
  pipeline (tegrastats capture, log collection) is described in
  [`../onJetson/README.md`](../onJetson/README.md).

```mermaid
flowchart LR
    VM1["🖥️ VM1<br/>load generator / orchestrator<br/>(onGeneratorScripts)"]
    VM2["☁️ VM2<br/>system under test<br/>(this folder: onVMScripts + Docker stack)"]
    JETSON["🟢 Jetson Nano<br/>edge inference<br/>(onJetson)"]

    VM1 -- "🔗 sshpass ssh (VM pipeline)<br/>📋 sshpass scp (results back)" --> VM2
    VM1 -- "🔗 sshpass ssh (Jetson pipeline)" --> JETSON
    VM1 -- "🖼️ HTTP POST /predict<br/>(raw image via load_generator.py)" --> JETSON
    JETSON -- "⚡ HTTP POST /iot/json<br/>(occupied_spots payload)" --> VM2
    VM1 -- "📈 PromQL queries<br/>(get_metrics_posttest.py → Prometheus)" --> VM2

    classDef vm1 fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue
    classDef vm2 fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef jetson fill:#FFD700,stroke:#333,stroke-width:2px,color:black
    class VM1 vm1
    class VM2 vm2
    class JETSON jetson
```

## How this folder fits in the pipeline

The VM1-side orchestrator
(`multi-tier-deployment/edge_deploy/onGenScripts/edge_deploy_runner.sh`)
opens two parallel SSH sessions — one into the Jetson and one into VM2
— and runs the scripts in this folder against VM2. The directory
layout on VM2 is assumed to be `$VM_dir/onVMScripts/` (the path is read
from `edge_deploy.conf` via the `onVM_dir` variable). The matching
Jetson pipeline runs against `$Jetson_dir/onJetson/` and is documented
in [`../onJetson/README.md`](../onJetson/README.md).

```mermaid
flowchart LR
    subgraph VM1["🖥️ VM1 (load generator)"]
        Runner[⚙️ edge_deploy_runner.sh]
    end

    subgraph VM2["☁️ VM2 (system under test)"]
        direction TB
        S0[0_healthy_waiting.sh]
        S1[1_create_IoT_Agent_indices_MongoDB.sh]
        S2[2_create_service_group.sh]
        S3[3_provision_devices.sh M]
        S4[4_verify_provisioned_devices.sh M]
        LOG["inline: docker logs > *.log-agent"]
        S6[7_process_iot_agent_logs.sh]
    end

    subgraph JETSON["🟢 Jetson (edge inference)"]
        direction TB
        compose[compose.yml up -d]
        tegrastats[tegrastats log capture]
    end

    Runner -- "sshpass ssh (parallel)" --> VM2
    Runner -- "sshpass ssh (parallel)" --> JETSON
    Runner -- "sshpass ssh" --> S0
    S0 --> S1 --> S2 --> S3 --> S4
    S4 -. "control back to VM1" .-> Runner
    Runner -- "🖼️ load_generator.py → /predict" --> JETSON
    compose -. "before load test" .- tegrastats
    LOG -. "after load test" .- S6
    Runner -- "sshpass ssh (later)" --> S6
    Runner -- "sshpass scp back to VM1" --> Runner

    classDef vm1 fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue
    classDef vm2 fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef jetson fill:#FFD700,stroke:#333,stroke-width:2px,color:black
    classDef step fill:#E6E6FA,stroke:#333,stroke-width:2px,color:darkblue
    class Runner vm1
    class S0,S1,S2,S3,S4,LOG,S6 vm2
    class compose,tegrastats jetson
    class S0,S1,S2,S3,S4,LOG,S6 step
```

`cpu_baseline.sh` is not part of this pipeline — see its own section
below.

## Execution order

The numbered prefix on each script is the order in which the
orchestrator runs them. The flowchart below mirrors the exact call
sequence in `edge_deploy_runner.sh`.

```mermaid
flowchart TD
    Start([▶ edge_deploy_runner.sh<br/>on VM1]) --> Up[🐳 docker compose up -d]
    Up --> Wait30[⏳ sleep 30s]
    Wait30 --> S0[0_healthy_waiting.sh<br/>Orion-LD, MongoDB, @context]
    S0 --> S1[1_create_IoT_Agent_indices_MongoDB.sh<br/>drop + recreate iotagentjson collections]
    S1 --> S2[2_create_service_group.sh<br/>service=unicamp path=/parking key=12345]
    S2 --> S3[3_provision_devices.sh M<br/>register M OffStreetParking devices]
    S3 --> S4[4_verify_provisioned_devices.sh M<br/>assert all M are present]
    S4 --> HandBack([↩️ control back to VM1])
    HandBack --> LoadGen[🖼️ load_generator.py on VM1<br/>raw image → Jetson /predict]
    LoadGen --> Metrics[📊 get_metrics_posttest.py on VM1]
    Metrics --> CollectLogs["inline: docker logs fiware-iot-agent<br/>→ *.log-agent"]
    CollectLogs --> S6[7_process_iot_agent_logs.sh<br/>--out-dir .../DIRNAME]
    S6 --> SCP[📋 scp results back to VM1]
    SCP --> Done([✅ Done])

    classDef vm1 fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue
    classDef vm2 fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef step fill:#E6E6FA,stroke:#333,stroke-width:2px,color:darkblue

    class Start,HandBack,LoadGen,Metrics,Done vm1
    class Up,Wait30,S0,S1,S2,S3,S4,CollectLogs,S6,SCP vm2
    class S0,S1,S2,S3,S4,CollectLogs,S6 step
```

> **Why the gap between 4 and 7?** There is no `5_` or `6_` script on
> disk. The pipeline was restructured at some point (steps that used to
> live in their own files were either folded into another step or
> dropped entirely), but the numeric prefixes of the remaining files
> were left untouched so that the calling code in
> `edge_deploy_runner.sh` did not have to be modified. The log
> collection in the edge tier is intentionally inline in the runner
> (one-shot `docker logs`, not a backgrounded streaming collector as in
> `mist_deploy`); the runner then runs the load generator from VM1
> *against* the Jetson (which forwards the count to VM2) and only
> comes back to process the logs once the load test has finished.

> **Why `*.log-agent` instead of `*.log`?** The runner's inline
> `docker logs > "$DIRNAME/raw_logs_${container}_M${M}_N${N}_seeds${seed}_alpha${alpha}_beta${beta}.log-agent"`
> deliberately uses the `.log-agent` extension so the two streams of
> log files produced by the same runner (the IoT Agent log on VM2, the
> Jetson inference log on the Jetson with a `.log-jetson` extension,
> and the tegrastats log with a `.log-jetson-tegrastats` extension) are
> easy to disambiguate downstream. `7_process_iot_agent_logs.sh`
> globs on `*.log-agent` (see its own section below) so it only ever
> picks up the IoT Agent file, never the Jetson ones.

## Architecture map — which script touches which component

```mermaid
graph TB
    subgraph Client["📡 Producer (VM1)"]
        LG[🖼️ load_generator.py]
    end

    subgraph Jetson["🟢 Jetson Nano"]
        EdgeAPI[⚡ FastAPI /predict<br/>YOLOv11n TensorRT]
    end

    subgraph VM2["☁️ VM2 — FIWARE stack"]
        Nginx[🌐 nginx-reverse-proxy<br/>:7896]
        Orion[📡 Orion-LD<br/>:1026]
        IoTA[🔌 IoT Agent JSON<br/>:4041]
        Mongo[(🗄️ MongoDB<br/>iotagentjson)]
        Context[📄 Apache httpd<br/>@context broker]
    end

    S0[0_healthy_waiting.sh] -->|healthcheck| Orion
    S0 -->|healthcheck| Mongo
    S0 -->|GET| Context

    S1[1_create_IoT_Agent_indices_MongoDB.sh] -->|mongosh| Mongo

    S2[2_create_service_group.sh] -->|POST /iot/services| IoTA
    IoTA -->|registers in| Mongo

    S3[3_provision_devices.sh] -->|POST /iot/devices ×M| IoTA
    IoTA -->|persists| Mongo

    S4[4_verify_provisioned_devices.sh] -->|GET /iot/devices| IoTA

    LG -->|"HTTP POST /predict<br/>raw image"| EdgeAPI
    EdgeAPI -->|"HTTP POST /iot/json<br/>{occupied_spots: N}"| Nginx
    Nginx -->|proxies| IoTA
    IoTA -->|NGSI-LD update| Orion
    IoTA -->|writes| Mongo

    Collector["inline docker logs<br/>(in runner)"] -.->|docker logs| IoTA
    Collector -->|writes| RawLog[(📝 raw_logs_*.log-agent)]

    S6[7_process_iot_agent_logs.sh] -->|reads *.log-agent| RawLog
    S6 -->|writes| CSV[(📊 processed_*.csv)]

    classDef script fill:#E6E6FA,stroke:#333,stroke-width:2px,color:darkblue
    classDef stack fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef jetson fill:#FFD700,stroke:#333,stroke-width:2px,color:black
    classDef store fill:#FFB6C1,stroke:#DC143C,stroke-width:2px,color:black
    classDef client fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue

    class S0,S1,S2,S3,S4,S6,Collector script
    class Nginx,Orion,IoTA,Context stack
    class EdgeAPI jetson
    class Mongo,RawLog,CSV store
    class LG client
```

## Script reference

### 0. `0_healthy_waiting.sh`

**Purpose:** Block until every external dependency is actually serving
traffic, not just *up*. Without this step, `2_create_service_group.sh`
and `3_provision_devices.sh` would race against container startup and
fail with connection-refused errors.

**What it waits for:**

| Dependency | How it checks | Endpoint |
|---|---|---|
| Orion-LD container | Docker healthcheck status | `docker inspect fiware-orion` |
| MongoDB container | Docker healthcheck status | `docker inspect db-mongo` |
| NGSI-LD core `@context` | HTTP `200` from ETSI | `https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context-v1.8.jsonld` |
| User `@context` (Apache) | HTTP `200` via curl in `quay.io/curl/curl` | `http://context/user-context.jsonld` |

**Notes**

- Assumes the default Docker network is named `default` (it uses
  `docker run --network default` for the curl probes).
- `set -e` is **not** active — failures fall through to retries
  rather than aborting the whole pipeline.
- Prints a friendly progress dot every 3 seconds so you can see it is
  alive.

**Parameters:** none.

### 1. `1_create_IoT_Agent_indices_MongoDB.sh`

**Purpose:** Prepare the `iotagentjson` MongoDB database the first time
the stack is brought up. Idempotent only in the sense that it is meant
to be run once; on a non-empty database it **drops every collection
first** and recreates the two required ones (`devices`, `groups`) with
the correct indexes.

> [!WARNING]
> Running this on a populated database wipes all registered devices and
> service groups. Only do this on a fresh stack or when you explicitly
> want to start over.

**What it does:**

1. `mongosh` into the `iotagentjson` DB.
2. Drop every collection (`getCollectionNames().forEach(c => db[c].drop())`).
3. Recreate `devices` with three indexes:
   - `{_id.service, _id.id, _id.type}` (compound)
   - `{_id.type}`
   - `{_id.id}`
4. Recreate `groups` with two indexes:
   - `{_id.resource, _id.apikey, _id.service}` (compound)
   - `{_id.type}`

It also blocks until the `fiware-iot-agent` container is reported
healthy by Docker.

**Parameters:** none.

### 2. `2_create_service_group.sh`

**Purpose:** Register the FIWARE service / subservice / API-key triple
that the IoT Agent uses to route incoming `iot/json` payloads to the
right Orion-LD context broker.

**Hard-coded values** (edit the script if you need to change them):

| Variable | Value |
|---|---|
| `IOTA_HOST` | `http://localhost:4041` |
| `FIWARE_SERVICE` | `unicamp` |
| `FIWARE_SERVICEPATH` | `/parking` |
| `API_KEY` | `12345` |
| `CBROKER` | `http://orion:1026` |
| `ENTITY_TYPE` | `OffStreetParking` |
| `RESOURCE` | `/iot/json` |

**What it does:**

1. `POST /iot/services` to the IoT Agent with the JSON body shown in
   the file, declaring the `apikey`/`cbroker`/`entity_type`/`resource`
   quadruple.
2. `GET /iot/services` to confirm the registration, printing the
   response to stdout.

**Parameters:** none.

### 3. `3_provision_devices.sh`

**Purpose:** Pre-register `M` virtual parking entities with the IoT
Agent so that the Jetson, after each `/predict` inference, can
`POST /iot/json?k=12345&i=NN` for each one without the IoT Agent
having to lazily create entities on the fly. In the edge tier, the
**Jetson** is the producer that posts to the IoT Agent — the load
generator on VM1 only sends raw images to the Jetson, never to the
IoT Agent directly.

**Why `OffStreetParking` and not `ParkingSensor`?** To keep the test
simple, the device is provisioned as a single `OffStreetParking`
entity and the inference result posts the *number of detected cars*
directly to it. There is no intermediate `ParkingSensor` entity: in a
real setup a `ParkingSensor` would report the presence of a single
parking spot, and the IoT Agent would then propagate the update to a
parent `OffStreetParking` entity (which would itself trigger a chain
of further updates). For benchmarking, that chain is unnecessary — a
single camera snapshot already counts the total number of vehicles in
the lot, so posting that count straight into `OffStreetParking` is
enough and lets us measure the IoT Agent / Orion-LD pipeline in
isolation.

**Usage**

```bash
./3_provision_devices.sh <M>
```

- `M` — number of devices to provision. They are numbered with leading
  zeros (`01`, `02`, …, `0M`).
- Each `device_id` maps to a `urn:ngsi-ld:OffStreetParking:<id>` entity.
- Each device exposes a single attribute: `occupiedSpotNumber`
  (object id `occupied_spots`, NGSI-LD `Property`).

**Loop output:** every iteration prints the HTTP status code returned
by `POST /iot/devices` (e.g. `201` on success).

**Parameters:** `M` (positional, required). The script does not
validate that the argument is a positive integer; an empty or
non-numeric `M` will either skip the loop or fail in `seq -w`.

### 4. `4_verify_provisioned_devices.sh`

**Purpose:** Sanity-check that all `M` devices provisioned by
`3_provision_devices.sh` are actually present in the IoT Agent
registry. The runner aborts on failure because of `set -euo pipefail`.

**Usage**

```bash
./4_verify_provisioned_devices.sh <M>
```

- Validates that `M` is a positive integer (exits `2` if not).
- Fetches every device with `GET /iot/devices` (no `?limit=…`, so very
  large `M` may need raising the per-page limit on the IoT Agent
  side).
- Greps the JSON for each expected `device_id` and prints `[✔]` /
  `[✘]` per device.
- Exits `0` if all are present, otherwise prints how many are missing
  and exits `0` (the orchestrator relies on the printed summary, not
  the exit code, for the verdict — it has its own `set -e` at a higher
  level).

**Parameters:** `M` (positional, required).

### 5. `collector_logs.sh`

**Purpose:** One-shot helper that copies the current stdout/stderr of a
named Docker container into a single raw log file, parameterised by the
`M`, `N`, `seeds`, `alpha` and `beta` values of the current test
scenario. It is a stand-alone utility — **it is not invoked by
`edge_deploy_runner.sh`**, which collects the IoT Agent log inline
instead (see "Execution order" above and the note about the
`*.log-agent` extension).

The reason it is shipped in this folder anyway is to make ad-hoc
inspection of a container's log trivial when you are debugging a
stack without wanting to drive a full load test:

```bash
./collector_logs.sh \
  --container fiware-iot-agent \
  --M 136 --N 30 --seeds 2 --alpha 5 --beta 5 \
  --out-dir ./edge_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5
```

**Arguments**

| Flag | Default | Meaning |
|---|---|---|
| `--container` | required | Docker container name or ID to read logs from. |
| `--M` | required | Number of devices — used in the filename suffix. |
| `--N` | required | Number of seconds per seed — used in the filename suffix. |
| `--seeds` | required | Number of seed cycles — used in the filename suffix. |
| `--alpha` | required | Beta distribution α — used in the filename suffix. |
| `--beta` | required | Beta distribution β — used in the filename suffix. |
| `--out-dir` | `./results` | Directory to write the log file into. |

**Output file**

```
raw_logs_<container>_M<M>_N<N>_seeds<seeds>_alpha<alpha>_beta<beta>.log
```

> [!WARNING]
> If you collect IoT Agent logs with `collector_logs.sh` and then run
> `7_process_iot_agent_logs.sh` on the same directory, the processor
> will not pick them up: it globs on `*.log-agent` (the extension the
> runner uses), not `*.log` (the extension this helper uses). Either
> rename the file, symlink it, or rerun the runner's inline
> collection. This mismatch is the reason the runner does the
> collection itself rather than calling this helper.

**Parameters:** see the table above.

### 6. `7_process_iot_agent_logs.sh`

**Purpose:** After the test finishes, walk the raw IoT Agent log
produced by the runner's inline `docker logs` and emit a tidy CSV with
one row per processed update, joining the three pieces of information
that the IoT Agent logs in different lines:

| Field | Source in the log |
|---|---|
| `correlationID` | `corr=<uuid>` |
| `entity_id` | `"id": "urn:ngsi-ld:OffStreetParking:..."` |
| `observedAt` | `"observedAt": "2026-..."` |
| `response_time_ms` | `response-time: <integer>` |

**Usage**

```bash
./7_process_iot_agent_logs.sh --out-dir ./edge_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5
```

- Picks the first `raw_logs_fiware-iot-agent_*.log-agent` file in
  `--out-dir` and produces `processed_<basename>.csv` next to it.
- Uses two associative arrays (`ENTITY`, `OBSERVED`) keyed by the
  current `correlationID` so the final row is emitted only when *all
  three* fields have been seen for that correlation.
- Exits `1` if no matching raw log is found.

**Output columns**

```
correlationID,entity_id,observedAt,response_time_ms
```

**Parameters:** `--out-dir <dir>` (optional, defaults to `.`).

### 7. `cpu_baseline.sh`

**Purpose:** Run this on VM2 **before** a test scenario to capture a
host-side CPU baseline (lscpu, sysbench single- and multi-thread,
`openssl speed`, `mpstat` for `%steal`, a small Python FP microbench,
and current `cpu MHz`). The intent is that, when comparing different
test scenarios against each other, VM2 is reset between runs and this
script is used to confirm that the underlying CPU performance is
comparable — i.e. to rule out hardware / virtualization noise as a
confounding factor in the comparison.

**Usage**

```bash
./cpu_baseline.sh [OUTDIR]   # default: ./baseline_results
```

Each run produces a timestamped prefix `host_<UTC-timestamp>.txt` and
drops several sibling files next to it.

**Files written**

| File | Contents |
|---|---|
| `host_<ts>.txt.lscpu` | Full `lscpu` output. |
| `host_<ts>.txt.model` | First `model name` line from `/proc/cpuinfo`. |
| `host_<ts>.txt.cpuinfo` | Full `/proc/cpuinfo`. |
| `host_<ts>.txt.sysbench_s1` | 10 s sysbench CPU run, 1 thread. |
| `host_<ts>.txt.sysbench_mt` | 10 s sysbench CPU run, `nproc` threads. |
| `host_<ts>.txt.openssl` | `openssl speed aes-128-cbc`. |
| `host_<ts>.txt.mpstat` | 3 × 1 s `mpstat -P ALL` samples. |
| `host_<ts>.txt.cpumhz_before` | First 4 `cpu MHz` lines. |
| `host_<ts>.txt.pybench` | 2 000 000 Python `math.sqrt` calls. |

**Dependencies**

- `sysbench` (auto-installed via `apt-get` if missing).
- `sysstat` (auto-installed for `mpstat`).
- `openssl` and `python3` (only used if present).
- `sudo` is required for the apt-get calls — run as a sudoer or
  preinstall the packages.

**Parameters:** `OUTDIR` (positional, optional, default
`./baseline_results`).

## Log processing data flow

The pair `docker logs` (inline in the runner) + `7_process_iot_agent_logs.sh`
implements a two-stage ETL: capture, then join-and-flatten. The
Jetson-side inference log follows an analogous two-stage path on the
device, described in [`../onJetson/README.md`](../onJetson/README.md).

```mermaid
flowchart LR
    subgraph Capture["Stage 1 — capture (after test)"]
        Container[🐳 fiware-iot-agent<br/>stdout/stderr]
        Coll[📝 inline docker logs<br/>in edge_deploy_runner.sh]
        Raw[(📝 raw_logs_*.log-agent)]
        Container --> Coll --> Raw
    end

    subgraph Process["Stage 2 — process (after test)"]
        Raw --> Parse[🔍 7_process_iot_agent_logs.sh<br/>regex on each line]
        Parse -->|corr= uuid| State[(🧠 in-memory bash assoc arrays<br/>ENTITY, OBSERVED)]
        State -->|"response-time: N<br/>flush + reset"| CSV[(📊 processed_*.csv)]
    end

    CSV -->|scp to VM1| Analysis[📈 correlation with<br/>response_times_*.csv]

    classDef stage fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef store fill:#FFB6C1,stroke:#DC143C,stroke-width:2px,color:black
    classDef step fill:#E6E6FA,stroke:#333,stroke-width:2px,color:darkblue

    class Capture,Process stage
    class Raw,CSV,State store
    class Coll,Parse,Analysis step
```

## Running the scripts by hand

You rarely need to invoke these directly — `edge_deploy_runner.sh`
does it for you — but if you are debugging, here is the exact order.
Run each on VM2, **after** `docker compose -f infra/compose.yaml up -d`:

```bash
# 0. wait for everything to be ready
./0_healthy_waiting.sh

# 1. prepare Mongo (CAUTION: drops existing collections in iotagentjson)
./1_create_IoT_Agent_indices_MongoDB.sh

# 2. register the service group
./2_create_service_group.sh

# 3. provision M devices
./3_provision_devices.sh 136

# 4. verify they are all there
./4_verify_provisioned_devices.sh 136

# (5. load test is driven from VM1; the runner does not background a
#     log collector on VM2 — it does a one-shot docker logs after the
#     test has finished)

# 6. after the test, convert the raw log
./7_process_iot_agent_logs.sh \
  --out-dir ./edge_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5
```

> **Prerequisites inside VM2**
> - `docker` on the path and the user in the `docker` group.
> - `curl` (or just rely on the `quay.io/curl/curl` image, which is
>   what `0_healthy_waiting.sh` does).
> - `mongosh` reachable through the `db-mongo` container
>   (`docker exec db-mongo mongosh`).
> - `python3` on the host for `cpu_baseline.sh`.

## Outputs produced on VM2

For a single test run with parameters `M=136 N=30 seed=2 alpha=5 beta=5`
VM2 ends up with this directory:

```text
onVMScripts/edge_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5/
├── VM_edge_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5.log
└── raw_logs_fiware-iot-agent_M_136_N_30_seeds_2_alpha_5_beta_5.log-agent
└── processed_raw_logs_fiware-iot-agent_M_136_N_30_seeds_2_alpha_5_beta_5.csv
```

The `edge_deploy_runner.sh` script then `scp`s the whole directory back
to VM1's `onGenScripts/`. The matching Jetson-side directory
(`onJetson/edge_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5/`) is
scp'd back in parallel and contains the tegrastats trace and the
inference CSV.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `0_healthy_waiting.sh` hangs on `@context HTTP state: 000` | The VM has no outbound internet access to `uri.etsi.org`, or the Apache httpd context broker container is not running. | Confirm `docker ps` shows the context broker up; if you are in an air-gapped environment, pre-cache the JSON-LD contexts. |
| `2_create_service_group.sh` returns `404` | The IoT Agent container is not on the `default` network, or you are not running from VM2. | Run from inside VM2 (`ssh` then execute), and confirm `docker network inspect default` lists `fiware-iot-agent`. |
| `3_provision_devices.sh` reports non-`201` codes | Service group from step 2 is missing, or `M` is `0`/non-numeric. | Re-run `2_create_service_group.sh`. The script does not validate its argument. |
| `4_verify_provisioned_devices.sh` says devices are missing | IoT Agent limit reached (default `1000`) for very large `M`, or provision step silently failed. | Lower the per-page `limit` query or split provisioning. Check step 3's HTTP status output. |
| `7_process_iot_agent_logs.sh` exits with `No matching log file found` | The runner's inline `docker logs` did not run, or `--out-dir` does not match what was passed to the runner, or you used `collector_logs.sh` (which produces a `.log` file, not a `.log-agent` one). | Confirm the `.log-agent` file exists in the directory you pass to `--out-dir`; if you used `collector_logs.sh`, rename the file or rerun via the runner. |
| `cpu_baseline.sh` aborts on `apt-get` | The user cannot `sudo`. | Preinstall `sysbench` and `sysstat`, or run the script as root. |
