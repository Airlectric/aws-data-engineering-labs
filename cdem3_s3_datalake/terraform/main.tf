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

module "s3" {
  source = "./modules/s3"

  aws_account_id         = var.aws_account_id
  aws_region             = var.aws_region
  data_engineer_role_arn = var.data_engineer_role_arn
  glue_service_role_arn  = var.glue_service_role_arn
  redshift_iam_role_arn  = var.redshift_iam_role_arn
}
