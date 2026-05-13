output "vpc_id" {
  description = "data-platform-vpc ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "data-platform-vpc CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_id" {
  description = "public-subnet-1a ID"
  value       = module.vpc.public_subnet_id
}

output "private_subnet_1a_id" {
  description = "private-subnet-1a ID"
  value       = module.vpc.private_subnet_1a_id
}

output "private_subnet_1b_id" {
  description = "private-subnet-1b ID"
  value       = module.vpc.private_subnet_1b_id
}

output "internet_gateway_id" {
  description = "data-platform-igw ID"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_id" {
  description = "data-platform-nat ID (null when enable_nat_gateway=false)"
  value       = module.vpc.nat_gateway_id
}

output "sg_public_nat_id" {
  description = "sg-public-nat security group ID"
  value       = module.vpc.sg_public_nat_id
}

output "sg_private_compute_id" {
  description = "sg-private-compute security group ID"
  value       = module.vpc.sg_private_compute_id
}

output "sg_private_db_id" {
  description = "sg-private-db security group ID"
  value       = module.vpc.sg_private_db_id
}
