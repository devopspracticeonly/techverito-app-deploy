terraform {
  backend "s3" {
    bucket         = "techverito-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
	use_lockfile   = true
  }
}