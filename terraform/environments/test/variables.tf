variable "aws_region" {
  type = string
  default = "ap-south-1"
}
variable "name" {
  type = string
  default = "employee-management-test"
}
variable "tags" {
  type = map(string)
  default = {
  Project = "employee-management"
    Environment = "test"
    ManagedBy = "Terraform"
}
}
variable "vpc_cidr" {
  type = string
  default = "10.30.0.0/16"
}
variable "availability_zones" {
  type = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}
variable "public_subnets" {
  type = list(string)
  default = ["10.30.1.0/24", "10.30.2.0/24"]
}
variable "private_subnets" {
  type = list(string)
  default = ["10.30.11.0/24", "10.30.12.0/24"]
}
variable "nat_gateway_count" {
  type = number
  default = 1
}
variable "kubernetes_version" {
  type = string
  default = "1.31"
}
variable "eks_endpoint_public_access" {
  type = bool
  default = true
}
variable "cluster_public_access_cidrs" {
  type = list(string)
  default = ["127.0.0.1/32"]
}
variable "node_instance_types" {
  type = list(string)
  default = ["t3.medium"]
}
variable "node_desired_size" {
  type = number
  default = 2
}
variable "node_min_size" {
  type = number
  default = 1
}
variable "node_max_size" {
  type = number
  default = 3
}
variable "rds_allowed_client_cidrs" {
  type = list(string)
  default = []
}
variable "db_name" {
  type = string
  default = "employees"
}
variable "db_username" {
  type = string
  default = "employee_admin"
}
variable "db_password" {
  type = string
  sensitive = true
}
variable "db_instance_class" {
  type = string
  default = "db.t3.micro"
}
variable "db_multi_az" {
  type = bool
  default = false
}
variable "db_deletion_protection" {
  type = bool
  default = false
}
variable "db_skip_final_snapshot" {
  type = bool
  default = true
}
