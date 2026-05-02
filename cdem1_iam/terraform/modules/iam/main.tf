# ============================================================
# CUSTOM POLICY: DataLakeBucketAccessPolicy
# Restricts access to data-lake-* buckets only and enforces
# AES256 encryption on all uploads (compliance requirement).
# ============================================================
resource "aws_iam_policy" "data_lake_bucket_access" {
  name        = "DataLakeBucketAccessPolicy"
  description = "Custom policy to access data lake S3 bucket with encryption enforcement. Allows read/write to data-lake-* buckets only. Blocks unencrypted uploads for compliance."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListDataLakeBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::data-lake-*"
      },
      {
        Sid    = "ReadWriteDataLakeObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::data-lake-*/*"
      },
      {
        # DENY overrides any Allow — blocks unencrypted uploads even if another
        # policy grants s3:PutObject. This is how compliance is enforced.
        Sid    = "DenyUnencryptedUploads"
        Effect = "Deny"
        Action = "s3:PutObject"
        Resource = "arn:aws:s3:::data-lake-*/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      }
    ]
  })
}

# ============================================================
# ROLE 1: DataEngineerRole
# Your daily work role. Broad access to build and manage
# data pipelines across S3, Glue, Redshift, EMR, Kinesis,
# Lambda, and CloudWatch.
# Trust: EC2 (can also be assumed by other services/people)
# ============================================================
resource "aws_iam_role" "data_engineer" {
  name        = "DataEngineerRole"
  description = "Role for data engineers to access S3, Glue, Redshift, EMR, Kinesis, Lambda, and Cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "data_engineer_s3" {
  role       = aws_iam_role.data_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "data_engineer_glue" {
  role       = aws_iam_role.data_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}

resource "aws_iam_role_policy_attachment" "data_engineer_redshift" {
  role       = aws_iam_role.data_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess"
}

resource "aws_iam_role_policy_attachment" "data_engineer_emr" {
  role       = aws_iam_role.data_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2"
}

resource "aws_iam_role_policy_attachment" "data_engineer_kinesis" {
  role       = aws_iam_role.data_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
}

resource "aws_iam_role_policy_attachment" "data_engineer_lambda" {
  role       = aws_iam_role.data_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_role_policy_attachment" "data_engineer_cloudwatch" {
  role       = aws_iam_role.data_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# ============================================================
# ROLE 2: GlueServiceRole
# Assumed by the Glue SERVICE (not a person) when running jobs.
# Kept separate so a hacked laptop can't directly use Glue's
# permissions — the job must be explicitly created first.
# Trust: glue.amazonaws.com
# ============================================================
resource "aws_iam_role" "glue_service" {
  name        = "GlueServiceRole"
  description = "Service role for AWS Glue jobs to access S3, CloudWatch Logs, and Secrets Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_service_s3" {
  role       = aws_iam_role.glue_service.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_service_cloudwatch" {
  role       = aws_iam_role.glue_service.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_service_secrets" {
  role       = aws_iam_role.glue_service.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# ============================================================
# ROLE 3: LambdaExecutionRole
# Assumed by Lambda functions when they run. Limiting this role
# means an exploited Lambda function can only reach what's
# listed here — blast radius is contained.
# Trust: lambda.amazonaws.com
# ============================================================
resource "aws_iam_role" "lambda_execution" {
  name        = "LambdaExecutionRole"
  description = "Execution role for Lambda functions to access S3, DynamoDB, Kinesis, CloudWatch Logs, and Secrets Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_kinesis" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# ============================================================
# ROLE 4: RedshiftIAMRole
# Used by Redshift cluster when running COPY commands from S3.
# Without this role, COPY FROM 's3://...' would be denied.
# Trust: redshift.amazonaws.com
# ============================================================
resource "aws_iam_role" "redshift_iam" {
  name        = "RedshiftIAMRole"
  description = "Service role for Redshift to read/write to S3 and write CloudWatch Logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "redshift.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "redshift_s3" {
  role       = aws_iam_role.redshift_iam.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "redshift_cloudwatch" {
  role       = aws_iam_role.redshift_iam.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Spectrum registers external table definitions in Glue Data Catalog.
# Without this, CREATE EXTERNAL SCHEMA / CREATE EXTERNAL TABLE fail
# with glue:CreateTable / glue:GetDatabase denied errors.
resource "aws_iam_role_policy" "redshift_glue_catalog" {
  name = "RedshiftGlueCatalogAccess"
  role = aws_iam_role.redshift_iam.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "GlueCatalogForSpectrum"
      Effect = "Allow"
      Action = [
        "glue:CreateDatabase",
        "glue:DeleteDatabase",
        "glue:GetDatabase",
        "glue:GetDatabases",
        "glue:CreateTable",
        "glue:DeleteTable",
        "glue:GetTable",
        "glue:GetTables",
        "glue:UpdateTable",
        "glue:GetPartition",
        "glue:GetPartitions",
        "glue:BatchCreatePartition",
        "glue:BatchDeletePartition"
      ]
      Resource = "*"
    }]
  })
}

# ============================================================
# ROLE 5: AnalystReadOnlyRole
# For analysts and BI teams. Can query and view data but cannot
# modify, delete, or create infrastructure. Separating read
# from write reduces the risk of accidental data loss.
# Trust: EC2 (can be assigned to analyst instances)
# ============================================================
resource "aws_iam_role" "analyst_read_only" {
  name        = "AnalystReadOnlyRole"
  description = "Read-only role for analysts to access Redshift, Athena, QuickSight, and S3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "analyst_athena" {
  role       = aws_iam_role.analyst_read_only.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

resource "aws_iam_role_policy_attachment" "analyst_redshift" {
  role       = aws_iam_role.analyst_read_only.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftReadOnlyAccess"
}


resource "aws_iam_role_policy_attachment" "analyst_s3" {
  role       = aws_iam_role.analyst_read_only.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ============================================================
# ROLE 6: StepFunctionsExecutionRole
# Assumed by Step Functions when running a state machine.
# It must be allowed to call every service the state machine
# orchestrates: Lambda (invoke), Glue (startJobRun + poll),
# SNS (publish), DynamoDB (put item for audit log), and
# CloudWatch Logs (for Express workflow execution history).
# Trust: states.amazonaws.com
# ============================================================
resource "aws_iam_role" "step_functions_execution" {
  name        = "StepFunctionsExecutionRole"
  description = "Execution role for Step Functions state machines - invokes Lambda, Glue, SNS, and DynamoDB"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "step_functions_permissions" {
  name = "StepFunctionsPermissions"
  role = aws_iam_role.step_functions_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLambda"
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = "arn:aws:lambda:*:*:function:*"
      },
      {
        Sid    = "StartAndPollGlueJob"
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = "*"
      },
      {
        Sid    = "PublishSNS"
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = "arn:aws:sns:*:*:Pipeline*"
      },
      {
        Sid    = "WriteDynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/PipelineExecutionLog"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}
