variable vpc_cidr_param {
  description = "VPC CIDR. For more info, see http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html#VPC_Sizing"
  type = string
}

variable public_aza_subnet_block {
  description = "Subnet CIDR for first Availability Zone"
  type = string
}

variable public_azb_subnet_block {
  description = "Subnet CIDR for second Availability Zone"
  type = string
}

variable public_azc_subnet_block {
  description = "Subnet CIDR for third Availability Zone"
  type = string
}

variable private_aza_subnet_block {
  description = "Subnet CIDR for first Availability Zone (e.g. us-west-2a, us-east-1b)"
  type = string
}

variable private_azb_subnet_block {
  description = "Subnet CIDR for second Availability Zone (e.g. us-west-2b, us-east-1c)"
  type = string
}

variable private_azc_subnet_block {
  description = "Subnet CIDR for third Availability Zone, (e.g. us-west-2c, us-east-1d)"
  type = string
}

variable data_aza_subnet_block {
  description = "Subnet CIDR for first Availability Zone (e.g. us-west-2a, us-east-1b)"
  type = string
}

variable data_azb_subnet_block {
  description = "Subnet CIDR for second Availability Zone (e.g. us-west-2b, us-east-1c)"
  type = string
}

variable data_azc_subnet_block {
  description = "Subnet CIDR for third Availability Zone, (e.g. us-west-2c, us-east-1d)"
  type = string
}

variable highly_available_nat {
  description = "Optional configuration for a highly available NAT Gateway setup. Default configuration is a single NAT Gateway in Subnet A. The highly available option will configure a NAT Gateway in each of the Subnets."
  type = string
  default = false
}

variable enable_vpc_flow_logs {
  description = "Optional configuration for enabling VPC Flow Logs sent to CloudWatch Logs. Default configuration has no VPC Flow Logs enabled."
  type = string
  default = "false"
}

