resource "aws_ecr_repository" "backend" {
  name = var.backend_repository
  image_tag_mutability = var.image_tag_mutability
  image_scanning_configuration {
  scan_on_push = true
}
  encryption_configuration {
  encryption_type = "AES256"
}
  tags = merge(var.tags, {
  Name = var.backend_repository
})
}
resource "aws_ecr_repository" "frontend" {
  name = var.frontend_repository
  image_tag_mutability = var.image_tag_mutability
  image_scanning_configuration {
  scan_on_push = true
}
  encryption_configuration {
  encryption_type = "AES256"
}
  tags = merge(var.tags, {
  Name = var.frontend_repository
})
}
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({ rules = [{ rulePriority = 1, description = "Expire old tagged images", selection = {
  tagStatus = "tagged", tagPrefixList = ["v", "release"], countType = "imageCountMoreThan", countNumber = var.keep_image_count
}, action = {
  type = "expire"
}
}]
})
}
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy = aws_ecr_lifecycle_policy.backend.policy
}
