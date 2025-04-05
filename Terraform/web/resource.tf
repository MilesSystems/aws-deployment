resource "aws_elasticache_parameter_group" "alb_target_group" {
  count = local.linkAlb ? 1 : 0
  name = "${var.environment}-${var.repository_nicename}-alb"
  // CF Property(HealthCheckEnabled) = true
  // CF Property(HealthCheckIntervalSeconds) = 10
  // CF Property(HealthCheckPath) = "/aws.json"
  // CF Property(HealthCheckPort) = "80"
  // CF Property(HealthCheckProtocol) = "HTTP"
  // CF Property(HealthCheckTimeoutSeconds) = 5
  // CF Property(HealthyThresholdCount) = 4
  // CF Property(UnhealthyThresholdCount) = 2
  // CF Property(Port) = 80
  // CF Property(Protocol) = "HTTP"
  // CF Property(ProtocolVersion) = "HTTP1"
  // CF Property(TargetGroupAttributes) = [
  //   {
  //     Key = "stickiness.enabled"
  //     Value = "false"
  //   },
  //   {
  //     Key = "stickiness.type"
  //     Value = "lb_cookie"
  //   }
  // ]
  // CF Property(TargetType) = "instance"
  // CF Property(VpcId) = var.vpc_id
  tags = {
    Name = "${var.environment}-${var.repository_nicename}-alb"
  }
}

resource "aws_load_balancer_listener_policy" "alb_http_listener_rule" {
  count = local.linkAlb ? 1 : 0
  // CF Property(Actions) = [
  //   {
  //     Type = "forward"
  //     TargetGroupArn = aws_elasticache_parameter_group.alb_target_group[0].id
  //   }
  // ]
  // CF Property(Conditions) = [
  //   {
  //     Field = "path-pattern"
  //     PathPatternConfig = {
  //       Values = [
  //         "/*"
  //       ]
  //     }
  //   }
  // ]
  // CF Property(ListenerArn) = var.PublicAlbHttpListenerArn
  // CF Property(Priority) = var.load_balancer_rule_priority
}

resource "aws_load_balancer_listener_policy" "alb_https_listener_rule" {
  count = local.linkAlbWithCerts ? 1 : 0
  // CF Property(Actions) = [
  //   {
  //     Type = "forward"
  //     TargetGroupArn = aws_elasticache_parameter_group.alb_target_group[0].id
  //   }
  // ]
  // CF Property(Conditions) = [
  //   {
  //     Field = "host-header"
  //     HostHeaderConfig = {
  //       Values = local.HasLoadBalancerHosts ? var.load_balancer_hosts : [
  //   "*"
  // ]
  //     }
  //   }
  // ]
  // CF Property(ListenerArn) = var.PublicAlbHttpsListenerArn
  // CF Property(Priority) = var.load_balancer_rule_priority
}

resource "aws_elasticache_parameter_group" "nlb_target_group" {
  count = local.linkNlb ? 1 : 0
  name = "${var.environment}-${var.repository_nicename}-nlb"
  // CF Property(HealthCheckEnabled) = true
  // CF Property(HealthCheckIntervalSeconds) = 30
  // CF Property(HealthCheckPort) = "4444"
  // CF Property(HealthCheckProtocol) = "HTTP"
  // CF Property(Port) = var.port_udp
  // CF Property(Protocol) = "TCP_UDP"
  // CF Property(TargetGroupAttributes) = [
  //   {
  //     Key = "stickiness.enabled"
  //     Value = "true"
  //   }
  // ]
  // CF Property(TargetType) = "instance"
  // CF Property(VpcId) = var.vpc_id
  tags = {
    Name = "${var.environment}-${var.repository_nicename}-nlb"
  }
}

resource "aws_load_balancer_listener_policy" "nlb_listener" {
  count = local.linkNlb ? 1 : 0
  // CF Property(DefaultActions) = [
  //   {
  //     Type = "forward"
  //     TargetGroupArn = aws_elasticache_parameter_group.nlb_target_group[0].id
  //   }
  // ]
  load_balancer_name = var.PublicNlbLoadBalancerArn
  load_balancer_port = var.port_udp
  // CF Property(Protocol) = "TCP_UDP"
}

resource "aws_launch_template" "launch_template" {
  name = "${var.environment}-${var.repository_nicename}-launch-template"
  user_data = {
    ImageId = var.amazon_linux_ami
    EbsOptimized = "true"
    IamInstanceProfile = {
      Name = "EC2RoleForSSM"
    }
    SecurityGroupIds = [
      var.Ec2SecurityGroup
    ]
    UserData = base64encode("")
  }
}

resource "aws_autoscaling_group" "auto_scaling_group" {
  health_check_type = "EC2"
  health_check_grace_period = 1800
  name = local.IncludeGitHubRunNumberForASG ? "${var.environment}-${var.repository_nicename}-${var.version}.${var.git_hub_run_number}-asg-${var.branch}-deployed" : "${var.environment}-${var.repository_nicename}-asg-${var.branch}-deployed"
  initial_lifecycle_hook = [
    {
      LifecycleTransition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      LifecycleHookName = "ready-hook"
      DefaultResult = "ABANDON"
      HeartbeatTimeout = var.heartbeat_timeout
    }
  ]
  target_group_arns = [
    local.linkAlb ? aws_elasticache_parameter_group.alb_target_group[0].id : null,
    local.linkNlb ? aws_elasticache_parameter_group.nlb_target_group[0].id : null
  ]
  min_size = var.min_size
  max_size = var.max_size
  // CF Property(MetricsCollection) = [
  //   {
  //     Granularity = "1Minute"
  //   }
  // ]
  desired_capacity = var.desired_capacity
  vpc_zone_identifier = var.private_subnets
  mixed_instances_policy = {
    LaunchTemplate = {
      LaunchTemplateSpecification = {
        Version = aws_launch_template.launch_template.latest_version
        LaunchTemplateId = aws_launch_template.launch_template.arn
      }
      Overrides = [
        {
          InstanceType = var.instance_type
        }
      ]
    }
    InstancesDistribution = {
      OnDemandBaseCapacity = var.on_demand_base_capacity
      OnDemandPercentageAboveBaseCapacity = var.on_demand_percentage_above_base_capacity
      SpotAllocationStrategy = "lowest-price"
      OnDemandAllocationStrategy = "lowest-price"
    }
  }
  tag {
    // CF Property(Name) = "${var.environment}-${var.repository_nicename}-${var.recipe_version}.${var.git_hub_run_number}-asg-${var.branch}-deployed"
    // CF Property(Version) = "${var.recipe_version}"
    // CF Property(GitHubRunNumber) = "${var.git_hub_run_number}"
  }
}

resource "aws_autoscalingplans_scaling_plan" "auto_scaling_plan_cpu" {
  application_source = {
    CloudFormationStackARN = local.stack_id
  }
  scaling_instruction = [
    {
      MinCapacity = var.min_size
      MaxCapacity = var.max_size
      ServiceNamespace = "autoscaling"
      ScalableDimension = "autoscaling:autoScalingGroup:DesiredCapacity"
      ResourceId = join("/", ["autoScalingGroup", aws_autoscaling_group.auto_scaling_group.id])
      TargetTrackingConfigurations = [
        {
          PredefinedScalingMetricSpecification = {
            PredefinedScalingMetricType = "ASGAverageCPUUtilization"
          }
          TargetValue = var.max_cpu
          EstimatedInstanceWarmup = 1200
        }
      ]
    }
  ]
}

