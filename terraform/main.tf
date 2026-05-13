terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "iam" {
  source         = "./modules/iam"
  aws_account_id = var.aws_account_id
}

module "vpc" {
  source             = "./modules/vpc"
  aws_region         = var.aws_region
  enable_nat_gateway = var.enable_nat_gateway
}

module "s3" {
  source = "./modules/s3"

  aws_account_id         = var.aws_account_id
  aws_region             = var.aws_region
  data_engineer_role_arn = module.iam.data_engineer_role_arn
  glue_service_role_arn  = module.iam.glue_service_role_arn
  redshift_iam_role_arn  = module.iam.redshift_iam_role_arn

  depends_on = [module.iam]
}
