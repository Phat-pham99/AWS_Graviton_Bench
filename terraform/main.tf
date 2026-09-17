# --------------------------------------------------------------------------
# AWS Graviton vs x86_64 Empirical Benchmark -- Terraform IaC
#
# Provisions the hardware topology defined in PLAN.md section 2:
#   - LOAD GENERATOR : dedicated c6i.2xlarge running k6/wrk2
#   - CONTROL GROUP  : c6i.xlarge (x86_64, Intel Ice Lake)
#   - TEST GROUP     : c7g.xlarge (ARM64, Graviton3/Neoverse V1)
#   - TELEMETRY      : Kepler + Prometheus Node Exporter + Scaphandre on each SUT
#   - DASHBOARD      : Prometheus Server + Grafana (central)
#
# Author & Principal Researcher: Pham Hong Phat.
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

locals {
  namespace = "graviton-bench"
  # All groups run in the SAME Availability Zone to eliminate AZ/placement noise
  # as required by the methodology (PLAN.md section 2).
  az = var.availability_zone == "" ? var.region : var.availability_zone
  tags = {
    Project     = "AWS_Graviton_Bench"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "phamhongphat"
  }
}

module "network" {
  source  = "./modules/network"
  namespace = local.namespace
  region    = var.region
  vpc_cidr  = var.vpc_cidr
  az        = local.az
  tags      = local.tags
}


# ---- Control Group: x86_64 (c6i.xlarge) ------------------------------------
module "control" {
  source            = "./modules/bench_instance"
  group             = "control"
  arch              = "x86_64"
  instance_type     = var.control_instance_type # c6i.xlarge
  ami               = var.x86_ami
  
  subnet_id         = module.network.subnet_id
  security_group_id = module.network.security_group_id
  key_name          = var.ssh_key_name

  telemetry_enable_kepler    = var.telemetry_enable_kepler
  telemetry_enable_scaphandre = var.telemetry_enable_scaphandre
  telemetry_enable_exporter  = var.telemetry_enable_exporter
  prometheus_scrape_interval = var.prometheus_scrape_interval
  sut_image                  = "public.ecr.aws/graviton-bench/workload:latest"
  sut_platform               = "linux/amd64"
  sut_gomaxprocs             = 4
  sut_cpus                   = 4
  sut_mem                    = "7g"

  iam_instance_profile       = var.iam_instance_profile
  tags                       = local.tags
}

# ---- Test Group: ARM64 Graviton (c7g.xlarge) --------------------------------
module "test" {
  source            = "./modules/bench_instance"
  group             = "test"
  arch              = "arm64"
  instance_type     = var.test_instance_type # c7g.xlarge
  ami               = var.arm_ami

  subnet_id         = module.network.subnet_id
  security_group_id = module.network.security_group_id
  key_name          = var.ssh_key_name

  telemetry_enable_kepler    = var.telemetry_enable_kepler
  telemetry_enable_scaphandre = var.telemetry_enable_scaphandre
  telemetry_enable_exporter  = var.telemetry_enable_exporter
  prometheus_scrape_interval = var.prometheus_scrape_interval
  sut_image                  = "public.ecr.aws/graviton-bench/workload:latest"
  sut_platform               = "linux/arm64"
  sut_gomaxprocs             = 4
  sut_cpus                   = 4
  sut_mem                    = "7g"

  iam_instance_profile       = var.iam_instance_profile
  tags                       = local.tags
}

# ---- Load Generator: x86_64 (c6i.2xlarge) -----------------------------------
module "loadgen" {
  source            = "./modules/bench_instance"
  group             = "loadgen"
  arch              = "x86_64"
  instance_type     = var.loadgen_instance_type # c6i.2xlarge
  ami               = var.x86_ami

  subnet_id         = module.network.subnet_id
  security_group_id = module.network.security_group_id
  key_name          = var.ssh_key_name

  # Load generator does not host SUT telemetry exporters directly.
  telemetry_enable_kepler     = false
  telemetry_enable_scaphandre = false
  telemetry_enable_exporter   = false
  prometheus_scrape_interval  = var.prometheus_scrape_interval
  iam_instance_profile        = var.iam_instance_profile
  tags                        = local.tags
}

# ---- Central Dashboard: Prometheus + Grafana --------------------------------
module "dashboard" {
  source                   = "./modules/dashboard"
  namespace                = local.namespace
  ami                       = var.x86_ami
  instance_type            = var.dashboard_instance_type
  subnet_id                = module.network.subnet_id
  security_group_id        = module.network.security_group_id
  ssh_sg_id                = module.network.ssh_sg_id
  dashboard_sg_id          = module.network.dashboard_sg_id
  key_name                 = var.ssh_key_name
  grafana_admin_password   = var.grafana_admin_password
  grafana_port             = var.grafana_port
  targets_control          = module.control.private_ip
  targets_test             = module.test.private_ip
  targets_loadgen          = module.loadgen.private_ip
  iam_instance_profile     = var.iam_instance_profile
  tags                     = local.tags
}

# ---- Outputs -----------------------------------------------------------------
output "load_generator_ip" {
  description = "Public IP of the k6/wrk2 load generator instance."
  value       = module.loadgen.public_ip
}
output "control_ip" {
  description = "Private IP of the x86_64 control SUT."
  value       = module.control.private_ip
}
output "test_ip" {
  description = "Private IP of the ARM64 Graviton test SUT."
  value       = module.test.private_ip
}
output "grafana_url" {
  description = "Grafana dashboard URL."
  value       = "http://${module.dashboard.public_ip}:${var.grafana_port}"
}
output "prometheus_endpoint" {
  description = "Prometheus scrape target list rendered for inspection."
  value       = module.dashboard.prometheus_targets
}
