terraform {
  backend "s3" {
    bucket       = "techverito-terraform-state-test"
    key          = "test/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}