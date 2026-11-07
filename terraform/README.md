# Employee Management EKS Terraform

Reusable modules: `vpc`, `eks`, `ecr`, `rds`. Each module has its own `main.tf`, `variables.tf`, `outputs.tf`, and `versions.tf`.

Dependency graph:
- VPC -> EKS (subnet IDs)
- VPC -> RDS (VPC ID, VPC CIDR, private subnet IDs)
- ECR is standalone
- EKS and RDS do not depend on each other

Run from `environments/dev` (or test/prod):
```bash
cp terraform.tfvars.example terraform.tfvars
export TF_VAR_db_password='use-a-secret-manager-value'
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```
Restrict `cluster_public_access_cidrs` to trusted IPs. For production, use encrypted remote state with locking, AWS Secrets Manager for DB credentials, RDS deletion protection, Multi-AZ, and tighter RDS ingress. Terraform state can contain the DB password. NAT gateways, EKS, and RDS incur ongoing charges. Validate the selected EKS and PostgreSQL versions against current AWS regional support before applying.
