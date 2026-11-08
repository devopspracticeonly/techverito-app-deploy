terraform {
  backend "s3" {
    bucket         = "techverito-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "techverito-terraform-locks"
  }
}