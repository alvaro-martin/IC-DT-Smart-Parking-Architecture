# multi-tier-deployment

This folder contains the research artefacts of the **4 × 9 × 9 full-factorial
load-test campaign** that compares four deployment strategies for the
FIWARE NGSI-LD Digital-Twin smart-parking stack. One folder per strategy,
each self-contained and reproducible on the hardware target listed in its
own README.

## What the four strategies have in common

Across all four tiers, the **system under test on VM2 is identical**: the
Interface component (NGINX), the Core component (Orion-LD Context Broker,
IoT Agent JSON, MongoDB, the LD `@context` server), and the Infrastructure
Monitoring component (Prometheus, Grafana, cAdvisor, Node Exporter).
VM1 is always the load generator and orchestrator. The campaign is the
same full-factorial design on every tier:

| Factor | Levels | Count |
|---|---|---|
| **A — Deployment Strategy** | `mist`, `edge`, `fog`, `cloud` | 4 |
| **B — Workload** (Beta-distribution shape, B1..B9) | (1,1), (1,5), (5,1), (5,5), (2,5), (5,2), (2,2), (10,10), (100,100) | 9 |
| **C — Traffic Shape** (`M` devices / `N` seconds, C1..C9) | 136/30, 136/60, 136/120, 136/180, 136/240, 136/300, 250/60, 500/60, 1000/60 | 9 |

4 × 9 × 9 = **324** experiments; **81 per tier**, with 100 internal
repetitions each. Each tier shuffles its 81 scenarios with its own
deterministic seed (`mist` = 27, `edge` = 8, `fog` = 37; `cloud` differs)
because each tier is operated on different hardware and the
inter-tier ordering is independent.

## What the four strategies differ in

The single axis of variation is **where the vehicle-counting inference
runs**, and consequently what VM1 sends on the wire. All other pieces
of the system are kept the same so the comparison isolates the effect
of the deployment tier.

| Tier | Inference host | Model / format | What VM1 sends | Networking |
|---|---|---|---|---|
| **mist** | none (simulated on the device) | n/a | pre-processed `{"occupied_spots": N}` | Tailscale |
| **edge** | NVIDIA Jetson Nano (ARM + Maxwell GPU) | YOLOv11n → TensorRT | raw parking image (multipart) | Tailscale |
| **fog** | IC Discovery Lab cluster node (x86 + GTX 1080) | YOLOv11m → TensorRT 8.6 + CUDA 11.8 | raw parking image (multipart) | Tailscale |
| **cloud** | container **on VM2 itself** (CPU-only) | YOLOv11m → OpenVINO int8 | raw parking image (multipart) | Tailscale for the image hop; inter-container for the count hop |

Mist is the only tier that skips inference entirely; edge, fog and
cloud all share the same **image-in / count-out** contract with VM2 and
differ only in the inference host and the model format.

## The four deployments at a glance

### `mist_deploy/` — local inference on the field device

![Mist deployment diagram](./mist_deploy/mist_deployment.png)

The image is processed locally on the field device (a Raspberry Pi in
the conceptual design; the Load Generator Script in this benchmark).
Only the resulting `{"occupied_spots": N}` payload is transmitted.

- 2 nodes: VM1 (load generator) + VM2 (system under test), Tailscale.
- Tier README: [`mist_deploy/README.md`](./mist_deploy/README.md)

### `edge_deploy/` — inference on a Jetson Nano at the edge

![Edge deployment diagram](./edge_deploy/edge_deployment.png)

VM1 sends the raw parking image to a co-located **NVIDIA Jetson
Nano**, which runs YOLOv11n on the TensorRT engine and forwards the
count to VM2. This is the only tier with field-edge hardware
participating in the data path.

- 3 nodes: VM1 + Jetson Nano + VM2, all Tailscale.
- Tier README: [`edge_deploy/README.md`](./edge_deploy/README.md)

### `fog_deploy/` — inference on a Discovery Lab GPU cluster

![Fog deployment diagram](./fog_deploy/fog_deployment.png)

VM1 sends the raw parking image to a **GPU-enabled node of the IC
Discovery Lab cluster** (GTX 1080), which runs YOLOv11m on TensorRT
8.6 and forwards the count to VM2.

- 3 nodes: VM1 + Discovery cluster node + VM2, all Tailscale.
- Tier README: [`fog_deploy/README.md`](./fog_deploy/README.md)

### `cloud_deploy/` — inference co-located with the system on VM2

![Cloud deployment diagram](./cloud_deploy/cloud_deployment.png)

The inference service is a **container on VM2 itself**, alongside the
rest of the `docker compose` stack. VM1 sends the raw image to it over
Tailscale; the count hop back to the IoT Agent is inter-container on
VM2 (no Tailscale). The IC cloud VMs are CPU-only, so the model is
exported to **OpenVINO int8** instead of TensorRT.

- 2 nodes: VM1 + VM2, with inference co-located on VM2.
- Tier README: [`cloud_deploy/README.md`](./cloud_deploy/README.md)

## Where to go next

Each tier folder is the authoritative reference for that slice —
hardware spec, data flow, node assignment, the full folder layout, the
glossary from thesis terminology to on-disk artefacts, and the quick
start for running the campaign. Start with the tier you want to
reproduce:

- [`mist_deploy/README.md`](./mist_deploy/README.md)
- [`edge_deploy/README.md`](./edge_deploy/README.md)
- [`fog_deploy/README.md`](./fog_deploy/README.md)
- [`cloud_deploy/README.md`](./cloud_deploy/README.md)
