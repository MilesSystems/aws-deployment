variable "${var.network_stack_name}-private-az-a-subnet" {
  description = "This variable was an imported value in the Cloudformation Template."
}

variable network_stack_name {
  description = "The CloudFormation Stack Name for the Network/VPC"
  type = string
  default = "network-stack"
}

variable environment {
  description = "The environment (e.g., NonProd, Prod)"
  type = string
}

variable account_id {
  description = "The AWS Account ID for the environment"
  type = string
}

