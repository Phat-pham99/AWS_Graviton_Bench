variable "namespace" { type = string }
variable "region"    { type = string }
variable "vpc_cidr"  { type = string }
variable "az"        { type = string }
variable "tags"      { type = map(string) }

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags, { Name = "${var.namespace}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, { Name = "${var.namespace}-igw" })
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 1, 0)
  availability_zone       = var.az
  map_public_ip_on_launch = false
  tags = merge(var.tags, { Name = "${var.namespace}-private" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 1, 1)
  availability_zone       = var.az
  map_public_ip_on_launch = true
  tags = merge(var.tags, { Name = "${var.namespace}-public" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, { Name = "${var.namespace}-rt-private" })
}

resource "aws_route" "private_nat" {
  route_table_id = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.this.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, { Name = "${var.namespace}-rt-public" })
}

resource "aws_route" "public_igw" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# EIP for NAT (single-AZ setup keeps it cheap and deterministic).
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = merge(var.tags, { Name = "${var.namespace}-eip-nat" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = merge(var.tags, { Name = "${var.namespace}-nat" })
}

# Security groups.
resource "aws_security_group" "bench" {
  name        = "${var.namespace}-bench"
  description = "Bench instances: allow dashboards, telemetry, and internal SUT traffic."
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, { Name = "${var.namespace}-sg-bench" })

  ingress {
    from_port = 8080 # workload microservice
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block, aws_subnet.public.cidr_block]
  }
  ingress {
    from_port = 3000 # grafana
    to_port   = 3000
    protocol  = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block, aws_subnet.public.cidr_block]
  }
  ingress {
    from_port = 9100 # node exporter
    to_port   = 9100
    protocol  = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }
  ingress {
    from_port = 9090 # prometheus
    to_port   = 9090
    protocol  = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh" {
  name        = "${var.namespace}-ssh"
  description = "SSH from operator CIDR."
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, { Name = "${var.namespace}-sg-ssh" })

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = var.ssh_cidr
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dashboard" {
  name        = "${var.namespace}-dashboard"
  description = "Allow operator access to Grafana UI."
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, { Name = "${var.namespace}-sg-dashboard" })

  ingress {
    from_port = var.grafana_port
    to_port   = var.grafana_port
    protocol  = "tcp"
    cidr_blocks = var.operator_cidr
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "subnet_id"         { value = aws_subnet.private.id }
output "security_group_id" { value = aws_security_group.bench.id }
output "ssh_sg_id"         { value = aws_security_group.ssh.id }
output "dashboard_sg_id"   { value = aws_security_group.dashboard.id }
