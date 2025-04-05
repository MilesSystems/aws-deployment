variable environment {
  description = "The name of the Environment"
  type = string
}

variable repository_nicename {
  description = "The name of the Repository cleaned up for use in the stack"
  type = string
}

variable git_hub_run_number {
  description = "The unique GitHub run number"
  type = string
}

variable branch {
  description = "The branch of the repository to deploy"
  type = string
}

variable version {
  description = "The version of the application to deploy"
  type = string
}

variable run_number {
  description = "The GitHub Actions run number"
  type = string
}

variable vpc_id {
  description = "ID of the VPC"
  type = string
}

variable recipe_version {
  description = "The semantic version number you want to give to the recipe (in Major.Minor.Patch format)."
  type = string
}

variable private_subnets {
  description = "List of Private subnets to use for the application"
  type = string
}

variable amazon_linux_ami {
  type = string
}

variable update_policy_pause_time {
  description = "The pause time for the Auto Scaling rolling update in ISO 8601 duration format (e.g., PT30M for 30 minutes)."
  type = string
  default = "PT10M"
}

variable creation_policy_timeout {
  description = "The timeout for the ResourceSignal in ISO 8601 duration format (e.g., PT10M for 10 minutes)."
  type = string
  default = "PT10M"
}

variable min_size {
  description = "The minimum limit of allowed instances to be deployed."
  type = string
  default = 1
}

variable max_size {
  description = "The maximum limit of allowed instances to be deployed."
  type = string
  default = 8
}

variable desired_capacity {
  description = "The average amount of instances to be deployed."
  type = string
  default = 1
}

variable on_demand_base_capacity {
  description = "The minimum amount of the Auto Scaling group's capacity that must be fulfilled by On-Demand Instances. For prod you should always have at least 1 On-Demand instance (set to 1)."
  type = string
  default = 1
}

variable on_demand_percentage_above_base_capacity {
  description = "Controls the percentages of On-Demand Instances and Spot Instances for your additional capacity beyond OnDemandBaseCapacity. Expressed as a number (for example, 20 specifies 20% On-Demand Instances, 80% Spot Instances). Defaults to 0 if not specified. If set to 100, only On-Demand Instances are provisioned."
  type = string
  default = 0
}

variable port_udp {
  description = "The UDP port number for the environment."
  type = string
  default = 4444
}

variable instance_type {
  description = "The EC2 instance type for the environment."
  type = string
}

variable max_cpu {
  description = "The maximum CPU utilization percentage for auto-scaling."
  type = string
}

variable heartbeat_timeout {
  description = "The heartbeat timeout for the load balancer."
  type = string
}

variable load_balancer_rule_priority {
  description = "The priority of the load balancer rule."
  type = string
}

variable load_balancer_hosts {
  description = "The list of hosts for the load balancer."
  type = string
}

variable add_alb_listener {
  description = "Add an HTTPS listener to the ALB"
  type = string
  default = "false"
}

variable add_nlb_listener {
  description = "Add a UDP listener to the NLB"
  type = string
  default = "false"
}

variable certificate_arns {
  description = "List of ACM certificates to be used by the load balancer listener"
  type = string
}

variable use_git_hub_run_number_for_asg {
  description = "A flag to include GitHubRunNumber in the AutoScalingGroup Name tag"
  type = string
  default = "true"
}

