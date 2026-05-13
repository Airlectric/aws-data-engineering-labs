variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID — used in bucket names"
  type        = string
}

variable "data_engineer_role_arn" {
  description = "ARN of the data engineer IAM role (read/write access to the data lake)"
  type        = string
}

variable "glue_service_role_arn" {
  description = "ARN of the Glue service role (ETL job access to the data lake)"
  type        = string
}

variable "redshift_iam_role_arn" {
  description = "ARN of the Redshift IAM role (read access for COPY commands)"
  type        = string
}
