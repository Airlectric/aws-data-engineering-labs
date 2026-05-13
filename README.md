# AWS Data Engineering Infrastructure

Production-grade AWS data platform foundation built with Terraform. Three independently deployable infrastructure layers — IAM, VPC networking, and S3 data lake — wired together using Terraform remote state so outputs flow automatically between layers without hardcoding values.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Account                              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Layer 1 — IAM (cdem1_iam)                              │    │
│  │                                                         │    │
│  │  DataEngineerRole  GlueServiceRole  LambdaExecutionRole │    │
│  │  RedshiftIAMRole   AnalystReadOnlyRole  StepFunctionsRole│    │
│  │  DataLakeBucketAccessPolicy                             │    │
│  └──────────────────────┬──────────────────────────────────┘    │
│                         │ terraform_remote_state                 │
│  ┌──────────────────────┼──────────────────────────────────┐    │
│  │  Layer 3 — S3 Data Lake (cdem3_s3_datalake)             │    │
│  │                      │                                  │    │
│  │  data-lake-prod-*  ──┘  (bucket policy uses IAM ARNs)   │    │
│  │  ├─ raw/                                                │    │
│  │  ├─ processed/  → Glacier 90d → Deep Archive 180d       │    │
│  │  ├─ curated/                                            │    │
│  │  ├─ temp/       → deleted after 1 day                   │    │
│  │  └─ archive/    → Glacier 1d → Deep Archive 91d → 7yr   │    │
│  │  CloudTrail audit trail + access logging                │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Layer 2 — VPC & Network (cdem2_vpc_network)            │    │
│  │                                                         │    │
│  │  data-platform-vpc  10.0.0.0/16                         │    │
│  │  ├─ public-subnet-1a   10.0.1.0/24  (NAT Gateway)       │    │
│  │  ├─ private-subnet-1a  10.0.2.0/24  (databases)         │    │
│  │  └─ private-subnet-1b  10.0.3.0/24  (applications)      │    │
│  │                                                         │    │
│  │  Internet Gateway · NAT Gateway · Route Tables          │    │
│  │  sg-public-nat · sg-private-compute · sg-private-db     │    │
│  │  VPC Endpoints: S3 (free) · DynamoDB (free) · SecretsM  │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
aws-data-engineering-labs/
├── .gitignore
├── README.md
│
├── terraform/
│   ├── modules/                  # Reusable modules (called by root configs)
│   │   ├── iam/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── s3/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   │
│   ├── cdem1_iam/                # Root: deploy IAM roles and policies
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── cdem2_vpc_network/        # Root: deploy VPC and network resources
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   └── cdem3_s3_datalake/        # Root: deploy S3 data lake (requires cdem1_iam)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
│
└── docs/
    ├── iam/
    ├── vpc_network/
    └── s3_datalake/
        └── sample_data/
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5 | `brew install terraform` or download from HashiCorp |
| [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | >= 2.0 | `brew install awscli` |
| AWS Account | — | Active account with billing enabled |

---

## AWS Credentials Setup

### Option A — Named Profile (recommended for multiple accounts)

```bash
aws configure --profile data-engineering
# AWS Access Key ID:     <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name:   us-east-1
# Default output format: json
```

Export the profile before running Terraform:

```bash
export AWS_PROFILE=data-engineering
```

### Option B — Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Verify credentials

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
  "UserId": "AIDA...",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

---

## Deployment

> **Deploy order matters.** The S3 data lake (Layer 3) reads IAM role ARNs from Layer 1's Terraform state. Always apply `cdem1_iam` before `cdem3_s3_datalake`. Layer 2 (`cdem2_vpc_network`) is independent and can be deployed in any order.

### Layer 1 — IAM Roles & Policies

```bash
cd terraform/cdem1_iam

# Copy the example vars file and fill in your account ID
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   aws_account_id = "123456789012"

terraform init
terraform plan
terraform apply
```

**Outputs after apply:**

| Output | Description |
|--------|-------------|
| `data_engineer_role_arn` | ARN for day-to-day pipeline work |
| `glue_service_role_arn` | ARN assumed by Glue ETL jobs |
| `lambda_execution_role_arn` | ARN assumed by Lambda functions |
| `redshift_iam_role_arn` | ARN used by Redshift COPY commands |
| `analyst_read_only_role_arn` | Read-only ARN for analysts/BI |
| `step_functions_execution_role_arn` | ARN for Step Functions state machines |
| `data_lake_policy_arn` | Custom policy ARN (encryption enforcement) |

---

### Layer 2 — VPC & Network

```bash
cd terraform/cdem2_vpc_network

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   aws_region         = "us-east-1"
#   enable_nat_gateway = true    # set false to avoid ~$0.32/hr cost

terraform init
terraform plan
terraform apply
```

**Outputs after apply:**

| Output | Description |
|--------|-------------|
| `vpc_id` | data-platform-vpc ID |
| `public_subnet_id` | public-subnet-1a (10.0.1.0/24) |
| `private_subnet_1a_id` | private-subnet-1a (10.0.2.0/24) |
| `private_subnet_1b_id` | private-subnet-1b (10.0.3.0/24) |
| `internet_gateway_id` | data-platform-igw ID |
| `nat_gateway_id` | data-platform-nat ID (null if disabled) |
| `sg_public_nat_id` | Public NAT security group ID |
| `sg_private_compute_id` | Compute security group ID |
| `sg_private_db_id` | Database security group ID |

---

### Layer 3 — S3 Data Lake

> Requires Layer 1 (`cdem1_iam`) to be applied first. IAM role ARNs are read automatically from `terraform/cdem1_iam/terraform.tfstate`.

```bash
cd terraform/cdem3_s3_datalake

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   aws_account_id = "123456789012"
#   aws_region     = "us-east-1"

terraform init
terraform plan
terraform apply
```

**Outputs after apply:**

| Output | Description |
|--------|-------------|
| `data_lake_bucket_id` | Main data lake bucket name |
| `data_lake_bucket_arn` | Main data lake bucket ARN |
| `logs_bucket_id` | Access and audit logs bucket name |
| `cloudtrail_arn` | CloudTrail audit trail ARN |

---

## Resources Created

### Layer 1 — IAM

| Resource | Type | Purpose |
|----------|------|---------|
| `DataLakeBucketAccessPolicy` | IAM Policy | Restricts S3 access to `data-lake-*` buckets; denies unencrypted uploads |
| `DataEngineerRole` | IAM Role | Full access to S3, Glue, Redshift, EMR, Kinesis, Lambda, CloudWatch |
| `GlueServiceRole` | IAM Role | Assumed by Glue service when running ETL jobs |
| `LambdaExecutionRole` | IAM Role | Assumed by Lambda functions; scoped to S3, DynamoDB, Kinesis |
| `RedshiftIAMRole` | IAM Role | Assumed by Redshift for COPY from S3 and Spectrum queries |
| `AnalystReadOnlyRole` | IAM Role | Read-only access to Redshift, Athena, S3 for analysts |
| `StepFunctionsExecutionRole` | IAM Role | Assumed by Step Functions; can invoke Lambda, Glue, SNS, DynamoDB |

### Layer 2 — VPC & Network

| Resource | Type | Detail |
|----------|------|--------|
| `data-platform-vpc` | VPC | 10.0.0.0/16, DNS hostnames enabled |
| `public-subnet-1a` | Subnet | 10.0.1.0/24, us-east-1a |
| `private-subnet-1a` | Subnet | 10.0.2.0/24, us-east-1a (databases) |
| `private-subnet-1b` | Subnet | 10.0.3.0/24, us-east-1b (applications) |
| `data-platform-igw` | Internet Gateway | Attached to VPC |
| `data-platform-nat` | NAT Gateway | In public subnet; enables private egress |
| `public-route-table` | Route Table | 0.0.0.0/0 → IGW |
| `private-route-table` | Route Table | 0.0.0.0/0 → NAT |
| `sg-public-nat` | Security Group | HTTPS (443) inbound from anywhere |
| `sg-private-compute` | Security Group | All traffic within itself + from public SG |
| `sg-private-db` | Security Group | MySQL (3306) + PostgreSQL (5432) from compute SG only |
| S3 Gateway Endpoint | VPC Endpoint | Free; private S3 traffic stays on AWS backbone |
| DynamoDB Gateway Endpoint | VPC Endpoint | Free; private DynamoDB access |
| Secrets Manager Interface Endpoint | VPC Endpoint | Private DNS; no internet required for secret retrieval |

### Layer 3 — S3 Data Lake

| Resource | Type | Detail |
|----------|------|--------|
| `data-lake-prod-{account_id}` | S3 Bucket | Main data lake; AES-256 encryption, versioning, SSL-only |
| `data-lake-prod-logs-{account_id}` | S3 Bucket | Access logs and CloudTrail logs; separated from data |
| Public Access Block | S3 Config | All four block settings enabled on both buckets |
| Bucket Policy — data lake | S3 Policy | Denies HTTP, denies unencrypted uploads, allows three IAM roles |
| Bucket Policy — logs | S3 Policy | Allows CloudTrail to write audit logs |
| Lifecycle Rule 1 | S3 Lifecycle | `processed/` → Glacier IR at 90 days → Deep Archive at 180 days |
| Lifecycle Rule 2 | S3 Lifecycle | `temp/` → deleted after 1 day |
| Lifecycle Rule 3 | S3 Lifecycle | `archive/` → Glacier at 1 day → Deep Archive at 91 days → deleted at 7 years |
| `data-lake-audit-trail` | CloudTrail | Logs all S3 data and management events; log file validation enabled |
| Folder prefixes | S3 Objects | `raw/`, `processed/`, `curated/`, `temp/`, `archive/` |

---

## Key Design Decisions

**Separate logs bucket** — Audit logs and S3 access logs live in a dedicated bucket. This prevents log records from appearing in data queries and allows different lifecycle policies on logs vs data.

**Deny-based encryption enforcement** — The bucket policy uses an explicit `Deny` on `s3:PutObject` when the `x-amz-server-side-encryption` header is absent or not AES256. A `Deny` overrides any `Allow`, so this enforcement cannot be bypassed even by administrators.

**NAT Gateway toggle** — The `enable_nat_gateway` variable defaults to `true` but can be set to `false` to avoid the ~$0.32/hr cost when the private subnets don't need outbound internet access (e.g. during teardown or when running workloads that only use VPC endpoints).

**Two private subnets across AZs** — `private-subnet-1a` (us-east-1a) and `private-subnet-1b` (us-east-1b) provide redundancy. If one AZ becomes unavailable, resources in the other continue running.

**Gateway VPC Endpoints for S3 and DynamoDB** — Gateway endpoints are free and route traffic to S3 and DynamoDB over the AWS private backbone. This avoids NAT Gateway data-processing charges for high-volume S3 reads/writes from private subnets.

**Remote state dependency** — `cdem3_s3_datalake` reads the IAM role ARNs directly from `cdem1_iam`'s Terraform state file via `terraform_remote_state`. This eliminates hardcoded ARNs and ensures the bucket policy always references the exact roles that exist in the account.

---

## Cost Estimates

| Layer | Resource | Estimated Cost |
|-------|----------|---------------|
| IAM | All roles and policies | **$0.00** — IAM has no charges |
| VPC | VPC, subnets, IGW, route tables, SGs | **$0.00** |
| VPC | NAT Gateway (if enabled) | ~**$0.32/hr** (~$230/month if always on) |
| VPC | S3 + DynamoDB Gateway Endpoints | **$0.00** |
| VPC | Secrets Manager Interface Endpoint | ~**$7/month** |
| S3 | Standard storage | ~**$0.023/GB/month** |
| S3 | Glacier Instant Retrieval | ~**$0.004/GB/month** |
| S3 | Glacier Deep Archive | ~**$0.00099/GB/month** |
| CloudTrail | Management events (first trail) | **$0.00** |
| CloudTrail | Data events (S3 object reads/writes) | ~**$0.10 per 100,000 events** |

> **Cost tip:** Set `enable_nat_gateway = false` in `terraform.tfvars` and run `terraform apply` to remove the NAT Gateway when not actively running workloads in private subnets. The Elastic IP is also released.

---

## Teardown

Destroy each layer in reverse order (deepest dependency first):

```bash
# Layer 3 first
cd terraform/cdem3_s3_datalake
terraform destroy

# Layer 2
cd ../cdem2_vpc_network
terraform destroy

# Layer 1 last
cd ../cdem1_iam
terraform destroy
```

> **Note:** The S3 buckets are created with `force_destroy = true`, so `terraform destroy` will delete all objects in the bucket automatically. Make sure you do not need the data before destroying.

---

## Troubleshooting

**`Error: BucketAlreadyOwnedByYou`**
A bucket with that name already exists in your account from a previous run. Either destroy the existing bucket manually in the AWS console or import it: `terraform import module.s3.aws_s3_bucket.data_lake <bucket-name>`.

**`Error: AccessDenied` on `terraform apply`**
Your AWS credentials do not have sufficient permissions. Confirm that the IAM user or role running Terraform has `AdministratorAccess` or at minimum permissions for IAM, S3, VPC, CloudTrail, and EC2.

**`Error: reading remote state`** (cdem3_s3_datalake)
`cdem1_iam` has not been applied yet or its `terraform.tfstate` file is missing. Run `terraform apply` in `terraform/cdem1_iam/` first.

**`Error: VpcLimitExceeded`**
AWS default limit is 5 VPCs per region. Delete an unused VPC in the AWS console or request a limit increase.
