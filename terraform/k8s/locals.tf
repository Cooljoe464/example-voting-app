locals {
  subnet_ids = sort(data.aws_subnets.default.ids)

  tags = merge(
    var.tags,
    {
      Project     = "example-voting-app"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

resource "terraform_data" "preflight" {
  input = {
    vpc_id     = data.aws_vpc.default.id
    subnet_ids = local.subnet_ids
  }

  lifecycle {
    precondition {
      condition     = length(local.subnet_ids) >= 2
      error_message = "The default VPC must have at least two subnets in different Availability Zones for EKS."
    }

    precondition {
      condition     = var.node_desired_size >= var.node_min_size && var.node_desired_size <= var.node_max_size
      error_message = "node_desired_size must be between node_min_size and node_max_size."
    }
  }
}
