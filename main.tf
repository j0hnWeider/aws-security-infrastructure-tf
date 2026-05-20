terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- NETWORK LAYER ARCHITECTURE ---

resource "aws_vpc" "production_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "prod-secure-vpc"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.production_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true 

  tags = {
    Name        = "prod-subnet-public-1a"
    Tier        = "Public/DMZ"
    Environment = "production"
  }
}

# Hardening: Isolated network layer for sensitive workloads (No IGW Route)
resource "aws_subnet" "private_subnet_1a" {
  vpc_id                  = aws_vpc.production_vpc.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false 

  tags = {
    Name        = "prod-subnet-private-1a"
    Tier        = "Private/Application"
    Environment = "production"
  }
}

# --- PERIMETER ROUTING ---

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.production_vpc.id

  tags = {
    Name        = "prod-igw"
    Environment = "production"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.production_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name        = "prod-public-route-table"
    Environment = "production"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rt.id
}

# Final architectural security layer applied.

# --- SECURITY PERIMETER HARDENING ---

resource "aws_security_group" "internal_app_sg" {
  name        = "prod-internal-app-sg"
  description = "Strict firewall rules for private subnet workloads"
  vpc_id      = aws_vpc.production_vpc.id

  # Ingress: Allow traffic only on HTTPS port from internal network
  ingress {
    description = "Allow HTTPS internal traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.production_vpc.cidr_block]
  }

  # Egress: Restrict outbound traffic to secure web traffic only
  egress {
    description = "Allow secure outbound updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "prod-app-firewall"
    Environment = "production"
  }
}
