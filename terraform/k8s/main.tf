module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.13"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = data.aws_vpc.default.id
  subnet_ids               = local.subnet_ids
  control_plane_subnet_ids = local.subnet_ids

  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = false

  # Use the AWS-managed EKS encryption key and avoid a customer KMS key that
  # would linger in a pending-deletion state after destroy.
  encryption_config = null

  # No control-plane log group: keeps the lifecycle fast and clean.
  enabled_log_types           = []
  create_cloudwatch_log_group = false

  addons = var.enable_eks_addons ? {
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
  } : null

  eks_managed_node_groups = var.enable_managed_node_group ? {
    default = {
      name                           = "default"
      ami_type                       = "AL2023_x86_64_STANDARD"
      use_latest_ami_release_version = false
      instance_types                 = var.node_instance_types
      capacity_type                  = "ON_DEMAND"
      disk_size                      = 20

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      tags = local.tags
    }
  } : null

  tags         = local.tags
  cluster_tags = local.tags
}
