variable "name" {
  type = string
}
variable "kubernetes_version" {
  type = string default = "1.31"
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "public_subnet_ids" {
  type = list(string) default = []
}
variable "endpoint_private_access" {
  type = bool default = true
}
variable "endpoint_public_access" {
  type = bool default = true
}
variable "cluster_public_access_cidrs" {
  type = list(string) default = ["127.0.0.1/32"]
}
variable "node_instance_types" {
  type = list(string) default = ["t3.medium"]
}
variable "node_desired_size" {
  type = number default = 2
}
variable "node_min_size" {
  type = number default = 1
}
variable "node_max_size" {
  type = number default = 3
}
variable "node_disk_size" {
  type = number default = 30
}
variable "tags" {
  type = map(string) default = {}
}
