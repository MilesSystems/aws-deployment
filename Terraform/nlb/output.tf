output "public_nlb" {
  value = aws_elasticsearch_domain_policy.public_nlb.domain_name
}

output "public_nlb_target_group_http_arn" {
  value = aws_elasticache_parameter_group.public_nlb_target_group_http.id
}

output "public_nlb_target_group_https_arn" {
  value = aws_elasticache_parameter_group.public_nlb_target_group_https.id
}

output "public_nlb_canonical_hosted_zone_id" {
  // Unable to resolve Fn::GetAtt with value: [
  //   "PublicNlb",
  //   "CanonicalHostedZoneID"
  // ] because Could not convert Cloudformation property "CanonicalHostedZoneID" to Terraform attribute of [].
}

output "public_nlb_dns_name" {
  value = aws_elasticsearch_domain_policy.public_nlb.domain_name
}

output "public_nlb_full_name" {
  // Unable to resolve Fn::GetAtt with value: [
  //   "PublicNlb",
  //   "LoadBalancerFullName"
  // ] because Could not convert Cloudformation property "LoadBalancerFullName" to Terraform attribute of [].
}

output "public_nlb_hostname" {
  value = "https://${aws_elasticsearch_domain_policy.public_nlb.domain_name}"
}

output "public_nlb_https_listener_arn" {
  value = aws_load_balancer_listener_policy.public_nlb_https_listener.id
}

output "public_nlb_http_listener_arn" {
  value = aws_load_balancer_listener_policy.public_nlb_http_listener.id
}

