variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway ($0.32/hr). Set false to save cost when private subnet egress is not needed."
  type        = bool
  default     = true
}
