locals {
  linkAlb = var.add_alb_listener == "true"
  linkNlb = var.add_nlb_listener == "true"
  HasCertificates = !join("", var.certificate_arns) == ""
  linkAlbWithCerts = alltrue([
  local.linkAlb,
  local.HasCertificates
])
  HasLoadBalancerHosts = !join("", var.load_balancer_hosts) == ""
  IncludeGitHubRunNumberForASG = var.use_git_hub_run_number_for_asg == "true"
  stack_id = uuidv5("dns", "web")
}

