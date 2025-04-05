resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr_param
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "${local.stack_name}"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  tags = {
    Name = "${local.stack_name}"
  }
}

resource "aws_vpn_gateway_attachment" "vpc_gateway_attachment" {
  vpc_id = aws_vpc.vpc.arn
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.arn
  tags = {
    Name = "${local.stack_name}-public"
    Type = "public"
  }
}

resource "aws_route" "public_subnets_route" {
  route_table_id = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id
}

resource "aws_subnet" "public_aza_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.public_aza_subnet_block
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.stack_name}-public-1"
    Type = "public"
  }
}

resource "aws_route_table_association" "public_aza_subnet_route_table_association" {
  subnet_id = aws_subnet.public_aza_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_subnet" "public_azb_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.public_azb_subnet_block
  availability_zone = element(// Unable to resolve Fn::GetAZs with value: "" because cannot access local variable 'az_data' where it is not associated with a value, 1)
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.stack_name}-public-2"
    Type = "public"
  }
}

resource "aws_route_table_association" "public_azb_subnet_route_table_association" {
  subnet_id = aws_subnet.public_azb_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_subnet" "public_azc_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.public_azc_subnet_block
  availability_zone = element(// Unable to resolve Fn::GetAZs with value: "" because cannot access local variable 'az_data' where it is not associated with a value, 2)
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.stack_name}-public-3"
    Type = "public"
  }
}

resource "aws_route_table_association" "public_azc_subnet_route_table_association" {
  subnet_id = aws_subnet.public_azc_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_ec2_fleet" "aza_nat_gateway_eip" {
  // CF Property(Domain) = "vpc"
}

resource "aws_nat_gateway" "aza_nat_gateway" {
  allocation_id = aws_ec2_fleet.aza_nat_gateway_eip.id
  subnet_id = aws_subnet.public_aza_subnet.id
}

resource "aws_ec2_fleet" "azb_nat_gateway_eip" {
  count = local.HighlyAvailable ? 1 : 0
  // CF Property(Domain) = "vpc"
}

resource "aws_nat_gateway" "azb_nat_gateway" {
  count = local.HighlyAvailable ? 1 : 0
  allocation_id = aws_ec2_fleet.azb_nat_gateway_eip.id
  subnet_id = aws_subnet.public_azb_subnet.id
}

resource "aws_ec2_fleet" "azc_nat_gateway_eip" {
  count = local.HighlyAvailable ? 1 : 0
  // CF Property(Domain) = "vpc"
}

resource "aws_nat_gateway" "azc_nat_gateway" {
  count = local.HighlyAvailable ? 1 : 0
  allocation_id = aws_ec2_fleet.azc_nat_gateway_eip.id
  subnet_id = aws_subnet.public_azc_subnet.id
}

resource "aws_subnet" "private_aza_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.private_aza_subnet_block
  availability_zone = element(// Unable to resolve Fn::GetAZs with value: "" because cannot access local variable 'az_data' where it is not associated with a value, 0)
  tags = {
    Name = "${local.stack_name}-private-1"
    Type = "private"
  }
}

resource "aws_route_table" "private_aza_route_table" {
  vpc_id = aws_vpc.vpc.arn
  tags = {
    Name = "${local.stack_name}-private-rtb-1"
    Type = "private"
  }
}

resource "aws_route" "private_aza_route" {
  route_table_id = aws_route_table.private_aza_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.aza_nat_gateway.association_id
}

resource "aws_route_table_association" "private_aza_route_table_association" {
  subnet_id = aws_subnet.private_aza_subnet.id
  route_table_id = aws_route_table.private_aza_route_table.id
}

resource "aws_subnet" "private_azb_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.private_azb_subnet_block
  availability_zone = element(// Unable to resolve Fn::GetAZs with value: "" because cannot access local variable 'az_data' where it is not associated with a value, 1)
  tags = {
    Name = "${local.stack_name}-private-2"
    Type = "private"
  }
}

resource "aws_route_table" "private_azb_route_table" {
  vpc_id = aws_vpc.vpc.arn
  tags = {
    Name = "${local.stack_name}-private-rtb-2"
    Type = "private"
  }
}

resource "aws_route" "private_azb_route" {
  count = local.HighlyAvailable ? 1 : 0
  route_table_id = aws_route_table.private_azb_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.azb_nat_gateway[0].association_id
}

resource "aws_route_table_association" "private_azb_route_table_association" {
  count = local.HighlyAvailable ? 1 : 0
  subnet_id = aws_subnet.private_azb_subnet.id
  route_table_id = aws_route_table.private_azb_route_table.id
}

resource "aws_route" "not_highly_available_private_azb_route" {
  count = local.NotHighlyAvailable ? 1 : 0
  route_table_id = aws_route_table.private_azb_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.aza_nat_gateway.association_id
}

resource "aws_route_table_association" "not_highly_available_private_azb_route_table_association" {
  count = local.NotHighlyAvailable ? 1 : 0
  subnet_id = aws_subnet.private_azb_subnet.id
  route_table_id = aws_route_table.private_azb_route_table.id
}

resource "aws_subnet" "private_azc_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.private_azc_subnet_block
  availability_zone = element(// Unable to resolve Fn::GetAZs with value: "" because cannot access local variable 'az_data' where it is not associated with a value, 2)
  tags = {
    Name = "${local.stack_name}-private-3"
    Type = "private"
  }
}

resource "aws_route_table" "private_azc_route_table" {
  vpc_id = aws_vpc.vpc.arn
  tags = {
    Name = "${local.stack_name}-private-rtb-3"
    Type = "private"
  }
}

resource "aws_route" "private_azc_route" {
  count = local.HighlyAvailable ? 1 : 0
  route_table_id = aws_route_table.private_azc_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.azc_nat_gateway[0].association_id
}

resource "aws_route_table_association" "private_azc_route_table_association" {
  count = local.HighlyAvailable ? 1 : 0
  subnet_id = aws_subnet.private_azc_subnet.id
  route_table_id = aws_route_table.private_azc_route_table.id
}

resource "aws_route" "not_highly_available_private_azc_route" {
  count = local.NotHighlyAvailable ? 1 : 0
  route_table_id = aws_route_table.private_azc_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.aza_nat_gateway.association_id
}

resource "aws_route_table_association" "not_highly_available_private_azc_route_table_association" {
  count = local.NotHighlyAvailable ? 1 : 0
  subnet_id = aws_subnet.private_azc_subnet.id
  route_table_id = aws_route_table.private_azc_route_table.id
}

resource "aws_subnet" "data_aza_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.data_aza_subnet_block
  availability_zone = element(// Unable to resolve Fn::GetAZs with value: "" because cannot access local variable 'az_data' where it is not associated with a value, 0)
  tags = {
    Name = "${local.stack_name}-data-1"
    Type = "data"
  }
}

resource "aws_route_table_association" "data_aza_route_table_association" {
  subnet_id = aws_subnet.data_aza_subnet.id
  route_table_id = aws_route_table.data_route_table.id
}

resource "aws_subnet" "data_azb_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.data_azb_subnet_block
  availability_zone = element(// Unable to resolve Fn::GetAZs with value: "" because cannot access local variable 'az_data' where it is not associated with a value, 1)
  tags = {
    Name = "${local.stack_name}-data-2"
    Type = "data"
  }
}

resource "aws_route_table_association" "data_azb_route_table_association" {
  count = local.HighlyAvailable ? 1 : 0
  subnet_id = aws_subnet.data_azb_subnet.id
  route_table_id = aws_route_table.data_route_table.id
}

resource "aws_subnet" "data_azc_subnet" {
  vpc_id = aws_vpc.vpc.arn
  cidr_block = var.data_azc_subnet_block
  availability_zone = element(// Unable to resolve Fn::GetAZs with value: "" because cannot access local variable 'az_data' where it is not associated with a value, 2)
  tags = {
    Name = "${local.stack_name}-data-3"
    Type = "data"
  }
}

resource "aws_route_table_association" "data_azc_route_table_association" {
  subnet_id = aws_subnet.data_azc_subnet.id
  route_table_id = aws_route_table.data_route_table.id
}

resource "aws_route_table" "data_route_table" {
  vpc_id = aws_vpc.vpc.arn
  tags = {
    Name = "${local.stack_name}-data"
    Type = "data"
  }
}

resource "aws_vpc_endpoint" "s3_vpc_endpoint" {
  route_table_ids = [
    aws_route_table.public_route_table.id,
    aws_route_table.private_aza_route_table.id,
    aws_route_table.private_azb_route_table.id,
    aws_route_table.private_azc_route_table.id
  ]
  service_name = join("", ["com.amazonaws.", data.aws_region.current.name, ".s3"])
  vpc_id = aws_vpc.vpc.arn
  vpc_endpoint_type = "Gateway"
}

resource "aws_vpc_endpoint" "dynamo_dbvpc_endpoint" {
  route_table_ids = [
    aws_route_table.public_route_table.id,
    aws_route_table.private_aza_route_table.id,
    aws_route_table.private_azb_route_table.id,
    aws_route_table.private_azc_route_table.id
  ]
  service_name = join("", ["com.amazonaws.", data.aws_region.current.name, ".dynamodb"])
  vpc_id = aws_vpc.vpc.arn
  vpc_endpoint_type = "Gateway"
}

resource "aws_cloudwatch_log_group" "flow_log_log_group" {
  count = local.VpcFlowLogs ? 1 : 0
  name = "FlowLogs/${local.stack_name}"
  retention_in_days = 7
}

resource "aws_iam_role" "flow_logs_role" {
  count = local.VpcFlowLogs ? 1 : 0
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "vpc-flow-logs.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  }
  force_detach_policies = [
    {
      PolicyName = "AllowPublishingFlowLogsToCloudWatch"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents",
              "logs:DescribeLogGroups",
              "logs:DescribeLogStreams"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
}

resource "aws_flow_log" "vpc_flow_logs" {
  count = local.VpcFlowLogs ? 1 : 0
  iam_role_arn = aws_iam_role.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.flow_log_log_group.arn
  log_destination_type = "VPC"
  eni_id = aws_vpc.vpc.arn
  traffic_type = "ALL"
}

