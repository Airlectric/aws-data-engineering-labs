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

# Read IAM role ARNs from the cdem1_iam state — apply cdem1_iam first.
data "terraform_remote_state" "iam" {
  backend = "local"
  config = {
    path = "${path.module}/../cdem1_iam/terraform.tfstate"
  }
}

module "s3" {
  source = "../modules/s3"

  aws_account_id         = var.aws_account_id
  aws_region             = var.aws_region
  data_engineer_role_arn = data.terraform_remote_state.iam.outputs.data_engineer_role_arn
  glue_service_role_arn  = data.terraform_remote_state.iam.outputs.glue_service_role_arn
  redshift_iam_role_arn  = data.terraform_remote_state.iam.outputs.redshift_iam_role_arn
}
