variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (65,536 IPs)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet (NAT Gateway lives here)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_1a_cidr" {
  description = "CIDR for private subnet in us-east-1a (databases)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1b_cidr" {
  description = "CIDR for private subnet in us-east-1b (applications, redundancy AZ)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway ($0.32/hr). Set false to save cost when not actively using private subnet egress."
  type        = bool
  default     = true
}
