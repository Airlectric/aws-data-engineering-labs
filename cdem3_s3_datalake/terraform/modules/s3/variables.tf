variable "aws_account_id" {
  description = "AWS account ID — used in bucket names and bucket policy ARNs"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "data_engineer_role_arn" {
  description = "ARN of DataEngineerRole (from CDEM1)"
  type        = string
}

variable "glue_service_role_arn" {
  description = "ARN of GlueServiceRole (from CDEM1)"
  type        = string
}

variable "redshift_iam_role_arn" {
  description = "ARN of RedshiftIAMRole (from CDEM1)"
  type        = string
}
