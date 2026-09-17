variable "pet_count" {
  description = "Number of numbered pets (count)."
  type        = number
  default     = 3
}

variable "groups" {
  description = "Named groups (for_each over a map)."
  type        = map(string)
  default = {
    control = "c6i.xlarge"
    test    = "c7g.xlarge"
  }
}

variable "use_arm" {
  description = "Which architecture label to compute."
  type        = bool
  default     = true
}

variable "extra_pet_enabled" {
  description = "Toggle an optional resource."
  type        = bool
  default     = true
}
