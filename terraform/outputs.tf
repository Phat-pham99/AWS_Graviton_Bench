output "private_ips" {
  description = "Private IPs of all bench instances keyed by group."
  value = {
    control = module.control.private_ip
    test    = module.test.private_ip
    loadgen = module.loadgen.private_ip
  }
}
output "public_ips" {
  description = "Public IPs where SSH/UI access is needed."
  value = {
    control  = module.control.public_ip
    test     = module.test.public_ip
    loadgen  = module.loadgen.public_ip
    dashboard = module.dashboard.public_ip
  }
}
