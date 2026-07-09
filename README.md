# IC-DT-Smart-Parking-Architecture

Reference implementation of a **Digital-Twin-based Smart Parking architecture** for the Smart Campus of the **University of Campinas (UNICAMP)**. This repository accompanies the Master's Thesis:

> **Proposal and Evaluation of a Software Architecture for a Smart Campus Digital Twin**
> — Alvaro Martín, Aspilcueta Narváez, Institute of Computing, UNICAMP.

The full thesis is available as a PDF alongside this repository:
[`Proposal_and_Evaluation_of_a_Software_Architecture_for_a_Smart_Campus_Digital_Twin.pdf`](./Proposal_and_Evaluation_of_a_Software_Architecture_for_a_Smart_Campus_Digital_Twin.pdf).

## Problem statement

Smart parking solutions based on IoT and computer vision have been widely explored in both Smart City and Smart Campus contexts. At UNICAMP, the Institute of Computing has long operated such a system on the IC-2 parking lot, evolving it through several iterations. While effective for localized monitoring, scaling it to the whole campus surfaces new challenges around performance, data processing, resource utilization, and interoperability, while the Institute's heterogeneous infrastructure (embedded and edge devices, institutional cloud, GPU-enabled clusters) enables multiple implementation strategies spanning cloud, fog, edge, and mist computing.

In parallel, Digital Twin technology has gained traction, but its application to Smart Campus environments — and Smart Parking in particular — remains underexplored. Existing implementations often focus on isolated capabilities (monitoring, visualization, service provision), and many urban DTs still operate at early or intermediate maturity levels. Furthermore, deploying vision-based systems at scale raises questions about the trade-offs of cloud, fog, edge, and mist computing, especially on resource-constrained tiers where detection performance must be balanced with processing efficiency.

This work proposes a Digital-Twin paradigm for smart parking that supports scalable Smart Campus deployment and interoperability, with real-time monitoring, data-driven analysis, what-if scenario simulation, and a systematic evaluation of deployment strategies.

## Repository structure

The repository is organized in **two stages**, each corresponding to a part of the thesis.

### Stage 1 — Digital-Twin prototype

The first stage builds the DT on top of UNICAMP's existing vision-based pipeline (Raspberry Pi + YOLO + InfluxDB) and implements the full architecture defined in the thesis:

- **NGSI-LD integration** through FIWARE (Orion-LD, IoT Agent, MongoDB, CrateDB, QuantumLeap, Grafana).
- **Application and infrastructure monitoring** dashboards backed by Prometheus, cAdvisor, and Node Exporter.
- **Monte Carlo "what-if" simulation** with a Streamlit UI (manual and LLM-assisted interfaces).
- **NGINX reverse proxy** with SSL termination for HTTPS access.

See [`IC2-digital-twin/README.md`](./IC2-digital-twin/README.md) for the architecture, entity model, services, and quick start.

### Stage 2 — Multi-tier deployment evaluation

The second stage runs a **4 × 9 × 9 full-factorial load-test campaign** that compares four deployment strategies for the FIWARE NGSI-LD smart-parking stack. The system under test is kept identical across tiers; the only axis of variation is **where the vehicle-counting inference runs**:

- **mist** — local inference on the field device; only the processed count is transmitted.
- **edge** — inference on a co-located NVIDIA Jetson Nano.
- **fog** — inference on a node of the IC Discovery Lab GPU cluster.
- **cloud** — inference co-located with the system on a cloud container (OpenVINO int8).

See [`multi-tier-deployment/README.md`](./multi-tier-deployment/README.md) for the experimental design, then drill into each tier:

- [`multi-tier-deployment/mist_deploy/`](./multi-tier-deployment/mist_deploy/README.md)
- [`multi-tier-deployment/edge_deploy/`](./multi-tier-deployment/edge_deploy/README.md)
- [`multi-tier-deployment/fog_deploy/`](./multi-tier-deployment/fog_deploy/README.md)
- [`multi-tier-deployment/cloud_deploy/`](./multi-tier-deployment/cloud_deploy/README.md)

> [!NOTE]
> Per-folder READMEs are the authoritative reference for each slice (hardware spec, data flow, folder layout, glossary, quick start). The root README is intentionally high-level.

## Author

**Alvaro Martín, Aspilcueta Narváez** — Institute of Computing, UNICAMP.

- Personal site: <https://alvaro-martin.github.io/personal-site/>
- LinkedIn: <https://www.linkedin.com/in/almartinuni/>
- GitHub: <https://github.com/alvaro-martin>
