variable "aws_account_id" {
  description = "AWS account ID — used in bucket names and bucket policy ARNs"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "data_engineer_role_arn" {
  description = "ARN of DataEngineerRole — granted read/write access via bucket policy"
  type        = string
}

variable "glue_service_role_arn" {
  description = "ARN of GlueServiceRole — granted read/write access for ETL jobs"
  type        = string
}

variable "redshift_iam_role_arn" {
  description = "ARN of RedshiftIAMRole — granted read access for COPY commands"
  type        = string
}
