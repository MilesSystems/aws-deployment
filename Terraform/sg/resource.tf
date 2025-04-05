resource "aws_security_group" "ec2_security_group" {
  description = "Allows access to HTTP, HTTPS, and RTMP"
  ingress = [
    {
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP"
      from_port = 80
      to_port = 80
      protocol = "tcp"
    },
    {
      ipv6_cidr_blocks = "::/0"
      description = "HTTP"
      from_port = 80
      to_port = 80
      protocol = "tcp"
    },
    {
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS"
      from_port = 443
      to_port = 443
      protocol = "tcp"
    },
    {
      ipv6_cidr_blocks = "::/0"
      description = "HTTPS"
      from_port = 443
      to_port = 443
      protocol = "tcp"
    },
    {
      cidr_blocks = "0.0.0.0/0"
      description = "rtmp"
      from_port = 1935
      to_port = 1935
      protocol = "-1"
    },
    {
      ipv6_cidr_blocks = "::/0"
      description = "rtmp"
      from_port = 1935
      to_port = 1935
      protocol = "-1"
    }
  ]
  egress = [
    {
      cidr_blocks = "0.0.0.0/0"
      protocol = "-1"
    },
    {
      ipv6_cidr_blocks = "::/0"
      protocol = "-1"
    }
  ]
  vpc_id = var.vpc_id
}

