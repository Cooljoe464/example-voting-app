aws_region         = "us-east-1"
cluster_name       = "voting-app-eks"
kubernetes_version = "1.34"

# MiniStack EKS runs a real k3s server node. Its managed node groups are
# metadata-only, and it does not expose DescribeAddonVersions, so both are
# disabled for this workspace.
enable_eks_addons         = false
enable_managed_node_group = false

# ECR repositories are disposable in this local lifecycle.
ecr_force_delete = true

node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3

endpoint_public_access_cidrs = ["0.0.0.0/0"]

environment = "dev"
