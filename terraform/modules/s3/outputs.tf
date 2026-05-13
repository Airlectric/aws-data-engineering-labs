output "data_lake_bucket_id" {
  description = "data-lake-prod-ACCOUNT_ID bucket name"
  value       = aws_s3_bucket.data_lake.id
}

output "data_lake_bucket_arn" {
  description = "data-lake-prod-ACCOUNT_ID bucket ARN"
  value       = aws_s3_bucket.data_lake.arn
}

output "logs_bucket_id" {
  description = "data-lake-prod-logs-ACCOUNT_ID bucket name"
  value       = aws_s3_bucket.logs.id
}

output "cloudtrail_arn" {
  description = "data-lake-audit-trail ARN"
  value       = aws_cloudtrail.data_lake_audit.arn
}
