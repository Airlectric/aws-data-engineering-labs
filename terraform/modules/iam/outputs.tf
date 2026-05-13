output "data_engineer_role_arn" {
  description = "ARN of DataEngineerRole"
  value       = aws_iam_role.data_engineer.arn
}

output "glue_service_role_arn" {
  description = "ARN of GlueServiceRole"
  value       = aws_iam_role.glue_service.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of LambdaExecutionRole"
  value       = aws_iam_role.lambda_execution.arn
}

output "redshift_iam_role_arn" {
  description = "ARN of RedshiftIAMRole"
  value       = aws_iam_role.redshift_iam.arn
}

output "analyst_read_only_role_arn" {
  description = "ARN of AnalystReadOnlyRole"
  value       = aws_iam_role.analyst_read_only.arn
}

output "data_lake_policy_arn" {
  description = "ARN of DataLakeBucketAccessPolicy"
  value       = aws_iam_policy.data_lake_bucket_access.arn
}

output "step_functions_execution_role_arn" {
  description = "ARN of StepFunctionsExecutionRole"
  value       = aws_iam_role.step_functions_execution.arn
}
