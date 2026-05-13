output "vpc_id" {
  description = "ID of data-platform-vpc"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of data-platform-vpc"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "ID of public-subnet-1a (10.0.1.0/24, us-east-1a)"
  value       = aws_subnet.public_1a.id
}

output "private_subnet_1a_id" {
  description = "ID of private-subnet-1a (10.0.2.0/24, us-east-1a) — databases"
  value       = aws_subnet.private_1a.id
}

output "private_subnet_1b_id" {
  description = "ID of private-subnet-1b (10.0.3.0/24, us-east-1b) — applications"
  value       = aws_subnet.private_1b.id
}

output "internet_gateway_id" {
  description = "ID of data-platform-igw"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of data-platform-nat (null when enable_nat_gateway=false)"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "sg_public_nat_id" {
  description = "ID of sg-public-nat"
  value       = aws_security_group.public_nat.id
}

output "sg_private_compute_id" {
  description = "ID of sg-private-compute"
  value       = aws_security_group.private_compute.id
}

output "sg_private_db_id" {
  description = "ID of sg-private-db"
  value       = aws_security_group.private_db.id
}
