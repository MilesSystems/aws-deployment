<?php

# Generates a CloudFormation template for a shared Application Load Balancer
# that uses a default certificate and host-based rule. Optional CLI arguments
# allow populating default values for the certificate ARN and the host list.

$defaultCertificateArn = $argv[1] ?? '';
$defaultHosts = $argv[2] ?? '';

$defaultCertificateParam = <<<EOT
  DefaultCertificateArn:
    Type: String
    Description: ARN of the default ACM certificate for the listener
EOT;

if (!empty($defaultCertificateArn)) {
    $defaultCertificateParam .= "\n    Default: $defaultCertificateArn";
}

$defaultHostsParam = <<<EOT
  DefaultLoadBalancerHosts:
    Type: List<String>
    Description: Default hostnames handled by the listener
EOT;

if (!empty($defaultHosts)) {
    $defaultHostsParam .= "\n    Default: $defaultHosts";
}

print <<<YAML
AWSTemplateFormatVersion: "2010-09-09"
Description: Application Load Balancer with default certificate and host rule.

Parameters:
  PublicSubnets:
    Type: List<AWS::EC2::Subnet::Id>
    Description: Subnets for the load balancer
  LoadBalancerSecurityGroups:
    Type: List<AWS::EC2::SecurityGroup::Id>
    Description: Security groups for the load balancer
$defaultCertificateParam
$defaultHostsParam

Resources:
  PublicAlb:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Scheme: internet-facing
      Subnets: !Ref PublicSubnets
      SecurityGroups: !Ref LoadBalancerSecurityGroups
      Type: application
      Tags:
        - Key: Name
          Value: publicAlb

  PublicAlbHttpListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      LoadBalancerArn: !Ref PublicAlb
      Port: 80
      Protocol: HTTP
      DefaultActions:
        - Type: redirect
          RedirectConfig:
            Port: '443'
            Protocol: HTTPS
            StatusCode: HTTP_301

  PublicAlbHttpsListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      LoadBalancerArn: !Ref PublicAlb
      Port: 443
      Protocol: HTTPS
      Certificates:
        - CertificateArn: !Ref DefaultCertificateArn
      DefaultActions:
        - Type: fixed-response
          FixedResponseConfig:
            StatusCode: '404'
            ContentType: text/plain
            MessageBody: Not Found

  DefaultHttpsListenerRule:
    Type: AWS::ElasticLoadBalancingV2::ListenerRule
    Properties:
      Actions:
        - Type: fixed-response
          FixedResponseConfig:
            StatusCode: '404'
            ContentType: text/plain
            MessageBody: Not Found
      Conditions:
        - Field: host-header
          HostHeaderConfig:
            Values: !Ref DefaultLoadBalancerHosts
      ListenerArn: !Ref PublicAlbHttpsListener
      Priority: 1

Outputs:
  PublicAlbArn:
    Value: !Ref PublicAlb
    Export:
      Name: PublicAlbArn
  PublicAlbDnsName:
    Value: !GetAtt PublicAlb.DNSName
    Export:
      Name: PublicAlbDnsName
  PublicAlbCanonicalHostedZoneId:
    Value: !GetAtt PublicAlb.CanonicalHostedZoneID
    Export:
      Name: PublicAlbCanonicalHostedZoneId
  PublicAlbHttpListenerArn:
    Value: !Ref PublicAlbHttpListener
    Export:
      Name: PublicAlbHttpListenerArn
  PublicAlbHttpsListenerArn:
    Value: !Ref PublicAlbHttpsListener
    Export:
      Name: PublicAlbHttpsListenerArn
YAML;

