variable "backend_repository" {
  type = string default = "employee-backend"
}
variable "frontend_repository" {
  type = string default = "employee-frontend"
}
variable "image_tag_mutability" {
  type = string default = "IMMUTABLE"
}
variable "keep_image_count" {
  type = number default = 30
}
variable "tags" {
  type = map(string) default = {}
}
