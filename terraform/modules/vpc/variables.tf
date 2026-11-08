variable "name" {
  type = string
}
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
variable "availability_zones" {
  type = list(string)
}
variable "public_subnets" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}
variable "nat_gateway_count" {
  type    = number
  default = 1
}
variable "tags" {
  type    = map(string)
  default = {}
}
