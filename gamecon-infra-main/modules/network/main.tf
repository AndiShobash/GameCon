# Fetches all available AZs in the current AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values to make AZ selection predictable
locals {
  subnet_azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
}

# Guard rail to ensure enough AZs are available. Only creates this resource if available AZs < required AZs
resource "null_resource" "az_guardrail" {
  count = length(data.aws_availability_zones.available.names) < var.availability_zone_count ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'Need at least ${var.availability_zone_count} AZs in this region' && exit 1"
  }
}

# Creates the main Virtual Private Cloud with your specified CIDR (default: 10.0.0.0/16)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "andi-vpc-${terraform.workspace}"
  }
}

# Route table for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "andi-igw-${terraform.workspace}"
  }
}

# Route table for public subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "andi-public-rt-${terraform.workspace}"
  }
}

# Creates public subnets using for_each across selected AZs
# Uses cidrsubnet() to automatically calculate non-overlapping CIDR blocks
resource "aws_subnet" "public" {
  for_each = toset(local.subnet_azs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(
    var.vpc_cidr, 
    var.subnet_newbits, 
    index(local.subnet_azs, each.value)
  )
  availability_zone = each.value
  
  map_public_ip_on_launch = true
  
  tags = {
    Name = "andi-public-subnet-${index(local.subnet_azs, each.value) + 1}-${terraform.workspace}"
    Type = "Public"
    # Required for Karpenter discovery
    "karpenter.sh/discovery" = "andi-eks-cluster"
    # Required for Load Balancer Controller
    "kubernetes.io/role/elb" = "1"
  }
}

# Associates each public subnet with the public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public
  
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway Elastic IPs
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "andi-nat-eip-${terraform.workspace}"
  }
  
  depends_on = [aws_internet_gateway.igw]
}

# Single NAT Gateway (in first public subnet)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  
  tags = {
    Name = "andi-nat-gateway-${terraform.workspace}"
  }
  
  depends_on = [aws_internet_gateway.igw]
}

# Private Subnets
resource "aws_subnet" "private" {
  for_each = toset(local.subnet_azs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(
    var.vpc_cidr, 
    var.subnet_newbits, 
    index(local.subnet_azs, each.value) + length(local.subnet_azs)  # Offset to avoid overlap
  )
  availability_zone = each.value
  
  map_public_ip_on_launch = false
  
  tags = {
    Name = "andi-private-subnet-${index(local.subnet_azs, each.value) + 1}-${terraform.workspace}"
    Type = "Private"
    # Required for Karpenter discovery
    "karpenter.sh/discovery" = "andi-eks-cluster"
    # EKS tags for load balancer discovery
    "kubernetes.io/role/internal-elb" = "1"
    # Required for EKS
    "kubernetes.io/cluster/andi-eks-cluster" = "owned"
  }
}

# Private Route Tables (all point to single NAT Gateway)
resource "aws_route_table" "private" {
  for_each = toset(local.subnet_azs)
  
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id  # Single NAT Gateway
  }

  tags = {
    Name = "andi-private-rt-${index(local.subnet_azs, each.value) + 1}-${terraform.workspace}"
  }
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private
  
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}