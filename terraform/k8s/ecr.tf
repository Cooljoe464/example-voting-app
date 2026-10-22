locals {
  ecr_repository_names = toset(["vote", "result", "worker", "redis", "db"])
}

resource "aws_ecr_repository" "images" {
  for_each = var.enable_ecr ? local.ecr_repository_names : toset([])

  name                 = "voting-app/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.ecr_force_delete

  tags = merge(local.tags, {
    Name = "voting-app/${each.key}"
  })
}
