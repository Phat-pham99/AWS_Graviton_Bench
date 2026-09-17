# AWS Graviton Benchmark — Terraform Infrastructure Report

## Overview

This Terraform configuration provisions an AWS test lab for benchmarking **AWS Graviton (ARM64)** against **Intel x86_64** performance. It creates:

1. A dedicated VPC network
2. Three EC2 instances:
   - **Control group** — `c6i.xlarge` (x86_64, Intel Ice Lake)
   - **Test group** — `c7g.xlarge` (ARM64, AWS Graviton3 / Neoverse V1)
   - **Load generator** — `c6i.2xlarge` (runs k6/wrk2)
3. A **central dashboard server** — Prometheus + Grafana for telemetry collection

All instances run in a **single Availability Zone** to eliminate AZ/placement noise, per the methodology in `PLAN.md` section 2.

---

## File Structure

```
terraform/
├── main.tf                     # Orchestrator: provider, locals, module wiring
├── variables.tf                # All configurable inputs
├── outputs.tf                  # IP outputs for post-deploy access
└── modules/
    ├── network/                # VPC, subnets, NAT, IGW, security groups
    │   ├── module.tf
    │   └── variables.tf
    ├── bench_instance/         # Generic EC2 instance + user-data bootstrap
    │   └── module.tf
    └── dashboard/              # Prometheus + Grafana host
        └── module.tf
```

---

## File-by-File Breakdown

### `main.tf` — the orchestrator

- Requires Terraform `>= 1.5` and AWS provider `~> 5.0`
- Uses an **S3 remote backend** for state storage
- Defines `locals`:
  - `namespace = "graviton-bench"`
  - `az` — auto-resolves if not specified
  - Shared tags (Project, Environment, ManagedBy, Owner)
- Instantiates 4 modules:

| Module    | Group     | Instance Type  | Architecture | Role                                |
|-----------|-----------|----------------|--------------|-------------------------------------|
| `control` | control   | `c6i.xlarge`   | x86_64       | SUT — Intel Ice Lake                |
| `test`    | test      | `c7g.xlarge`   | arm64        | SUT — Graviton3                     |
| `loadgen` | loadgen   | `c6i.2xlarge`  | x86_64       | k6/wrk2 load generator (no telemetry) |
| `dashboard` | dashboard | `t3.medium`   | x86_64       | Prometheus + Grafana                |

Both SUTs run the same workload container (`public.ecr.aws/graviton-bench/workload:latest`) with matching resource limits (4 vCPU, 7 GiB) for a fair comparison — only the CPU platform differs (`linux/amd64` vs `linux/arm64`).

Outputs: loadgen public IP, control/test private IPs, Grafana URL, Prometheus targets.

### `variables.tf` — the knobs

| Variable                      | Default / Required       | Purpose                                  |
|-------------------------------|--------------------------|------------------------------------------|
| `region`                      | `us-east-1`              | AWS region for the whole benchmark       |
| `availability_zone`           | `""` (auto)              | Pin a specific AZ                        |
| `environment`                 | `research`               | Tag label                                |
| `vpc_cidr`                    | `10.0.0.0/22`            | VPC CIDR block                           |
| `ssh_key_name`                | **required**             | Existing EC2 key pair                    |
| `iam_instance_profile`        | `""`                     | Optional IAM profile for instances       |
| `control_instance_type`       | `c6i.xlarge`             | x86_64 control (4 vCPU, 8 GiB)           |
| `test_instance_type`          | `c7g.xlarge`             | ARM64 Graviton (4 vCPU, 8 GiB)           |
| `loadgen_instance_type`       | `c6i.2xlarge`            | Dedicated non-burstable load generator   |
| `dashboard_instance_type`     | `t3.medium`              | Central dashboard host                   |
| `x86_ami` / `arm_ami`         | **required**             | Ubuntu 24.04 AMI ids (per region)        |
| `telemetry_enable_kepler`     | `true`                   | Power telemetry (Kepler, requires BPF)   |
| `telemetry_enable_scaphandre` | `true`                   | Fine-grained energy measurement          |
| `telemetry_enable_exporter`   | `true`                   | Prometheus Node Exporter                 |
| `prometheus_scrape_interval`  | `10s`                    | Scrape interval for power/energy capture |
| `grafana_admin_password`      | **required** (sensitive) | Grafana admin password                   |
| `grafana_port`                | `3000`                   | Grafana UI port                          |

### `outputs.tf`

- `private_ips` — map of control/test/loadgen private IPs
- `public_ips` — map of public IPs for SSH/UI access

---

## Modules

### `modules/network`

Builds the network layer:

- **VPC** (`10.0.0.0/22`) with DNS support/hostnames
- **Internet Gateway** + **NAT Gateway** (with EIP) for outbound access
- **Subnets**:
  - Public (`cidrsubnet(..., 1, 1)`, public IPs on launch) — hosts NAT
  - Private (`cidrsubnet(..., 1, 0)`) — hosts all bench instances
- **Route tables**: private → NAT, public → IGW
- **Security groups**:
  - `graviton-bench-bench` — workload (8080), Grafana (3000), Node Exporter (9100, private-only), Prometheus (9090, private-only)
  - `graviton-bench-ssh` — port 22 from `ssh_cidr` (default `0.0.0.0/0` — tighten before production use)
  - `graviton-bench-dashboard` — Grafana port from `operator_cidr`
- Outputs: `subnet_id`, `security_group_id`, `ssh_sg_id`, `dashboard_sg_id`

### `modules/bench_instance`

Creates a single EC2 instance, used 3× (control, test, loadgen):

- 40 GB encrypted gp3 root volume
- Detailed CloudWatch monitoring enabled
- **`user_data.sh.tftpl`** bootstrap script that, on boot:
  - For SUTs (`control`/`test`): installs Kepler, Scaphandre, and Node Exporter per toggles, configures Prometheus scraping, and deploys the workload container with pinned `GOMAXPROCS`/CPU/memory limits
  - For `loadgen`: skips telemetry
- Outputs: `private_ip`, `public_ip`, `id`

### `modules/dashboard`

Creates the monitoring EC2 instance:

- Attached to bench + dashboard + SSH security groups
- `user_data.sh.tftpl` installs Prometheus + Grafana, configuring Prometheus with the control/test/loadgen private IPs as scrape targets and setting the Grafana admin password
- 40 GB encrypted gp3 root volume
- Outputs: `public_ip`, `private_ip`, `prometheus_targets`

---

## How to Run

```bash
cd terraform

terraform init      # initialize backend + download AWS provider
terraform plan      # preview what will be created
terraform apply     # create the infrastructure
terraform destroy   # tear everything down when done
```

Required inputs: `ssh_key_name`, `x86_ami`, `arm_ami`, `grafana_admin_password`.

---

## Data Flow

```
loadgen (c6i.2xlarge)
    │  HTTP load on port 8080
    ▼
control (c6i.xlarge, x86_64)      test (c7g.xlarge, ARM64)
    │  telemetry (9100/9318/...)     │  telemetry (9100/9318/...)
    └──────────────┬─────────────────┘
                   ▼
        dashboard (Prometheus + Grafana)
                   │  scraped every 10s (power/energy/metrics)
                   ▼
        Grafana UI (http://<dashboard-public-ip>:3000)
```

---

## In One Sentence

This Terraform tells AWS: *"Create an isolated single-AZ network, launch an x86 SUT, an ARM Graviton SUT, a load generator, and a monitoring dashboard, then wire them together so I can fairly benchmark Graviton vs Intel on both performance and energy."*
