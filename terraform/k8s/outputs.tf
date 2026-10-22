output "aws_region" {
  description = "AWS region used by this deployment."
  value       = var.aws_region
}

output "vpc_id" {
  description = "Default VPC used by the cluster."
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Default VPC subnets used by the cluster and node group."
  value       = local.subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "EKS Kubernetes version."
  value       = module.eks.cluster_version
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "node_group_arn" {
  description = "ARN of the managed node group, or null when node groups are disabled."
  value       = try(module.eks.eks_managed_node_groups["default"].node_group_arn, null)
}

output "ecr_registry" {
  description = "ECR registry host used by the application images."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by application component."
  value       = { for name, repo in aws_ecr_repository.images : name => repo.repository_url }
}

output "update_kubeconfig_command" {
  description = "Command that updates the local kubeconfig for this cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
