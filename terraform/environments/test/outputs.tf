output "vpc_id" {
  value = module.vpc.vpc_id
}
output "eks_cluster_name" {
  value = module.eks.cluster_name
}
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "ecr_backend_repository_url" {
  value = module.ecr.backend_repository_url
}
output "ecr_frontend_repository_url" {
  value = module.ecr.frontend_repository_url
}
output "rds_address" {
  value = module.rds.address
}
output "rds_port" {
  value = module.rds.port
}
output "rds_db_name" {
  value = module.rds.db_name
}
