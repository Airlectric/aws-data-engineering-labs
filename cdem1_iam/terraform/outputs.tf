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
