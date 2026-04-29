# ============================================================
# S3 BUCKETS
# Two buckets:
#   data-lake-prod-ACCOUNT_ID  — actual data (raw/processed/curated/temp/archive)
#   data-lake-prod-logs-ACCOUNT_ID — access logs + CloudTrail logs only
# Keeping logs in a separate bucket prevents audit logs from
# showing up in data queries and simplifies lifecycle rules.
# ============================================================
resource "aws_s3_bucket" "data_lake" {
  bucket        = "data-lake-prod-${var.aws_account_id}"
  force_destroy = true

  tags = {
    Name        = "data-lake-prod-${var.aws_account_id}"
    Environment = "Production"
    Owner       = "DataEngineering"
    Purpose     = "DataLake"
    CostCenter  = "Analytics"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket        = "data-lake-prod-logs-${var.aws_account_id}"
  force_destroy = true

  tags = {
    Name        = "data-lake-prod-logs-${var.aws_account_id}"
    Environment = "Production"
    Owner       = "DataEngineering"
    Purpose     = "DataLakeLogs"
    CostCenter  = "Analytics"
  }
}

# ============================================================
# PUBLIC ACCESS BLOCK
# All four settings = true is the modern default for any
# private data bucket. Prevents accidental exposure even if
# someone attaches a permissive bucket policy.
# ============================================================
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# ENCRYPTION (SSE-S3 / AES-256)
# Free tier encryption. Meets GDPR, HIPAA, PCI-DSS, SOC2.
# KMS would give per-key rotation but costs $1/key/month.
# ============================================================
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================
# VERSIONING
# Keeps every version of every object. Lets you recover
# accidentally deleted or overwritten files.
# Cost: extra $0.023/GB for each stored version.
# ============================================================
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================
# ACCESS LOGGING
# Records every GET/PUT/DELETE: who, what file, when.
# Logs go to the separate logs bucket to keep data and
# audit records cleanly separated.
# ============================================================
resource "aws_s3_bucket_logging" "data_lake" {
  bucket        = aws_s3_bucket.data_lake.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

# ============================================================
# LIFECYCLE RULES
# Automates storage cost savings without manual intervention.
#
# processed/ → Glacier IR at 90d, Deep Archive at 180d
#   Compliance data: queryable fast for 90 days, then cold.
#
# temp/       → delete after 1 day
#   Spark intermediate outputs — gone automatically.
#
# archive/    → Glacier at day 1, Deep Archive at day 91,
#              expire (delete) at 7 years (GDPR legal hold).
#
# depends_on: versioning must be enabled first to avoid
# an eventual-consistency race condition in the AWS API.
# ============================================================
resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket     = aws_s3_bucket.data_lake.id
  depends_on = [aws_s3_bucket_versioning.data_lake]

  rule {
    id     = "archive-processed-data-after-90-days"
    status = "Enabled"
    filter { prefix = "processed/" }
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }
  }

  rule {
    id     = "delete-temp-data-after-1-day"
    status = "Enabled"
    filter { prefix = "temp/" }
    expiration { days = 1 }
  }

  rule {
    id     = "archive-and-delete-after-7-years"
    status = "Enabled"
    filter { prefix = "archive/" }
    transition {
      days          = 1
      storage_class = "GLACIER"
    }
    transition {
      days          = 91
      storage_class = "DEEP_ARCHIVE"
    }
    expiration { days = 2555 }
  }
}

# ============================================================
# BUCKET POLICIES
#
# data_lake policy enforces:
#   1. SSL-only connections (deny HTTP)
#   2. Encrypted uploads only (deny unencrypted PutObject)
#   3. Explicit allow for the three IAM roles that need access
#
# logs policy allows CloudTrail to write trail logs.
# S3 access logging does NOT need an explicit policy —
# it is handled by the aws_s3_bucket_logging resource.
#
# depends_on public_access_block: bucket policies are
# rejected while public-access-block is being applied.
# ============================================================
resource "aws_s3_bucket_policy" "data_lake" {
  bucket     = aws_s3_bucket.data_lake.id
  depends_on = [aws_s3_bucket_public_access_block.data_lake]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.data_lake.arn}/*"
        Condition = {
          StringNotEqualsIfExists = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
          # Both conditions must be true for the Deny to fire.
          # DataSync does not send the SSE header in its access test,
          # so we exclude it here. The bucket default encryption still
          # applies, so DataSync writes are encrypted automatically.
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${var.aws_account_id}:role/DataSyncS3Role",
              "arn:aws:iam::${var.aws_account_id}:role/KinesisFirehoseS3Role"
            ]
          }
        }
      },
      {
        Sid       = "AllowDataEngineerRole"
        Effect    = "Allow"
        Principal = { AWS = var.data_engineer_role_arn }
        Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      {
        Sid       = "AllowGlueServiceRole"
        Effect    = "Allow"
        Principal = { AWS = var.glue_service_role_arn }
        Action    = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      {
        Sid       = "AllowRedshiftIAMRole"
        Effect    = "Allow"
        Principal = { AWS = var.redshift_iam_role_arn }
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      # {
      #   Sid       = "AllowDataSyncRole"
      #   Effect    = "Allow"
      #   Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:role/DataSyncS3Role" }
      #   Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation", "s3:GetObjectTagging", "s3:PutObjectTagging"]
      #   Resource = [
      #     aws_s3_bucket.data_lake.arn,
      #     "${aws_s3_bucket.data_lake.arn}/*"
      #   ]
      # }
    ]
  })
}

resource "aws_s3_bucket_policy" "logs" {
  bucket     = aws_s3_bucket.logs.id
  depends_on = [aws_s3_bucket_public_access_block.logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# ============================================================
# FOLDER STRUCTURE
# S3 has no real folders — everything is a flat key namespace.
# These empty objects create the visual folder structure in
# the console and establish the zone prefixes upfront.
# ============================================================
resource "aws_s3_object" "raw" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "raw/"
  content = ""
}

resource "aws_s3_object" "processed" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "processed/"
  content = ""
}

resource "aws_s3_object" "curated" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "curated/"
  content = ""
}

resource "aws_s3_object" "temp" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "temp/"
  content = ""
}

resource "aws_s3_object" "archive" {
  bucket  = aws_s3_bucket.data_lake.id
  key     = "archive/"
  content = ""
}

# ============================================================
# CLOUDTRAIL AUDIT TRAIL
# Logs infrastructure-level changes (who changed bucket
# policy, who enabled encryption) — complements S3 access
# logs which record data-level access (who read a file).
# enable_log_file_validation: detects tampered log files.
# depends_on logs policy: CloudTrail creation fails if the
# bucket policy isn't in place first.
# ============================================================
resource "aws_cloudtrail" "data_lake_audit" {
  name                          = "data-lake-audit-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.data_lake.arn}/"]
    }
  }

  depends_on = [aws_s3_bucket_policy.logs]

  tags = {
    Name        = "data-lake-audit-trail"
    Environment = "Production"
    Purpose     = "Compliance"
  }
}
