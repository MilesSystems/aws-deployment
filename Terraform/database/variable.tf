variable vpc_id {
  description = "ID of the VPC"
  type = string
}

variable vpc_cidr {
  description = "The CIDR block used for the VPC. The security group will allow connections from this CIDR range."
  type = string
  default = "10.1.0.0/16"
}

variable data_subnets {
  description = "List of data subnets to use for the Load Balancer"
  type = string
}

variable database_engine {
  description = "Choose the database engine"
  type = string
  default = "MySQL"
}

variable database_engine_version {
  description = "The version of the database engine"
  type = string
}

variable database_instance_type {
  description = "The Amazon RDS database instance class."
  type = string
  default = "db.t4g.micro"
}

variable database_master_username {
  description = "The Amazon RDS master username."
  type = string
  default = "root"
}

variable database_master_password {
  description = "The Amazon RDS master password."
  type = string
  default = "password"
}

variable database_name {
  description = "The Amazon RDS master database name. DBName must begin with a letter and contain only alphanumeric characters."
  type = string
}

variable database_cluster_parameter_group_family {
  description = "The cluster parameter group family to use for Aurora"
  type = string
  default = "mysql8.0"
}

variable instance_identifier_prefix {
  description = "Prefix for the database instance identifier"
  type = string
  default = "mydb"
}

variable port {
  description = "The database port"
  type = string
  default = 3306
}

variable monitoring_interval {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance."
  type = string
  default = 0
}

variable enable_iam_database_authentication {
  description = "Enable IAM Database Authentication"
  type = string
  default = false
}

variable multi_az {
  description = "Specifies if the database instance is a Multi-AZ deployment"
  type = string
  default = false
}

variable publicly_accessible {
  description = "Specifies the accessibility options for the database instance"
  type = string
  default = false
}

variable allocated_storage {
  description = "The amount of allocated storage for the database instance"
  type = string
  default = 20
}

variable backup_retention_period {
  description = "The number of days to retain backups"
  type = string
  default = 7
}

variable storage_type {
  description = "Specifies the storage type to be associated with the DB instance"
  type = string
  default = "gp2"
}

variable deletion_protection {
  description = "Indicates if the database should have deletion protection"
  type = string
  default = false
}

variable preferred_backup_window {
  description = "The daily time range during which automated backups are created if automated backups are enabled"
  type = string
  default = "23:25-23:55"
}

variable preferred_maintenance_window {
  description = "The weekly time range (in UTC) during which system maintenance can occur"
  type = string
  default = "Tue:03:00-Tue:06:00"
}

variable scaling_configuration_auto_pause {
  description = "Indicates whether to allow or disallow automatic pause for an Aurora DB cluster in serverless DB engine mode"
  type = string
  default = true
}

variable scaling_configuration_min_capacity {
  description = "The minimum capacity for an Aurora DB cluster in serverless DB engine mode"
  type = string
  default = 1
}

variable scaling_configuration_max_capacity {
  description = "The maximum capacity for an Aurora DB cluster in serverless DB engine mode"
  type = string
  default = 4
}

variable scaling_configuration_seconds_until_auto_pause {
  description = "The time, in seconds, before an Aurora DB cluster in serverless mode is paused"
  type = string
  default = 1800
}

variable storage_encrypted {
  description = "Specifies whether the database instance is encrypted"
  type = string
  default = true
}

variable enable_performance_insights {
  description = "Enable Performance Insights"
  type = string
  default = false
}

variable performance_insights_retention_period {
  description = "The amount of time, in days, to retain Performance Insights data"
  type = string
  default = 7
}

variable use_serverless {
  description = "Specifies whether to use serverless Aurora or a standard RDS instance"
  type = string
  default = false
}

