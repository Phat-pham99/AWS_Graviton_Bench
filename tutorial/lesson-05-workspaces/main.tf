terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

locals {
  group_name = terraform.workspace == "default" ? "unset" : terraform.workspace
}

resource "random_pet" "sut" {
  prefix = "${local.group_name}-"
  length = 2
}

output "group_name" {
  value = local.group_name
}

output "generated_name" {
  value = random_pet.sut.id
}
