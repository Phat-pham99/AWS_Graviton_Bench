variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "research"
}

variable "group_name" {
  description = "Short name for this benchmark group (no default -> prompt!)."
  type        = string
}
