variable "aws_region" {
  description = "AWS region containing the default VPC."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region name, for example us-east-1."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "voting-app-eks"

  validation {
    condition     = can(regex("^[0-9A-Za-z][A-Za-z0-9_-]{0,99}$", var.cluster_name))
    error_message = "cluster_name must start with a letter or number and contain only letters, numbers, hyphens, and underscores."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.37"

  validation {
    condition     = can(regex("^1\\.(3[4-9])$", var.kubernetes_version))
    error_message = "kubernetes_version must be a supported EKS version between 1.34 and 1.39."
  }
}

variable "enable_eks_addons" {
  description = "Create EKS managed addons. Disable for emulators that do not expose DescribeAddonVersions."
  type        = bool
  default     = true
}

variable "enable_managed_node_group" {
  description = "Create the default EKS managed node group. Disable for emulators that use the k3s server node."
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]

  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "node_instance_types must contain at least one instance type."
  }
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.node_desired_size >= 1
    error_message = "node_desired_size must be at least 1."
  }
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_size >= 0
    error_message = "node_min_size cannot be negative."
  }
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3

  validation {
    condition     = var.node_max_size >= 1
    error_message = "node_max_size must be at least 1."
  }
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Set this to your administrator IP, for example 203.0.113.10/32."
  type        = list(string)

  validation {
    condition     = length(var.endpoint_public_access_cidrs) > 0
    error_message = "At least one CIDR must be supplied for the public EKS endpoint."
  }

  validation {
    condition     = alltrue([for cidr in var.endpoint_public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every endpoint_public_access_cidrs entry must be a valid CIDR block."
  }
}

variable "enable_ecr" {
  description = "Create the ECR repositories used by the voting application images."
  type        = bool
  default     = true
}

variable "ecr_force_delete" {
  description = "Delete ECR repositories even when they contain images. Useful for disposable emulator lifecycles."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
