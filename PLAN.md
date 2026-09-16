# Empirical Evaluation of ARM64 (AWS Graviton) vs. x86_64 Architectures: Quantifying Throughput, Energy Efficiency, and Operational Carbon Footprint

> ### 📜 Authorship & Intellectual Property Declaration
> **Author & Principal Researcher:** Phạm Hồng Phát |
> **Intellectual Ownership:** Phạm Hồng Phát.
> 
> **AI Assistance Disclosure:**  
> This research project and repository utilize Artificial Intelligence (AI) tools for code scaffolding, documentation formatting, and syntactic refinement. However, the **core thesis, research hypothesis ($H_1$), experimental methodology, mathematical metrics formulation, hardware topology design, and technical direction are conceptualized, authored, and owned exclusively by Phạm Hồng Phát**. All experimental validation, data verification, and conclusions represent the author's original work.

---

## 1. Thesis & Research Objectives

### Primary Thesis Statement
> **$H_1$ (Alternative Hypothesis):** Under identical containerized microservice workloads, AWS Graviton (ARM64) instance families achieve significantly higher compute throughput per watt ($\text{RPS/W}$) and lower operational carbon intensity ($\text{gCO}_2\text{e}$ per 1 million requests) than equivalent x86_64 instance families, without incurring latency penalties at  $p_{95}$ and  $p_{99}$ percentiles.

### Null Hypothesis
> **$H_0$:** There is no statistically significant difference ($p > 0.05$) in energy efficiency ($\text{Joules/request}$) or carbon footprint between ARM64 Graviton instances and x86_64 instances for identical compute-bound backend workloads.

---

## 2. Experimental Setup & Hardware Topology

To eliminate hardware allocation noise, tests must run on dedicated, non-burstable compute instances across equivalent instance tiers within the same AWS Availability Zone (AZ).

```text
+---------------------------------------------------------------------------------+
|                                 LOAD GENERATOR                                  |
|                 Dedicated `c6i.2xlarge` running k6 / wrk2                       |
+----------------------------------------+----------------------------------------+
                                         |
                            Private VPC Subnet (10 Gbps)
                                         |
                    +--------------------+--------------------+
                    |                                         |
                    v                                         v
+---------------------------------------+ +---------------------------------------+
|          CONTROL GROUP (x86_64)       | |           TEST GROUP (ARM64)        |
|  Instance: c6i.xlarge (4 vCPU, 8 GiB) | |  Instance: c7g.xlarge (4 vCPU, 8 GiB)|
|  Arch: Intel Ice Lake (3.5 GHz)       | |  Arch: AWS Graviton3 (Neoverse V1)   |
|  OS: Ubuntu 24.04 LTS (x86_64)        | |  OS: Ubuntu 24.04 LTS (arm64)        |
|  Runtime: Go 1.22 (linux/amd64)       | |  Runtime: Go 1.22 (linux/arm64)       |
+-------------------+-------------------+ +-------------------+-------------------+
                    |                                         |
                    v                                         v
+---------------------------------------+ +---------------------------------------+
|            TELEMETRY STACK            | |            TELEMETRY STACK            |
|  - Kepler (eBPF Energy Profiler)      | |  - Kepler (eBPF Energy Profiler)      |
|  - Prometheus Node Exporter           | |  - Prometheus Node Exporter           |
|  - Scaphandre (Power Estimator)       | |  - Scaphandre (Power Estimator)       |
+-------------------+-------------------+ +-------------------+-------------------+
                    |                                         |
                    +--------------------+--------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                            CENTRAL DASHBOARD STACK                              |
|                   Prometheus Server + Grafana Visualization                     |
+---------------------------------------------------------------------------------+