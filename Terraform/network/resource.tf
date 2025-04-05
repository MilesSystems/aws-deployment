resource "aws_ram_resource_share" "vpc_share" {
  allow_external_principals = [
    var.account_id
  ]
  name = "${var.environment} Network Share"
  // CF Property(ResourceArns) = [
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-private-az-a-subnet}",
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-private-az-b-subnet}",
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-private-az-c-subnet}",
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-public-az-a-subnet}",
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-public-az-b-subnet}",
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-public-az-c-subnet}",
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-data-az-a-subnet}",
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-data-az-b-subnet}",
  //   "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:subnet/${var.${var.network_stack_name}-data-az-c-subnet}"
  // ]
}

