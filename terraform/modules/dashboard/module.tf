variable "namespace"              { type = string }
variable "ami"                     { type = string }
variable "instance_type"           { type = string }
variable "subnet_id"               { type = string }
variable "security_group_id"       { type = string }
variable "ssh_sg_id"               { type = string }
variable "dashboard_sg_id"         { type = string }
variable "key_name"                { type = string }
variable "grafana_admin_password"  { type = string; sensitive = true }
variable "grafana_port"            { type = number; default = 3000 }
variable "targets_control"         { type = string }
variable "targets_test"            { type = string }
variable "targets_loadgen"         { type = string }
variable "iam_instance_profile"    { type = string }
variable "tags"                    { type = map(string) }

locals {
  all_targets = join(",", [var.targets_control, var.targets_test, var.targets_loadgen])
}

resource "aws_instance" "dashboard" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id, var.dashboard_sg_id, var.ssh_sg_id]
  key_name               = var.key_name == "" ? null : var.key_name
  iam_instance_profile   = var.iam_instance_profile == "" ? null : var.iam_instance_profile

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    grafana_password  = var.grafana_admin_password
    grafana_port      = tostring(var.grafana_port)
    targets_control   = var.targets_control
    targets_test      = var.targets_test
    targets_loadgen   = var.targets_loadgen
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 40
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${var.namespace}-dashboard", Role = "dashboard" })
}

output "public_ip"          { value = aws_instance.dashboard.public_ip }
output "private_ip"         { value = aws_instance.dashboard.private_ip }
output "prometheus_targets" { value = local.all_targets }
