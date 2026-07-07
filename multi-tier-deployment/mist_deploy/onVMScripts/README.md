# onVMScripts — VM2 provisioning & measurement scripts

This directory holds the scripts that are executed **inside VM2**, the
remote VM that hosts the Docker Compose stack (Orion-LD, IoT Agent JSON,
MongoDB, Prometheus, etc.) during a mist-tier load test. The companion
orchestrator `../onGeneratorScripts/mist_deploy_runner.sh` runs on VM1
(another VM in the Institute of Computing Cloud via OpenStack) and
invokes these scripts over SSH as part of the end-to-end test pipeline.

The scripts are intentionally numbered (`0_`…`7_`) so the orchestrator can
run them in the correct order; the two unnumbered files
(`docker_logs_collector.py` and `cpu_baseline.sh`) are independent
utilities.

> **TL;DR** — `0` waits for the stack to be healthy, `1` prepares Mongo,
> `2`/`3`/`4` register and verify the IoT devices, `docker_logs_collector.py`
> streams the IoT Agent log in the background during the test, and `7`
> converts that raw log into a CSV once the test finishes.
> `cpu_baseline.sh` is meant to be run on VM2 **before** each test run:
> after resetting VM2, it captures a CPU baseline so that the different
> test scenarios being compared are not biased by hardware / virtualization
> noise.

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
  - [5. `docker_logs_collector.py`](#5-docker_logs_collectorpy)
  - [6. `7_process_iot_agent_logs.sh`](#6-7_process_iot_agent_logssh)
  - [7. `cpu_baseline.sh`](#7-cpu_baselinesh)
- [Log processing data flow](#log-processing-data-flow)
- [Running the scripts by hand](#running-the-scripts-by-hand)
- [Outputs produced on VM2](#outputs-produced-on-vm2)
- [Troubleshooting](#troubleshooting)

## Overview — VM1 and VM2

The load-test setup spans two OpenStack VMs from the Institute of
Computing Cloud:

- **VM1 — load generator / orchestrator.** Runs
  `../onGeneratorScripts/mist_deploy_runner.sh`, `load_generator.py`,
  `get_metrics_posttest.py`, and the local virtual environment. It does
  *not* host any FIWARE component; it only generates traffic and collects
  metrics.
- **VM2 — system under test.** Runs the Docker Compose stack
  (Orion-LD, IoT Agent JSON, MongoDB, Prometheus, cAdvisor, Node
  Exporter, the nginx reverse proxy, etc.) and is where the scripts in
  this folder are executed.

```mermaid
flowchart LR
    VM1["🖥️ VM1<br/>load generator / orchestrator<br/>(onGeneratorScripts)"]
    VM2["☁️ VM2<br/>system under test<br/>(this folder: onVMScripts + Docker stack)"]

    VM1 -- "🔗 sshpass ssh (pipeline)<br/>📋 sshpass scp (results back)" --> VM2
    VM1 -- "⚡ HTTP POST /iot/json<br/>(load_generator.py → nginx → IoT Agent)" --> VM2
    VM1 -- "📈 PromQL queries<br/>(get_metrics_posttest.py → Prometheus)" --> VM2

    classDef vm1 fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue
    classDef vm2 fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    class VM1 vm1
    class VM2 vm2
```

## How this folder fits in the pipeline

The VM1-side orchestrator
(`multi-tier-deployment/mist_deploy/onGeneratorScripts/mist_deploy_runner.sh`)
opens an SSH session into VM2 and runs the following sequence against
this folder. The directory layout on VM2 is assumed to be
`$VM_dir/onVMScripts/` (the path is read from `mist_deploy.conf` via the
`onVM_dir` variable).

```mermaid
flowchart LR
    subgraph VM1["🖥️ VM1 (load generator)"]
        Runner[⚙️ mist_deploy_runner.sh]
    end

    subgraph VM2["☁️ VM2 (system under test)"]
        direction TB
        S0[0_healthy_waiting.sh]
        S1[1_create_IoT_Agent_indices_MongoDB.sh]
        S2[2_create_service_group.sh]
        S3[3_provision_devices.sh M]
        S4[4_verify_provisioned_devices.sh M]
        S5[docker_logs_collector.py<br/>nohup & background]
        S6[7_process_iot_agent_logs.sh]
    end

    Runner -- "sshpass ssh" --> S0
    S0 --> S1 --> S2 --> S3 --> S4 --> S5
    Runner -. "sshpass ssh (later)" .-> S6
    Runner -- "sshpass scp<br/>back to VM1" --> Runner

    classDef vm1 fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue
    classDef vm2 fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    class Runner vm1
    class S0,S1,S2,S3,S4,S5,S6 vm2
```

`cpu_baseline.sh` is not part of this pipeline — see its own section below.

## Execution order

The numbered prefix on each script is the order in which the orchestrator
runs them. The flowchart below mirrors the exact call sequence in
`mist_deploy_runner.sh`.

```mermaid
flowchart TD
    Start([▶ mist_deploy_runner.sh<br/>on VM1]) --> Up[🐳 docker compose up -d]
    Up --> Wait30[⏳ sleep 30s]
    Wait30 --> S0[0_healthy_waiting.sh<br/>Orion-LD, MongoDB, @context]
    S0 --> S1[1_create_IoT_Agent_indices_MongoDB.sh<br/>drop + recreate iotagentjson collections]
    S1 --> S2[2_create_service_group.sh<br/>service=unicamp path=/parking key=12345]
    S2 --> S3[3_provision_devices.sh M<br/>register M OffStreetParking devices]
    S3 --> S4[4_verify_provisioned_devices.sh M<br/>assert all M are present]
    S4 --> S5["docker_logs_collector.py<br/>--M M --N N --seeds seed --alpha a --beta b<br/>nohup &amp; background"]
    S5 --> HandBack([↩️ control back to VM1])
    HandBack --> LoadGen[⚡ load_generator.py on VM1]
    LoadGen --> Metrics[📊 get_metrics_posttest.py on VM1]
    Metrics --> S6[7_process_iot_agent_logs.sh<br/>--out-dir .../DIRNAME]
    S6 --> SCP[📋 scp results back to VM1]
    SCP --> Done([✅ Done])

    classDef vm1 fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue
    classDef vm2 fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef step fill:#E6E6FA,stroke:#333,stroke-width:2px,color:darkblue

    class Start,HandBack,LoadGen,Metrics,Done vm1
    class Up,Wait30,S0,S1,S2,S3,S4,S5,S6,SCP vm2
    class S0,S1,S2,S3,S4,S5,S6 step
```

> **Why the gap between 4 and 7?** There are no `5_` and `6_` scripts on
> disk. The pipeline was restructured at some point (steps that used to
> live in their own files were either folded into another step or
> dropped entirely), but the numeric prefixes of the remaining files
> were left untouched so that the calling code in
> `mist_deploy_runner.sh` did not have to be modified. The log collector
> is intentionally unnumbered and started in the background; the
> orchestrator then runs the load generator from VM1 *against* VM2 and
> only comes back to process the logs once the load test has finished.

## Architecture map — which script touches which component

```mermaid
graph TB
    subgraph Client["📡 Producer (VM1)"]
        LG[⚡ load_generator.py]
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

    S5[docker_logs_collector.py] -.->|docker logs -f| IoTA
    S5 -->|writes| RawLog[(📝 raw_docker_logs_*.log)]

    LG -->|"HTTP POST /iot/json?k=...&amp;i=..."| Nginx
    Nginx -->|proxies| IoTA
    IoTA -->|NGSI-LD update| Orion
    IoTA -->|writes| Mongo

    S6[7_process_iot_agent_logs.sh] -->|reads| RawLog
    S6 -->|writes| CSV[(📊 processed_*.csv)]

    classDef script fill:#E6E6FA,stroke:#333,stroke-width:2px,color:darkblue
    classDef stack fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef store fill:#FFB6C1,stroke:#DC143C,stroke-width:2px,color:black
    classDef client fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue

    class S0,S1,S2,S3,S4,S5,S6 script
    class Nginx,Orion,IoTA,Context stack
    class Mongo,RawLog,CSV store
    class LG client
```

## Script reference

### 0. `0_healthy_waiting.sh`

**Purpose:** Block until every external dependency is actually serving
traffic, not just *up*. Without this step, `2_create_service_group.sh` and
`3_provision_devices.sh` would race against container startup and fail
with connection-refused errors.

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
- Uses `set -e` is **not** active — failures fall through to retries
  rather than aborting the whole pipeline.
- Prints a friendly progress dot every 3 seconds so you can see it is
  alive.

**Parameters:** none.

### 1. `1_create_IoT_Agent_indices_MongoDB.sh`

**Purpose:** Prepare the `iotagentjson` MongoDB database the first time
the stack is brought up. Idempotent only in the sense that it is meant to
be run once; on a non-empty database it **drops every collection first**
and recreates the two required ones (`devices`, `groups`) with the
correct indexes.

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

1. `POST /iot/services` to the IoT Agent with the JSON body shown in the
   file, declaring the `apikey`/`cbroker`/`entity_type`/`resource`
   quadruple.
2. `GET /iot/services` to confirm the registration, printing the response
   to stdout.

**Parameters:** none.

### 3. `3_provision_devices.sh`

**Purpose:** Pre-register `M` virtual parking entities with the IoT Agent
so that the load generator on VM1 can `POST /iot/json?k=12345&i=NN` for
each one without the IoT Agent having to lazily create entities on the
fly.

**Why `OffStreetParking` and not `ParkingSensor`?** To keep the test
simple, the device is provisioned as a single `OffStreetParking` entity
and the load generator posts the *number of detected cars* directly to
it. There is no intermediate `ParkingSensor` entity: in a real setup a
`ParkingSensor` would report the presence of a single parking spot, and
the IoT Agent would then propagate the update to a parent
`OffStreetParking` entity (which would itself trigger a chain of further
updates). For benchmarking, that chain is unnecessary — a single camera
snapshot already counts the total number of vehicles in the lot, so
posting that count straight into `OffStreetParking` is enough and lets
us measure the IoT Agent / Orion-LD pipeline in isolation.

**Usage**

```bash
./3_provision_devices.sh <M>
```

- `M` — number of devices to provision. They are numbered with leading
  zeros (`001`, `002`, …, `0M`).
- Each `device_id` maps to a `urn:ngsi-ld:OffStreetParking:<id>` entity.
- Each device exposes a single attribute: `occupiedSpotNumber`
  (object id `occupied_spots`, NGSI-LD `Property`).

**Loop output:** every iteration prints the HTTP status code returned by
`POST /iot/devices` (e.g. `201` on success).

**Parameters:** `M` (positional, required).

### 4. `4_verify_provisioned_devices.sh`

**Purpose:** Sanity-check that all `M` devices provisioned by
`3_provision_devices.sh` are actually present in the IoT Agent registry.
The runner aborts on failure because of `set -euo pipefail`.

**Usage**

```bash
./4_verify_provisioned_devices.sh <M>
```

- Validates that `M` is a positive integer (exits `2` if not).
- Fetches every device with `GET /iot/devices?limit=1000` (note: no
  pagination, so very large `M` may need raising the limit).
- Greps the JSON for each expected `device_id` and prints `[✔]` /
  `[✘]` per device.
- Exits `0` if all are present, otherwise prints how many are missing
  and exits `0` (the orchestrator relies on the printed summary, not the
  exit code, for the verdict — it has its own `set -e` at a higher level).

**Parameters:** `M` (positional, required).

### 5. `docker_logs_collector.py`

**Purpose:** Stream the stdout/stderr of the `fiware-iot-agent` Docker
container into a single raw log file, anchored to the test start time.
It is launched in the background by the orchestrator with `nohup … &`
and lives for the whole test.

**Usage**

```bash
python3 docker_logs_collector.py \
  --M 136 --N 30 --seeds 2 --alpha 5 --beta 5 \
  --container fiware-iot-agent \
  --out-dir ./mist_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5
```

**Arguments**

| Flag | Default | Meaning |
|---|---|---|
| `--M` | required | Number of devices — used in the filename suffix. |
| `--N` | required | Number of seconds per seed — used in the filename suffix. |
| `--seeds` | required | Number of seed cycles — used in the filename suffix. |
| `--alpha` | `1.0` | Beta distribution α — used in the filename suffix. |
| `--beta` | `1.0` | Beta distribution β — used in the filename suffix. |
| `--container` | `fiware-iot-agent` | Docker container to follow. |
| `--out-dir` | `./results` | Directory to write the log file into. |

**Output file**

```
raw_docker_logs_fiware-iot-agent_M_136_N_30_seed_2_alpha_5_beta_5.log
```

- Captures the start timestamp with `datetime.utcnow().isoformat()` and
  uses it as `--since` for `docker logs -f`, so only lines emitted from
  that moment on are written.
- Stop with **Ctrl+C**; the script sends `SIGINT` to `docker logs`,
  waits up to 5 s, then `SIGKILL`s it if needed.

**Parameters:** see the table above.

### 6. `7_process_iot_agent_logs.sh`

**Purpose:** After the test finishes, walk the raw IoT Agent log
produced by `docker_logs_collector.py` and emit a tidy CSV with one row
per processed update, joining the three pieces of information that the
IoT Agent logs in different lines:

| Field | Source in the log |
|---|---|
| `correlationID` | `corr=<uuid>` |
| `entity_id` | `"id": "urn:ngsi-ld:OffStreetParking:..."` |
| `observedAt` | `"observedAt": "2026-..."` |
| `response_time_ms` | `response-time: <integer>` |

**Usage**

```bash
./7_process_iot_agent_logs.sh --out-dir ./mist_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5
```

- Picks the first `raw_docker_logs_fiware-iot-agent_M_*.log` file in
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
- `sudo` is required for the apt-get calls — run as a sudoer or preinstall
  the packages.

**Parameters:** `OUTDIR` (positional, optional, default `./baseline_results`).

## Log processing data flow

The pair `docker_logs_collector.py` + `7_process_iot_agent_logs.sh`
implements a two-stage ETL: capture, then join-and-flatten.

```mermaid
flowchart LR
    subgraph Capture["Stage 1 — capture (during test)"]
        Container[🐳 fiware-iot-agent<br/>stdout/stderr]
        Coll[📝 docker_logs_collector.py<br/>docker logs -f --since T0]
        Raw[(📝 raw_docker_logs_*.log)]
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

You rarely need to invoke these directly — `mist_deploy_runner.sh` does
it for you — but if you are debugging, here is the exact order. Run each
on VM2, **after** `docker compose -f infra/compose.yaml up -d`:

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

# 5. (in another shell, or with &) start the log collector
mkdir -p ./mist_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5
python3 ./docker_logs_collector.py \
  --M 136 --N 30 --seeds 2 --alpha 5 --beta 5 \
  --out-dir ./mist_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5

# 6. run the load generator from VM1
#    ...

# 7. after the test, convert the raw log
./7_process_iot_agent_logs.sh \
  --out-dir ./mist_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5
```

> **Prerequisites inside VM2**
> - `docker` on the path and the user in the `docker` group.
> - `curl` (or just rely on the `quay.io/curl/curl` image, which is what
>   `0_healthy_waiting.sh` does).
> - `mongosh` reachable through the `db-mongo` container
>   (`docker exec db-mongo mongosh`).
> - `python3` on the host for `docker_logs_collector.py` and
>   `cpu_baseline.sh`.

## Outputs produced on VM2

For a single test run with parameters `M=136 N=30 seed=2 alpha=5 beta=5`
VM2 ends up with this directory:

```
onVMScripts/mist_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5/
├── VM_mist_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5.log
├── VM_mist_deploy_test_M_136_N_30_seed_2_alpha_5_beta_5.log.collector
├── raw_docker_logs_fiware-iot-agent_M_136_N_30_seed_2_alpha_5_beta_5.log
└── processed_raw_docker_logs_fiware-iot-agent_M_136_N_30_seed_2_alpha_5_beta_5.csv
```

The `mist_deploy_runner.sh` script then `scp`s the whole directory back
to VM1's `onGeneratorScripts/`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `0_healthy_waiting.sh` hangs on `@context HTTP state: 000` | The VM has no outbound internet access to `uri.etsi.org`, or the Apache httpd context broker container is not running. | Confirm `docker ps` shows the context broker up; if you are in an air-gapped environment, pre-cache the JSON-LD contexts. |
| `2_create_service_group.sh` returns `404` | The IoT Agent container is not on the `default` network, or you are not running from VM2. | Run from inside VM2 (`ssh` then execute), and confirm `docker network inspect default` lists `fiware-iot-agent`. |
| `3_provision_devices.sh` reports non-`201` codes | Service group from step 2 is missing, or `M` is `0`/non-numeric. | Re-run `2_create_service_group.sh`. The script does not validate its argument. |
| `4_verify_provisioned_devices.sh` says devices are missing | IoT Agent limit reached (default `1000`) for very large `M`, or provision step silently failed. | Lower the per-page `limit` query or split provisioning. Check step 3's HTTP status output. |
| `7_process_iot_agent_logs.sh` exits with `No matching log file found` | The `docker_logs_collector.py` process did not start, or `--out-dir` does not match what was passed at collection time. | Confirm the `.log` file exists in the directory you pass to `--out-dir`. |
| `cpu_baseline.sh` aborts on `apt-get` | The user cannot `sudo`. | Preinstall `sysbench` and `sysstat`, or run the script as root. |
