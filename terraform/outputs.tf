# ── IAM ──────────────────────────────────────────────────────
output "data_engineer_role_arn" {
  description = "DataEngineerRole ARN"
  value       = module.iam.data_engineer_role_arn
}

output "glue_service_role_arn" {
  description = "GlueServiceRole ARN"
  value       = module.iam.glue_service_role_arn
}

output "lambda_execution_role_arn" {
  description = "LambdaExecutionRole ARN"
  value       = module.iam.lambda_execution_role_arn
}

output "redshift_iam_role_arn" {
  description = "RedshiftIAMRole ARN"
  value       = module.iam.redshift_iam_role_arn
}

output "analyst_read_only_role_arn" {
  description = "AnalystReadOnlyRole ARN"
  value       = module.iam.analyst_read_only_role_arn
}

output "data_lake_policy_arn" {
  description = "DataLakeBucketAccessPolicy ARN"
  value       = module.iam.data_lake_policy_arn
}

output "step_functions_execution_role_arn" {
  description = "StepFunctionsExecutionRole ARN"
  value       = module.iam.step_functions_execution_role_arn
}

# ── VPC ──────────────────────────────────────────────────────
output "vpc_id" {
  description = "data-platform-vpc ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "public-subnet-1a ID"
  value       = module.vpc.public_subnet_id
}

output "private_subnet_1a_id" {
  description = "private-subnet-1a ID"
  value       = module.vpc.private_subnet_1a_id
}

output "private_subnet_1b_id" {
  description = "private-subnet-1b ID"
  value       = module.vpc.private_subnet_1b_id
}

output "sg_private_compute_id" {
  description = "sg-private-compute security group ID"
  value       = module.vpc.sg_private_compute_id
}

output "sg_private_db_id" {
  description = "sg-private-db security group ID"
  value       = module.vpc.sg_private_db_id
}

# ── S3 ───────────────────────────────────────────────────────
output "data_lake_bucket_id" {
  description = "Data lake bucket name"
  value       = module.s3.data_lake_bucket_id
}

output "data_lake_bucket_arn" {
  description = "Data lake bucket ARN"
  value       = module.s3.data_lake_bucket_arn
}

output "logs_bucket_id" {
  description = "Access logs bucket name"
  value       = module.s3.logs_bucket_id
}

output "cloudtrail_arn" {
  description = "CloudTrail audit trail ARN"
  value       = module.s3.cloudtrail_arn
}
