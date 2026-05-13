# ============================================================
# VPC
# The container for all network resources. 10.0.0.0/16 gives
# 65,536 private IPs — standard for internal networks.
# ============================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "data-platform-vpc" }
}

# ============================================================
# SUBNETS
# Public  (10.0.1.0/24, us-east-1a) — NAT Gateway lives here
# Private (10.0.2.0/24, us-east-1a) — databases (primary AZ)
# Private (10.0.3.0/24, us-east-1b) — applications (second AZ
#   for redundancy: if 1a fails, 1b keeps running)
# ============================================================
resource "aws_subnet" "public_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = { Name = "public-subnet-1a" }
}

resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1a_cidr
  availability_zone = "${var.aws_region}a"

  tags = { Name = "private-subnet-1a" }
}

resource "aws_subnet" "private_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1b_cidr
  availability_zone = "${var.aws_region}b"

  tags = { Name = "private-subnet-1b" }
}

# ============================================================
# INTERNET GATEWAY
# The border checkpoint for all traffic entering/leaving the
# VPC. Must be attached to the VPC to work.
# ============================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "data-platform-igw" }
}

# ============================================================
# ELASTIC IP + NAT GATEWAY
# NAT Gateway needs a static public IP (Elastic IP).
# It MUST live in the PUBLIC subnet so it has direct access
# to the Internet Gateway. Private servers reach the internet
# through NAT; the internet cannot initiate back to them.
# Cost: ~$0.32/hour — disable with enable_nat_gateway=false.
# ============================================================
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = { Name = "data-platform-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_1a.id

  tags = { Name = "data-platform-nat" }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================
# ROUTE TABLES
# Public  route table: unknown traffic → Internet Gateway
# Private route table: unknown traffic → NAT Gateway
#   Both private subnets share one private route table.
# ============================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "public-route-table" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = { Name = "private-route-table" }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private.id
}

# ============================================================
# SECURITY GROUPS
# Principle: deny by default, allow explicitly.
#
# sg-public-nat      — HTTPS (443) from anywhere
# sg-private-compute — all traffic from itself + from public SG
#                      (EC2, Lambda, Glue run in compute subnet)
# sg-private-db      — MySQL (3306) + PostgreSQL (5432) from
#                      compute SG only; internet can never reach
# ============================================================
resource "aws_security_group" "public_nat" {
  name        = "public-nat-sg"
  description = "Security group for public subnet with NAT Gateway. Allows HTTPS inbound only."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from anywhere for secure connections"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "public-nat-sg" }
}

resource "aws_security_group" "private_compute" {
  name        = "private-compute-sg"
  description = "Security group for compute (EC2, Lambda, Glue) in private subnets. Allow internal traffic."
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "private-compute-sg" }
}

# Self-referencing rule: servers in compute subnet talk to each other.
resource "aws_vpc_security_group_ingress_rule" "compute_self" {
  security_group_id            = aws_security_group.private_compute.id
  referenced_security_group_id = aws_security_group.private_compute.id
  ip_protocol                  = "-1"
  description                  = "Allow all traffic from within this security group"
}

# Allow traffic from public subnet (e.g. load balancer → app server).
resource "aws_vpc_security_group_ingress_rule" "compute_from_public" {
  security_group_id            = aws_security_group.private_compute.id
  referenced_security_group_id = aws_security_group.public_nat.id
  ip_protocol                  = "-1"
  description                  = "Allow all traffic from public security group"
}

resource "aws_security_group" "private_db" {
  name        = "private-db-sg"
  description = "Security group for RDS databases in private subnets. Only allow from compute layer."
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "private-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_mysql" {
  security_group_id            = aws_security_group.private_db.id
  referenced_security_group_id = aws_security_group.private_compute.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "MySQL from compute subnet"
}

resource "aws_vpc_security_group_ingress_rule" "db_postgres" {
  security_group_id            = aws_security_group.private_db.id
  referenced_security_group_id = aws_security_group.private_compute.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from compute subnet"
}

# ============================================================
# VPC ENDPOINTS
# Gateway endpoints (S3, DynamoDB) are FREE — traffic stays
# inside AWS network instead of going through NAT/internet.
# Interface endpoint (Secrets Manager) is cheap and encrypts
# access without needing internet connectivity.
# ============================================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id
  ]

  tags = { Name = "data-platform-s3-endpoint" }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id
  ]

  tags = { Name = "data-platform-dynamodb-endpoint" }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1a.id, aws_subnet.private_1b.id]
  security_group_ids  = [aws_security_group.private_compute.id]
  private_dns_enabled = true

  tags = { Name = "data-platform-secretsmanager-endpoint" }
}
