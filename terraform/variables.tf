variable "region" {
  description = "AWS region hosting the whole benchmark (single AZ methodology)."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability Zone. Leave empty to auto-resolve one AZ in the region."
  type        = string
  default     = ""
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "research"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated research VPC."
  type        = string
  default     = "10.0.0.0/22"
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name for SSH access."
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name (optional) attached to instances."
  type        = string
  default     = ""
}

# Equivalent tiers within the same AZ per PLAN.md section 2.
variable "control_instance_type" {
  description = "x86_64 control instance (4 vCPU, 8 GiB)."
  type        = string
  default     = "c6i.xlarge"
}
variable "test_instance_type" {
  description = "ARM64 Graviton test instance (4 vCPU, 8 GiB)."
  type        = string
  default     = "c7g.xlarge"
}
variable "loadgen_instance_type" {
  description = "Dedicated load generator instance (non-burstable)."
  type        = string
  default     = "c6i.2xlarge"
}
variable "dashboard_instance_type" {
  description = "Central dashboard host."
  type        = string
  default     = "t3.medium"
}

variable "x86_ami" {
  description = "Ubuntu 24.04 LTS AMI id (x86_64). Populate per region."
  type        = string
}
variable "arm_ami" {
  description = "Ubuntu 24.04 LTS AMI id (arm64). Populate per region."
  type        = string
}

# Telemetry toggles.
variable "telemetry_enable_kepler" {
  type    = bool
  default = true
}
variable "telemetry_enable_scaphandre" {
  type    = bool
  default = true
}
variable "telemetry_enable_exporter" {
  type    = bool
  default = true
}
variable "prometheus_scrape_interval" {
  description = "Prometheus scrape interval for power/energy capture."
  type        = string
  default     = "10s"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (sensitive)."
  type        = string
  sensitive   = true
}
variable "grafana_port" {
  type    = number
  default = 3000
}
