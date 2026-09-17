output "control_name" {
  value = module.control.generated_name
}

output "test_name" {
  value = module.test.generated_name
}

output "all_names" {
  value = {
    control = module.control.generated_name
    test    = module.test.generated_name
  }
}
