resource "aws_security_group" "rds_security_group" {
  description = "Allows access to RDS via the selected database port"
  ingress = [
    {
      cidr_blocks = var.vpc_cidr
      description = "Database Port"
      from_port = var.port
      to_port = var.port
      protocol = "tcp"
    }
  ]
  egress = [
    {
      cidr_blocks = "0.0.0.0/0"
      protocol = "-1"
    },
    {
      ipv6_cidr_blocks = "::/0"
      protocol = "-1"
    }
  ]
  vpc_id = var.vpc_id
}

resource "aws_db_subnet_group" "data_subnet_group" {
  description = "RDS Database Subnet Group for WordPress"
  subnet_ids = var.data_subnets
  tags = {
    Name = "WordPress-DB-SubnetGroup"
  }
}

resource "aws_db_instance" "rds_db_instance" {
  count = local.IsNotAurora ? 1 : 0
  identifier = "${var.instance_identifier_prefix}-instance"
  allocated_storage = var.allocated_storage
  instance_class = var.database_instance_type
  engine = var.database_engine
  username = var.database_master_username
  manage_master_user_password = var.database_master_password
  db_name = var.database_name
  vpc_security_group_ids = [
    aws_security_group.rds_security_group.arn
  ]
  db_subnet_group_name = aws_db_subnet_group.data_subnet_group.id
  multi_az = var.multi_az
  publicly_accessible = var.publicly_accessible
  backup_retention_period = var.backup_retention_period
  backup_window = var.preferred_backup_window
  maintenance_window = var.preferred_maintenance_window
  storage_type = var.storage_type
  deletion_protection = var.deletion_protection
  storage_encrypted = var.storage_encrypted
  monitoring_interval = var.monitoring_interval
  iam_database_authentication_enabled = var.enable_iam_database_authentication
  engine_version = local.HasEngineVersion ? var.database_engine_version : null
  performance_insights_enabled = var.enable_performance_insights
  performance_insights_retention_period = local.EnablePerformanceInsightsCondition ? var.performance_insights_retention_period : null
}

resource "aws_rds_cluster" "rds_serverless_db_cluster" {
  count = local.IsAurora ? 1 : 0
  backup_retention_period = var.backup_retention_period
  cluster_identifier = "${var.instance_identifier_prefix}-cluster"
  db_cluster_parameter_group_name = var.database_cluster_parameter_group_family
  db_subnet_group_name = aws_db_subnet_group.data_subnet_group.id
  deletion_protection = var.deletion_protection
  engine = var.database_engine
  engine_mode = "serverless"
  engine_version = local.HasEngineVersion ? var.database_engine_version : null
  master_username = var.database_master_username
  manage_master_user_password = var.database_master_password
  port = var.port
  preferred_backup_window = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  scaling_configuration = {
    AutoPause = var.scaling_configuration_auto_pause
    MinCapacity = var.scaling_configuration_min_capacity
    MaxCapacity = var.scaling_configuration_max_capacity
    SecondsUntilAutoPause = var.scaling_configuration_seconds_until_auto_pause
  }
  storage_encrypted = var.storage_encrypted
  vpc_security_group_ids = [
    aws_security_group.rds_security_group.arn
  ]
  performance_insights_enabled = local.EnablePerformanceInsightsCondition ? var.enable_performance_insights : null
  performance_insights_retention_period = local.EnablePerformanceInsightsCondition ? var.performance_insights_retention_period : null
}

