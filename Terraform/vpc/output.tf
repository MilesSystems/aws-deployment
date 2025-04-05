output "vpc_id" {
  description = "VPC Id"
  value = aws_vpc.vpc.arn
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value = var.vpc_cidr_param
}

output "public_route_table_id" {
  description = "Route Table for public subnets"
  value = aws_route_table.public_route_table.id
}

output "public_aza_subnet_id" {
  description = "Availability Zone A public subnet Id"
  value = aws_subnet.public_aza_subnet.id
}

output "public_azb_subnet_id" {
  description = "Availability Zone B public subnet Id"
  value = aws_subnet.public_azb_subnet.id
}

output "public_azc_subnet_id" {
  description = "Availability Zone C public subnet Id"
  value = aws_subnet.public_azc_subnet.id
}

output "private_aza_subnet_id" {
  description = "Availability Zone A private subnet Id"
  value = aws_subnet.private_aza_subnet.id
}

output "private_azb_subnet_id" {
  description = "Availability Zone B private subnet Id"
  value = aws_subnet.private_azb_subnet.id
}

output "private_azc_subnet_id" {
  description = "Availability Zone C private subnet Id"
  value = aws_subnet.private_azc_subnet.id
}

output "private_aza_route_table_id" {
  description = "Route table for private subnets in AZ A"
  value = aws_route_table.private_aza_route_table.id
}

output "private_azb_route_table_id" {
  description = "Route table for private subnets in AZ B"
  value = aws_route_table.private_azb_route_table.id
}

output "private_azc_route_table_id" {
  description = "Route table for private subnets in AZ C"
  value = aws_route_table.private_azc_route_table.id
}

output "data_aza_subnet_id" {
  description = "Availability Zone A data subnet Id"
  value = aws_subnet.data_aza_subnet.id
}

output "data_azb_subnet_id" {
  description = "Availability Zone B data subnet Id"
  value = aws_subnet.data_azb_subnet.id
}

output "data_azc_subnet_id" {
  description = "Availability Zone C data subnet Id"
  value = aws_subnet.data_azc_subnet.id
}

output "data_route_table_id" {
  description = "Route table for data subnets in all AZs"
  value = aws_route_table.data_route_table.id
}

