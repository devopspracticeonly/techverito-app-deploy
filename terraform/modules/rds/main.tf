locals {
  client_cidrs = length(var.allowed_client_cidrs) > 0 ? var.allowed_client_cidrs : [var.vpc_cidr]
}
resource "aws_db_subnet_group" "this" {
  name = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags = var.tags
}
resource "aws_security_group" "this" {
  name = "${var.name}-rds-sg"
  description = "PostgreSQL client access"
  vpc_id = var.vpc_id
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = local.client_cidrs
 
}
  egress {
  from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"]
}
  tags = var.tags
}
resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"
  engine = "postgres"
  engine_version = var.engine_version
  instance_class = var.db_instance_class
  allocated_storage = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type = "gp3"
  storage_encrypted = true
  db_name = var.db_name
  username = var.db_username
  password = var.db_password
  port = 5432
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible = false
  multi_az = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot = true
  tags = var.tags
}
