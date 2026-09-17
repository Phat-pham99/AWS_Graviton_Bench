terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_pet" "many" {
  count  = var.pet_count
  prefix = "pet-${count.index}-"
}

resource "random_pet" "groups" {
  for_each = var.groups
  prefix   = "${each.key}-"
}

resource "random_pet" "only_if_enabled" {
  count  = var.extra_pet_enabled ? 1 : 0
  prefix = "extra-"
}

locals {
  arch_label = var.use_arm ? "arm64" : "x86_64"
}

output "numbered_names" {
  value = [for i in range(var.pet_count) : random_pet.many[i].id]
}

output "group_names" {
  value = { for k, v in random_pet.groups : k => v.id }
}

output "arch_label" {
  value = local.arch_label
}

output "extra_pet" {
  value = var.extra_pet_enabled ? random_pet.only_if_enabled[0].id : "(disabled)"
}
