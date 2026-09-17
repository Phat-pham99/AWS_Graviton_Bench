terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name."
  type        = string
}

variable "x86_ami" {
  description = "Ubuntu 24.04 x86_64 AMI id."
  type        = string
}

variable "grafana_admin_password" {
  description = "Sensitive admin password."
  type        = string
  sensitive   = true
}

locals {
  resolved = {
    ssh_key  = var.ssh_key_name
    ami      = var.x86_ami
    password = var.grafana_admin_password
  }
}

resource "random_pet" "lab" {
  prefix = "lab-"
  length = 2
}

output "lab_name" {
  value = random_pet.lab.id
}

output "ssh_key" {
  value = local.resolved.ssh_key
}

output "ami" {
  value = local.resolved.ami
}

output "password" {
  value     = local.resolved.password
  sensitive = true
}
