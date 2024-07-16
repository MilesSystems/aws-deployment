<?php

# @link https://github.com/aws-samples/ecs-refarch-cloudformation/blob/master/infrastructure/load-balancers.yaml

$certificateArns = $argv[1] ?? false;
$hasCert = !empty($certificateArns);


$certificateParameters = $hasCert ? <<<EOF
  CertificateArns:
    Type: List<AWS::CertificateManager::Certificate::Arn>
    Description: List of ACM certificates to be used by the load balancer listener
    Default: "$certificateArns"
EOF : <<<EOF
  CertificateArns:
    Type: CommaDelimitedList
    Description: List of ACM certificates to be used by the load balancer listener
    Default: ""
EOF;


$DefaultActions = $hasCert ? <<<EOF
        - Type: "redirect"
          RedirectConfig:
            Protocol: "HTTPS"
            Port: "443"
            Host: "#{host}"
            Path: "/#{path}"
            Query: "#{query}"
            StatusCode: "HTTP_301"
EOF : <<<EOF
        - Type: fixed-response
          FixedResponseConfig:
          StatusCode: 200
          ContentType: text/plain
          MessageBody: "No certificates provided, no target groups were matched."
EOF;

# todo - we dont need the conditions since were generating this dynamically.
# This is legacy and will be removed
print <<<EOF
AWSTemplateFormatVersion: "2010-09-09"
Description: Deploys an Application Load Balancer (ALB) with a listeners

Parameters:
  PublicSubnets:
    Type: List<AWS::EC2::Subnet::Id>
    Description: List of Private subnets to use for the application
$certificateParameters

Conditions:
  HasCertificates: !Not [ !Equals [ !Join [ "", !Ref CertificateArns ], "" ] ]
  DoesNotHaveCertificates:
    Fn::Equals: [ !Join [ "", !Ref CertificateArns ], "" ]


Resources:
  PublicAlb:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      IpAddressType: ipv4
      Name: publicAlb
      Scheme: internet-facing
      SecurityGroups:
        - !ImportValue Ec2SecurityGroup
      Subnets: !Ref PublicSubnets
      Tags:
        - Key: Name
          Value: ec2-alb
      Type: application

  PublicAlbHttpListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      DefaultActions:
$DefaultActions
      LoadBalancerArn: !Ref PublicAlb
      Port: 80
      Protocol: HTTP

  PublicAlbHttpsListenerWithCertificates:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Condition: HasCertificates
    Properties:
      Certificates:
        - CertificateArn: !Ref CertificateArns
      DefaultActions:
        - Type: fixed-response
      LoadBalancerArn: !Ref PublicAlb
      Port: 443
      Protocol: HTTPS

Outputs:
  PublicAlb:
    Value: !Ref PublicAlb
    Export:
      Name: PublicAlbArn
  PublicAlbCanonicalHostedZoneId:
    Value: !GetAtt PublicAlb.CanonicalHostedZoneID
  PublicAlbDnsName:
    Value: !GetAtt PublicAlb.DNSName
  PublicAlbFullName:
    Value: !GetAtt PublicAlb.LoadBalancerFullName
  PublicAlbHostname:
    Value: !Sub https://\${PublicAlb.DNSName}
  PublicAlbHttpsListenerArn:
    Condition: HasCertificates
    Value: !If
      - HasCertificates
      - !Ref PublicAlbHttpsListenerWithCertificates
      - !Ref "AWS::NoValue"
    Export:
      Name: PublicAlbHttpsListenerArn
  PublicAlbHttpListenerArn:
    Value: !Ref PublicAlbHttpListener
    Export:
      Name: PublicAlbHttpListenerArn


EOF;


