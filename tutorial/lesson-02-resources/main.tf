terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "pet_length" {
  type    = number
  default = 2
}

variable "prefix" {
  type    = string
  default = "sut"
}

resource "random_pet" "sut" {
  prefix    = "${var.prefix}-"
  length    = var.pet_length
  separator = "-"
}

output "generated_name" {
  value = random_pet.sut.id
}
