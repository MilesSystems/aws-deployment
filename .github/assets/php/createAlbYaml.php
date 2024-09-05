<?php

# @link https://github.com/aws-samples/ecs-refarch-cloudformation/blob/master/infrastructure/load-balancers.yaml
# @link https://repost.aws/knowledge-center/elastic-beanstalk-ssl-load-balancer

$certificateArns = $argv[2] ?? '';
$certificates = explode(',', $certificateArns);
$hasCert = !empty($certificates);

$DefaultHttpAction = $hasCert ? <<<EOF
        - Type: "redirect"
          RedirectConfig:
            Protocol: "HTTPS"
            Port: "443"
            Host: "#{host}"
            Path: "/#{path}"
            Query: "#{query}"
            StatusCode: "HTTP_301"
EOF: <<<EOF
        - Type: fixed-response
          FixedResponseConfig:
            StatusCode: 200
            ContentType: text/plain
            MessageBody: "No certificates provided, no target groups were matched."
EOF;

$PublicAlbHttpsListenerReturn = $hasCert ? 'PublicAlbHttpsListener' : 'AWS::NoValue';

$defaultCertificate = $hasCert ? array_shift($certificates) : '';

$httpsListener = $hasCert ? <<<EOF

  PublicAlbHttpsListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      Certificates:
        - CertificateArn: $defaultCertificate
      DefaultActions:
        - Type: fixed-response
          FixedResponseConfig:
            StatusCode: "404"
            MessageBody: !Sub "Our AWS application load balancer did not resolve this request. Please contact a server administrator."
      LoadBalancerArn: !Ref PublicAlb
      Port: 443
      Protocol: HTTPS


EOF : '';

foreach ($certificates as $key =>$certificate) {
    $httpsListener .= <<<EOF

      Certificate$key:
        Type: AWS::ElasticLoadBalancingV2::ListenerCertificate
        Properties:
          Certificates:
            - CertificateArn: "$certificate"
          ListenerArn: !Ref PublicAlbHttpsListener


    EOF;
}

print <<<EOF
AWSTemplateFormatVersion: "2010-09-09"
Description: Deploys an Application Load Balancer (ALB) with a listeners

Parameters:
  PublicSubnets:
    Type: List<AWS::EC2::Subnet::Id>
    Description: List of Private subnets to use for the application

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
$DefaultHttpAction
      LoadBalancerArn: !Ref PublicAlb
      Port: 80
      Protocol: HTTP

$httpsListener

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
    Value: !Ref $PublicAlbHttpsListenerReturn
    Export:
      Name: PublicAlbHttpsListenerArn
  PublicAlbHttpListenerArn:
    Value: !Ref PublicAlbHttpListener
    Export:
      Name: PublicAlbHttpListenerArn


EOF;


