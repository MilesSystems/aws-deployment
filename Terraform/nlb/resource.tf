resource "aws_elasticsearch_domain_policy" "public_nlb" {
  // CF Property(IpAddressType) = "ipv4"
  domain_name = "publicNlb"
  // CF Property(Scheme) = "internet-facing"
  // CF Property(Subnets) = var.public_subnets
  // CF Property(Type) = "network"
  // CF Property(tags) = {
  //   Name = "nlb"
  // }
}

resource "aws_elasticache_parameter_group" "public_nlb_target_group_http" {
  // CF Property(Port) = 80
  // CF Property(Protocol) = "TCP"
  // CF Property(Targets) = [
  //   {
  //     Id = var.PublicAlbArn
  //   }
  // ]
  // CF Property(TargetType) = "alb"
  // CF Property(VpcId) = var.vpc_id
}

resource "aws_elasticache_parameter_group" "public_nlb_target_group_https" {
  // CF Property(Port) = 443
  // CF Property(Protocol) = "TCP"
  // CF Property(Targets) = [
  //   {
  //     Id = var.PublicAlbArn
  //   }
  // ]
  // CF Property(TargetType) = "alb"
  // CF Property(VpcId) = var.vpc_id
}

resource "aws_load_balancer_listener_policy" "public_nlb_http_listener" {
  // CF Property(DefaultActions) = [
  //   {
  //     Type = "forward"
  //     TargetGroupArn = aws_elasticache_parameter_group.public_nlb_target_group_http.id
  //   }
  // ]
  load_balancer_name = aws_elasticsearch_domain_policy.public_nlb.domain_name
  load_balancer_port = 80
  // CF Property(Protocol) = "TCP"
}

resource "aws_load_balancer_listener_policy" "public_nlb_https_listener" {
  // CF Property(DefaultActions) = [
  //   {
  //     Type = "forward"
  //     TargetGroupArn = aws_elasticache_parameter_group.public_nlb_target_group_https.id
  //   }
  // ]
  load_balancer_name = aws_elasticsearch_domain_policy.public_nlb.domain_name
  load_balancer_port = 443
  // CF Property(Protocol) = "TCP"
}

