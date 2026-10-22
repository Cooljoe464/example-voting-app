mock_provider "aws" {
  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-0123456789abcdef0"
    }
  }

  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-0aaa1111", "subnet-0bbb2222", "subnet-0ccc3333"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/terraform-test"
      user_id    = "AIDAEXAMPLE"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name        = "us-east-1"
      id          = "us-east-1"
      description = "US East (N. Virginia)"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      arn        = "arn:aws:iam::123456789012:user/terraform-test"
      issuer_arn = "arn:aws:iam::123456789012:user/terraform-test"
    }
  }

  mock_data "aws_eks_addon_version" {
    defaults = {
      version  = "v1.0.0-eksbuild.1"
      versions = ["v1.0.0-eksbuild.1"]
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::123456789012:role/mock-role"
      name      = "mock-role"
      unique_id = "AROAEXAMPLE"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      name     = "voting-app-eks"
      version  = "1.37"
      endpoint = "https://example.eks.amazonaws.com"
      status   = "ACTIVE"

      certificate_authority = [
        {
          data = "ZmFrZS1jYQ=="
        }
      ]
    }
  }

  mock_resource "aws_ecr_repository" {
    defaults = {
      arn            = "arn:aws:ecr:us-east-1:123456789012:repository/voting-app/vote"
      repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/voting-app/vote"
    }
  }
}

mock_provider "tls" {}
mock_provider "time" {}
mock_provider "cloudinit" {}
mock_provider "null" {}

run "default_vpc_eks_cluster" {
  command = apply

  variables {
    endpoint_public_access_cidrs = ["203.0.113.10/32"]
  }

  # These data sources drive the preflight checks and must be known at plan
  # time, so provide deterministic values instead of relying on mock defaults.
  override_data {
    target = data.aws_vpc.default
    values = {
      id = "vpc-0123456789abcdef0"
    }
  }

  override_data {
    target = data.aws_subnets.default
    values = {
      ids = ["subnet-0aaa1111", "subnet-0bbb2222", "subnet-0ccc3333"]
    }
  }

  # The EKS module's managed-node-group submodule derives resource counts from
  # data sources, which mock providers cannot resolve during plan. Override the
  # submodule outputs so the rest of the cluster configuration is still tested.
  override_module {
    target = module.eks.module.eks_managed_node_group["default"]
    outputs = {
      launch_template_id             = "lt-0123456789abcdef0"
      launch_template_arn            = "arn:aws:ec2:us-east-1:123456789012:launch-template/lt-0123456789abcdef0"
      launch_template_latest_version = 1
      launch_template_name           = "voting-app-eks-default"

      node_group_arn                     = "arn:aws:eks:us-east-1:123456789012:nodegroup/voting-app-eks/default/abc123"
      node_group_id                      = "voting-app-eks:default"
      node_group_resources               = []
      node_group_autoscaling_group_names = ["voting-app-eks-default"]
      node_group_status                  = "ACTIVE"
      node_group_labels                  = {}
      node_group_taints                  = []

      iam_role_name      = "voting-app-eks-default"
      iam_role_arn       = "arn:aws:iam::123456789012:role/voting-app-eks-default"
      iam_role_unique_id = "AROAEXAMPLE"

      security_group_arn = "arn:aws:ec2:us-east-1:123456789012:security-group/sg-0123456789abcdef0"
      security_group_id  = "sg-0123456789abcdef0"
    }
  }

  assert {
    condition     = data.aws_vpc.default.id == "vpc-0123456789abcdef0"
    error_message = "The cluster must use the account's default VPC."
  }

  assert {
    condition     = length(local.subnet_ids) == 3
    error_message = "All default VPC subnets should be selected."
  }

  assert {
    condition     = module.eks.cluster_name == "voting-app-eks"
    error_message = "Unexpected EKS cluster name."
  }

  assert {
    condition     = module.eks.cluster_version == "1.37"
    error_message = "Unexpected EKS Kubernetes version."
  }

  assert {
    condition     = module.eks.cluster_endpoint == "https://example.eks.amazonaws.com"
    error_message = "Unexpected EKS endpoint."
  }

  assert {
    condition     = length(module.eks.cluster_addons) == 4
    error_message = "Expected vpc-cni, kube-proxy, coredns, and eks-pod-identity-agent addons."
  }

  assert {
    condition     = module.eks.eks_managed_node_groups["default"].node_group_arn != null
    error_message = "The default managed node group must be created."
  }

  assert {
    condition     = length(aws_ecr_repository.images) == 5
    error_message = "Expected ECR repositories for vote, result, worker, redis, and db."
  }
}

run "ministack_mode" {
  command = apply

  variables {
    kubernetes_version           = "1.34"
    enable_eks_addons            = false
    enable_managed_node_group    = false
    ecr_force_delete             = true
    endpoint_public_access_cidrs = ["0.0.0.0/0"]
  }

  override_data {
    target = data.aws_vpc.default
    values = {
      id = "vpc-0123456789abcdef0"
    }
  }

  override_data {
    target = data.aws_subnets.default
    values = {
      ids = ["subnet-0aaa1111", "subnet-0bbb2222", "subnet-0ccc3333"]
    }
  }

  assert {
    condition     = try(length(module.eks.cluster_addons), 0) == 0
    error_message = "MiniStack mode must not create EKS addons."
  }

  assert {
    condition     = try(length(module.eks.eks_managed_node_groups), 0) == 0
    error_message = "MiniStack mode must not create managed node groups."
  }

  assert {
    condition     = aws_ecr_repository.images["vote"].force_delete == true
    error_message = "MiniStack ECR repositories must be force-deletable."
  }
}
