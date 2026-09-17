terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_pet" "sut" {
  prefix = "sut-"
  length = 2
}

output "generated_name" {
  value = random_pet.sut.id
}
