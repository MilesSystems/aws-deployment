variable "PublicAlbArn" {
  description = "This variable was an imported value in the Cloudformation Template."
}

variable vpc_id {
  description = "ID of the VPC"
  type = string
}

variable public_subnets {
  description = "List of Public subnets to use for the Load Balancer"
  type = string
}

