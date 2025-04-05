locals {
  HighlyAvailable = var.highly_available_nat == "true"
  NotHighlyAvailable = var.highly_available_nat == "false"
  VpcFlowLogs = var.enable_vpc_flow_logs == "true"
  stack_name = "vpc"
}

