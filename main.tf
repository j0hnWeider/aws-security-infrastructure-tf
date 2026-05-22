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
  region = var.aws_region
}

# Coleta dinamicamente as AZs disponíveis na região selecionada (ex: us-east-1a, us-east-1b...)
data "aws_availability_zones" "available" {
  state = "available"
}

# --- NETWORK LAYER ARCHITECTURE ---

resource "aws_vpc" "production_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "prod-secure-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# --- SUBNETS (Criação dinâmica usando as variáveis e AZs do Data Source) ---

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.production_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "prod-subnet-public-${data.aws_availability_zones.available.names[count.index]}"
    Tier        = "Public/DMZ"
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.production_vpc.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "prod-subnet-private-${data.aws_availability_zones.available.names[count.index]}"
    Tier        = "Private/Application"
    Environment = var.environment
  }
}

# --- PERIMETER ROUTING (INTERNET GATEWAY) ---

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.production_vpc.id

  tags = {
    Name        = "prod-igw"
    Environment = var.environment
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
    Environment = var.environment
  }
}

# Associa todas as subnets públicas criadas à tabela de rotas pública
resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# --- NAT GATEWAY (Para a saída segura da internet a partir da rede privada) ---

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name        = "prod-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id # O NAT sempre fica em uma subnet pública

  tags = {
    Name        = "prod-nat-gw"
    Environment = var.environment
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.production_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "prod-private-route-table"
    Environment = var.environment
  }
}

# Associa todas as subnets privadas à tabela de rotas com saída pelo NAT Gateway
resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# --- SECURITY PERIMETER HARDENING ---

resource "aws_security_group" "internal_app_sg" {
  name        = "prod-internal-app-sg"
  description = "Strict firewall rules for private subnet workloads"
  vpc_id      = aws_vpc.production_vpc.id

  tags = {
    Name        = "prod-app-firewall"
    Environment = var.environment
  }
}

# Regras isoladas usando recursos modernos (Padrão de Produção recomendado pela HashiCorp)

resource "aws_vpc_security_group_ingress_rule" "allow_https_internal" {
  security_group_id = aws_security_group.internal_app_sg.id
  description       = "Allow HTTPS internal traffic from VPC"
  cidr_ipv4         = aws_vpc.production_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_https_outbound" {
  security_group_id = aws_security_group.internal_app_sg.id
  description       = "Allow secure outbound updates via HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_dns_outbound_udp" {
  security_group_id = aws_security_group.internal_app_sg.id
  description       = "Allow DNS queries over UDP (Essential for updates)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  ip_protocol       = "udp"
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "allow_dns_outbound_tcp" {
  security_group_id = aws_security_group.internal_app_sg.id
  description       = "Allow DNS queries over TCP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  ip_protocol       = "tcp"
  to_port           = 53
}
