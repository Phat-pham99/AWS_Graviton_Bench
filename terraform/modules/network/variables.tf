variable "ssh_cidr" {
  description = "Operator CIDR(s) allowed SSH access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "operator_cidr" {
  description = "Operator CIDR(s) allowed to reach the Grafana dashboard."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "grafana_port" {
  description = "Grafana UI port exposed on the dashboard security group."
  type        = number
  default     = 3000
}
