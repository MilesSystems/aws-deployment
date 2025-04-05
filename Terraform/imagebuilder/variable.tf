variable name {
  type = string
}

variable infrastructure_configuration_id {
  description = "ID of the Infrastructure Configuration"
  type = string
}

variable distribution_configuration_id {
  description = "ID of the Distribution Configuration"
  type = string
}

variable ec2_base_image_ami {
  description = "SSM Parameter that points to the latest AMI for ARM-based instances"
  type = string
  default = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable recipe_version {
  description = "The semantic version number you want to give to the recipe (in Major.Minor.Patch format)."
  type = string
}

variable storage {
  description = "The size of the root EBS volume in GB"
  type = string
  default = 30
}

