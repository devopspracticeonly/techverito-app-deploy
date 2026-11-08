module "vpc" {
  source             = "../../modules/vpc"
  name               = var.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  nat_gateway_count  = var.nat_gateway_count
  tags               = var.tags
}
module "ecr" {
  source              = "../../modules/ecr"
  backend_repository  = "employee-backend"
  frontend_repository = "employee-frontend"
  tags                = var.tags
}
module "eks" {
  source                      = "../../modules/eks"
  name                        = var.name
  kubernetes_version          = var.kubernetes_version
  private_subnet_ids          = module.vpc.private_subnet_ids
  public_subnet_ids           = module.vpc.public_subnet_ids
  endpoint_public_access      = var.eks_endpoint_public_access
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  node_instance_types         = var.node_instance_types
  node_desired_size           = var.node_desired_size
  node_min_size               = var.node_min_size
  node_max_size               = var.node_max_size
  tags                        = var.tags
}
module "rds" {
  source               = "../../modules/rds"
  name                 = var.name
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = module.vpc.vpc_cidr
  private_subnet_ids   = module.vpc.private_subnet_ids
  allowed_client_cidrs = var.rds_allowed_client_cidrs
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  multi_az             = var.db_multi_az
  deletion_protection  = var.db_deletion_protection
  skip_final_snapshot  = var.db_skip_final_snapshot
  tags                 = var.tags
}
