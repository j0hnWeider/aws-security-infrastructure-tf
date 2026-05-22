output "vpc_id" {
  description = "ID da VPC Criada"
  value       = aws_vpc.production_vpc.id
}

output "public_subnet_ids" {
  description = "IDs das Subnets Públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das Subnets Privadas"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_public_ip" {
  description = "IP Público Dinâmico do NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}
