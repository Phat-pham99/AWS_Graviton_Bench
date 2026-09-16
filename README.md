# AWS_Graviton_Bench

Empirical Evaluation of **ARM64 (AWS Graviton)** vs. **x86_64** Architectures:
Quantifying Throughput, Energy Efficiency, and Operational Carbon Footprint.

> **Author & Principal Researcher:** Pham Hong Phat.
> Intellectual ownership of the thesis, hypothesis ($H_1$), methodology, metrics
> formulation, and hardware topology design belongs to the author.

---

## 1. Research Question & Hypotheses

**Alternative ($H_1$):** Under identical containerized microservice workloads,
AWS Graviton (ARM64) instance families achieve significantly higher
throughput-per-watt ($\text{RPS/W}$) and lower operational carbon intensity
($\text{gCO}_2\text{e}$ per 1M requests) than equivalent x86_64 instances,
without latency penalties at $p_{95}$ / $p_{99}$.

**Null ($H_0$):** No statistically significant difference ($p>0.05$) in energy
efficiency (Joules/request) or carbon footprint between ARM64 Graviton and
x86_64 for identical compute-bound workloads.

## 2. Experimental Topology (from PLAN.md)

Single AWS AZ; dedicated non-burstable instances on equivalent tiers:

```
LOAD GENERATOR  c6i.2xlarge (x86_64)  -> k6 / wrk2         (10 Gbps private VPC)
  |                                  |
  v                                  v
CONTROL GROUP            TEST GROUP
c6i.xlarge (4vCPU,8GiB)  c7g.xlarge (4vCPU,8GiB)
x86_64 Intel Ice Lake    arm64 Graviton3 (Neoverse V1)
+ Kepler/Scaphandre/Node Exporter telemetry on each SUT
  |
  v
CENTRAL DASHBOARD: Prometheus Server + Grafana
```

## 3. Repository Layout

| Path           | Responsibility                                          |
|----------------|---------------------------------------------------------|
| `workload/`    | Go microservice (`/cpu /json /mixed /memory`), cross-compilable for `amd64`/`arm64` |
| `loadgen/`     | k6 ramp-and-hold scenarios (RPS, latency percentiles)   |
| `terraform/`   | IaC: network, bench instances, telemetry, dashboard modules |
| `telemetry/`   | Prometheus scrape/recording rules + Grafana dashboards   |
| `scripts/`     | Multi-arch image build + benchmark run orchestration     |
| `analysis/`    | Energy/throughput/carbon metrics + Welch hypothesis test |
| `results/`     | (gitignored) run outputs                                  |

## 4. Feature Branches & CI/CD

Each feature is developed, committed, and pushed **per-feature on its own
branch**, keeping history reviewable and mergeable:

| Branch            | Feature                                          |
|-------------------|--------------------------------------------------|
| `feature/workload`| Go benchmark microservice + Dockerfile           |
| `feature/loadgen` | k6 load generation                               |
| `feature/terraform`| AWS IaC (SUT pairs, loadgen, dashboard)         |
| `feature/telemetry`| Prometheus + Grafana telemetry stack            |
| `feature/scripts` | build + run orchestration                        |
| `feature/analysis`| metric derivation + hypothesis testing           |
| `feature/docs`    | methodology documentation (this README)          |

## 5. Workflow

```bash
# 1. Provision infrastructure
cd terraform && terraform init -backend-config=bucket=... && terraform apply

# 2. Build & push multi-arch workload image
./scripts/build.sh "$ECR_URL"

# 3. Run a scenario against one SUT (control or test)
END_ARCH=x86_64 END_GROUP=control BASE_URL=<sut>:8080 ./scripts/run_benchmark.sh

# 4. Export energy metrics, then aggregate + test hypotheses
python3 analysis/export_energy.py --group control --arch x86_64 \
  --start ... --end ... --out results/<run>/control-x86_64/cpu
python3 analysis/hypothesis_test.py --csv results/aggregated.csv
```

> Carbon intensity used in energy→CO2e conversion defaults to a US-average
> placeholder (see `analysis/export_energy.py`); replace with the experiment's
> regional grid intensity before drawing conclusions.

## 6. Validation

- Workload passes `go vet` / `gofmt` and cross-compiles for `linux/amd64` and
  `linux/arm64`.
- Analysis scripts compile and the Welch hypothesis test runs on synthetic data.

## License

CC-BY ... (see LICENSE). Research attribution as declared above.
