terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

module "control" {
  source        = "./modules/sut_instance"
  group         = "control"
  instance_type = "c6i.xlarge"
  arch          = "x86_64"
}

module "test" {
  source        = "./modules/sut_instance"
  group         = "test"
  instance_type = "c7g.xlarge"
  arch          = "arm64"
}
