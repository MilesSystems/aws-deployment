output "database_endpoint" {
  description = "The endpoint address of the RDS instance"
  value = local.IsAurora ? // Unable to resolve Fn::GetAtt with value: [
//   "RdsServerlessDbCluster",
//   "Endpoint.Address"
// ] because Unable to solve nested GetAttr Endpoint for rds_serverless_db_cluster and aws_rds_cluster : aws_db_instance.rds_db_instance.address
}

output "database_port" {
  description = "The port number on which the database accepts connections"
  value = var.port
}

output "security_group_id" {
  description = "The security group ID for the database"
  value = aws_security_group.rds_security_group.arn
}

