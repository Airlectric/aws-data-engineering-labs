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
