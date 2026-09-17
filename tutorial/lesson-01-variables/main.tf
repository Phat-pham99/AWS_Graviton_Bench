locals {
  namespace     = "graviton-bench"
  instance_type = "c7g.xlarge"
  arch          = "arm64"
  full_name     = "${local.namespace}-${var.environment}-${var.group_name}"
}

output "service_name" {
  description = "Fully qualified label for the group."
  value       = local.full_name
}

output "architecture" {
  value = local.arch
}

output "instance_type" {
  value = local.instance_type
}

output "math_demo" {
  value = "5*4 = ${5 * 4}"
}
