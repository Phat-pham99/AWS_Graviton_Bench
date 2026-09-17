variable "group"                        { type = string }
variable "arch"                         { type = string }
variable "instance_type"                { type = string }
variable "ami"                          { type = string }
variable "subnet_id"                    { type = string }
variable "security_group_id"            { type = string }
variable "key_name"                     { type = string }
variable "telemetry_enable_kepler"      { type = bool }
variable "telemetry_enable_scaphandre"  { type = bool }
variable "telemetry_enable_exporter"    { type = bool }
variable "prometheus_scrape_interval"   { type = string }
variable "iam_instance_profile"         { type = string }
variable "tags"                         { type = map(string) }

# SUT container deployment knobs (load generator passes default/harmless values).
variable "sut_image"       { type = string; default = "" }
variable "sut_platform"    { type = string; default = "linux/amd64" }
variable "sut_gomaxprocs"  { type = number; default = 4 }
variable "sut_cpus"        { type = number; default = 4 }
variable "sut_mem"         { type = string; default = "7g" }

locals {
  is_sut = var.group == "control" || var.group == "test"
  fqdn   = "${var.group}-${var.arch}"
}

# CPU architecture mapping for the user-data bootstrap of telemetry.
# Kepler requires kernel >= 5.13 with BPF; it is installed on SUT instances.
resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name == "" ? null : var.key_name
  iam_instance_profile   = var.iam_instance_profile == "" ? null : var.iam_instance_profile

  # Dedicated instance (no burst/credit) per methodology.
  instance_initiated_shutdown_behavior = "stop"
  monitoring                           = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    fqdn                      = local.fqdn
    arch                      = var.arch
    group                     = var.group
    is_sut                    = local.is_sut
    kepler                    = var.telemetry_enable_kepler
    scaphandre                = var.telemetry_enable_scaphandre
    node_exporter             = var.telemetry_enable_exporter
    scrape_interval           = var.prometheus_scrape_interval
    sut_image                 = var.sut_image
    sut_platform              = var.sut_platform
    sut_gomaxprocs            = var.sut_gomaxprocs
    sut_cpus                  = var.sut_cpus
    sut_mem                   = var.sut_mem
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 40
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name         = local.fqdn
    Group        = var.group
    Architecture = var.arch
  })
}

output "private_ip" { value = aws_instance.this.private_ip }
output "public_ip"  { value = aws_instance.this.public_ip }
output "id"         { value = aws_instance.this.id }
