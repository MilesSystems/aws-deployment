resource "aws_iam_role" "ec2_role_for_ssm" {
  name = "EC2RoleForSSM"
  force_detach_policies = [
    {
      PolicyName = "CompleteLifecycleActionAllowPolicy"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = "autoscaling:CompleteLifecycleAction"
            Resource = "*"
          }
        ]
      }
    },
    {
      PolicyName = "DescribeInstancesPolicy"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "ec2:DescribeInstances",
              "autoscaling:DescribeAutoScalingInstances"
            ]
            Resource = "*"
          }
        ]
      }
    },
    {
      PolicyName = "CloudFormationDescribeStackResourcesPolicy"
      PolicyDocument = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "cloudformation:DescribeStackResources"
            ]
            Resource = "*"
          }
        ]
      }
    }
  ]
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  }
  path = "/"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_instance_profile" "ec2_instance_profile_for_ssm" {
  name = "EC2RoleForSSM"
  path = "/"
  role = [
    aws_iam_role.ec2_role_for_ssm.arn
  ]
}

resource "aws_iam_role" "ec2_role_for_image_builder" {
  name = "EC2RoleForImageBuilder"
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com"
          ]
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  }
  path = "/"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  ]
}

resource "aws_iam_instance_profile" "ec2_instance_profile_for_image_builder" {
  name = "EC2RoleForImageBuilder"
  path = "/"
  role = [
    aws_iam_role.ec2_role_for_image_builder.arn
  ]
}

