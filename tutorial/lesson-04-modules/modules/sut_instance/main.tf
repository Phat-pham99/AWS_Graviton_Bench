variable "group" {
  description = "Benchmark group name (control/test/loadgen)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "arch" {
  description = "CPU architecture (x86_64 / arm64)."
  type        = string
}

resource "random_pet" "this" {
  prefix    = "${var.group}-"
  length    = 2
  separator = "-"
}

locals {
  summary = "${var.group} | ${var.instance_type} | ${var.arch}"
}

output "generated_name" {
  value = random_pet.this.id
}

output "summary" {
  value = local.summary
}
