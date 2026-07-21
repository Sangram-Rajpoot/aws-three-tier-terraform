# AWS Three-Tier Application with Module-Based Terraform

This repository contains a working three-tier sample application and reusable Terraform modules for the requested AWS architecture.

```text
Users in India / USA / Canada / Australia
                    |
              Route 53 DNS
                    |
          AWS Global Accelerator
                    |
       Public Application Load Balancer
                    |
        Web Auto Scaling Group (Nginx)
              AZ-1       AZ-2
                    |
       Internal Application Load Balancer
                    |
       App Auto Scaling Group (Flask API)
              AZ-1       AZ-2
                    |
           RDS MySQL Multi-AZ
                    |
       AWS Backup cross-Region copy
                    |
             DR backup vault
```

## What is included

- Four subnet layers across two Availability Zones: public, private web, private application, and isolated database.
- Internet Gateway and either one NAT Gateway for development or one NAT Gateway per AZ for production.
- Public and internal Application Load Balancers.
- Separate web and application Auto Scaling Groups.
- Amazon Linux 2023 instances with no public IPs and no SSH ingress.
- Systems Manager Session Manager access.
- Separate least-privilege IAM roles for web and application instances.
- RDS for MySQL 8.4, Multi-AZ, customer-managed KMS encryption, TLS-required connections, Secrets Manager-managed password, backups, and slow-query log export.
- AWS Global Accelerator with the public ALB as its endpoint. Terraform uses a dedicated `aws.global` provider in `us-west-2` for Global Accelerator API operations while the endpoint group targets the workload Region.
- Optional Route 53 record and ACM certificate created through Terraform.
- AWS Backup with a daily backup, customer-managed KMS keys, and cross-Region copy.
- CloudWatch alarms and an optional SNS email subscription.
- Encrypted, versioned S3 application-artifact bucket.
- Encrypted, versioned S3 Terraform-state bootstrap configuration.
- A realistic TaskFlow application with dashboard metrics, projects, tasks, activity history, search, filters, CRUD APIs, health checks, and MySQL persistence.

## Important correction about disaster recovery

The included DR design is **backup and restore**. It protects data in another Region, but it is not automatic regional failover and it is not zero downtime.

Automatic regional failover requires a second running application stack and continuously replicated data, normally using a warm-standby design and a technology such as Aurora Global Database or a cross-Region database replica. Build that only after the required RTO and RPO are approved.

## Repository structure

```text
application/
  frontend/                     Nginx-hosted browser application
  backend/                      Flask API and MySQL schema
  docker-compose.yml            Local three-tier test
terraform/
  bootstrap/                    S3 remote-state bucket
  modules/
    artifacts/
    backup/
    certificate/
    compute/
    database/
    dns/
    global-accelerator/
    load-balancers/
    monitoring/
    network/
    security/
  stacks/three-tier/            Composition of the reusable modules
  environments/dev/             Lower-cost test configuration
  environments/prod/            Production-oriented configuration
scripts/validate.sh              Static validation commands
TEST_MATRIX.md                   Configuration and failure-test combinations
```

## Cost warning

This is not a free-tier architecture. NAT Gateway, Global Accelerator, two ALBs, EC2, Multi-AZ RDS, AWS Backup, cross-Region storage, and data transfer all create charges. Deploy development first and destroy disposable resources after testing.

## Prerequisites

Install:

- Terraform 1.10 or newer.
- AWS CLI v2.
- Docker only when testing the application locally.
- An AWS account with permission for VPC, EC2, IAM, ELB, RDS, S3, Secrets Manager, Route 53, ACM, Global Accelerator, AWS Backup, CloudWatch, and SNS.

Verify the tools and credentials:

```bash
terraform version
aws --version
aws sts get-caller-identity
```

# Step-by-step deployment

## Step 1: Test the application locally

```bash
cd application
docker compose up --build
```

Open:

```text
http://localhost:8080
```

Verify:

```bash
curl http://localhost:8080/health.html
curl http://localhost:8080/api/health
```

Create and update a project and a task in the browser. Then stop the local stack:

```bash
docker compose down -v
```

## Step 2: Run static checks

From the repository root:

```bash
./scripts/validate.sh
```

This checks Python, JavaScript, user-data shell syntax, Terraform formatting, provider initialization, and Terraform validation for dev and prod. Terraform preconditions also reject invalid DNS pairs, unsafe production capacity, same-Region DR, invalid capacity ranges, and unsupported subnet sizing.

## Step 3: Create the remote Terraform-state bucket

The backend bucket must exist before an environment can use it.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output -raw state_bucket_name
```

Keep the bootstrap state safe. The bucket has `prevent_destroy = true` because accidental deletion of Terraform state is unacceptable.

## Step 4: Enable the backend for dev

```bash
cd ../environments/dev
cp backend.tf.example backend.tf
```

Edit `backend.tf` and replace the bucket name with the output from Step 3.

Initialize the backend:

```bash
terraform init -reconfigure
```

Terraform uses S3 native state locking through `use_lockfile = true`.

## Step 5: Configure development

```bash
cp terraform.tfvars.example terraform.tfvars
```

For the first deployment, keep DNS and HTTPS disabled:

```hcl
project_name = "taskflow"
environment  = "dev"
aws_region   = "ap-south-1"
dr_region    = "ap-southeast-1"

single_nat_gateway       = true
enable_global_accelerator = true

hosted_zone_id  = ""
domain_name     = ""
certificate_arn = ""
```

The example keeps RDS Multi-AZ enabled because HA is part of the task. One web and one app instance are used initially to reduce test cost. That initial capacity does not prove instance-level redundancy; increase each desired capacity to two for HA testing.

## Step 6: Plan before applying

```bash
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

Check the plan for:

- Exactly one VPC.
- Two Availability Zones.
- Public ALB only in public subnets.
- Web and app EC2 instances only in private subnets.
- No SSH ingress and no public EC2 addresses.
- RDS marked private, encrypted, Multi-AZ, and deletion settings matching the environment.
- One NAT Gateway in dev or one per AZ in prod.
- Correct primary and DR Regions.
- No unexpected resource replacement.

## Step 7: Deploy

```bash
terraform apply tfplan
```

RDS, Global Accelerator, load balancers, instance bootstrapping, and target health checks can take time.

Read the outputs:

```bash
terraform output
```

For the first HTTP deployment:

```bash
GA_DNS="$(terraform output -raw global_accelerator_dns_name)"
ALB_DNS="$(terraform output -raw public_alb_dns_name)"

curl -I "http://${GA_DNS}/health.html"
curl "http://${GA_DNS}/api/health"
curl -I "http://${ALB_DNS}/health.html"
curl "http://${ALB_DNS}/api/health"
```

## Step 8: Check instance bootstrapping

List the instances:

```bash
aws ec2 describe-instances \
  --filters \
    "Name=tag:Project,Values=taskflow" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,Tags[?Key==`Tier`].Value|[0]]' \
  --output table
```

Connect through Systems Manager, not SSH:

```bash
aws ssm start-session --target i-REPLACE_ME
```

Check startup logs:

```bash
sudo tail -n 200 /var/log/user-data.log
sudo systemctl status nginx       # web tier
sudo systemctl status taskflow    # app tier
sudo journalctl -u taskflow -n 200 --no-pager
```

## Step 9: Add Route 53 and HTTPS

You need a domain delegated to an existing Route 53 public hosted zone. Domain registration and registrar nameserver delegation are external prerequisites.

Set these values:

```hcl
hosted_zone_id = "Z0123456789EXAMPLE"
domain_name    = "taskflow.example.com"

# Leave blank to let Terraform create and DNS-validate the ACM certificate.
certificate_arn = ""
```

Or supply an existing ACM certificate ARN from the same Region as the public ALB.

Apply again:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform will:

1. Request the ACM certificate when no existing ARN is supplied.
2. Create the ACM DNS validation record.
3. Wait for certificate validation.
4. Add the ALB HTTPS listener.
5. Redirect port 80 to port 443.
6. Point the custom Route 53 name to Global Accelerator, or directly to the ALB when Global Accelerator is disabled.

After HTTPS is enabled, test the custom domain, not the generated AWS hostname:

```bash
curl -I https://taskflow.example.com/health.html
curl https://taskflow.example.com/api/health
```

The generated ALB or Global Accelerator hostname will not match your custom ACM certificate.

## Step 10: Confirm each tier

### Route 53

```bash
nslookup taskflow.example.com
```

### Global Accelerator

Confirm that the accelerator is enabled and that the public ALB endpoint is healthy.

### Public ALB and web tier

In EC2 > Target Groups, confirm the web target group has healthy targets in the expected AZs.

### Internal ALB and app tier

Confirm the application target group is healthy on port 8000 and path `/health`.

### RDS

```bash
terraform output -raw database_endpoint
terraform output -raw database_secret_arn
```

The password is generated and stored in Secrets Manager. It is not supplied in `tfvars` and should not be committed to Git.

The application downloads the Amazon RDS CA bundle and verifies the RDS server identity. The custom MySQL parameter group requires encrypted transport.

### Backups

Check AWS Backup in both Regions. Confirm that a primary recovery point is created and copied to the DR vault.

## Step 11: Run controlled failure tests

Do not trigger multiple failures together during the first test.

### Web instance failure

Increase web desired capacity to at least two, apply, then terminate one web instance. The ALB should continue through the other healthy target and the ASG should replace the failed instance.

### App instance failure

Increase app desired capacity to at least two, apply, then terminate one app instance. The internal ALB should continue through another healthy target and the ASG should replace it.

### RDS failover

Use RDS reboot with failover only during an approved test window. The endpoint remains the same, but existing connections can fail briefly while the application reconnects.

### Backup restore

Restore a copied recovery point into the DR Region and validate tables, row counts, and application connectivity from a temporary private test host. A backup that has never been restored is unproven.

See `TEST_MATRIX.md` for the complete configuration and failure-test matrix.

## Step 12: Deploy production

```bash
cd ../prod
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
```

Use a separate state key and review these minimum settings:

```hcl
single_nat_gateway             = false
web_min_size                  = 2
web_desired_capacity          = 2
app_min_size                  = 2
app_desired_capacity          = 2
enable_deletion_protection    = true
database_deletion_protection  = true
database_skip_final_snapshot  = false
database_multi_az             = true
artifact_bucket_force_destroy = false
```

Then run:

```bash
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

# Module purpose in simple terms

| Module | Responsibility |
|---|---|
| `network` | VPC, four subnet layers, routing, IGW, NAT |
| `security` | Tier-to-tier security-group rules |
| `certificate` | Optional ACM certificate and DNS validation |
| `database` | MySQL 8.4 RDS Multi-AZ, TLS, secret, logs, backups |
| `artifacts` | Packages frontend/backend and uploads encrypted versions to S3 |
| `load-balancers` | Public ALB, internal ALB, listeners, target groups, health checks |
| `compute` | EC2 launch templates, IAM, ASGs, rolling refresh, target tracking |
| `global-accelerator` | Global static entry point mapped to the public ALB |
| `dns` | Route 53 application record |
| `backup` | KMS-encrypted primary backup plan and cross-Region copy |
| `monitoring` | SNS and CloudWatch alarms |

# Security decisions already implemented

- No public IPs on web or app instances.
- No inbound SSH rule.
- SSM-based administration.
- IMDSv2 required.
- Encrypted EC2, RDS, S3 artifacts, and state.
- Database accepts MySQL only from the app security group.
- App accepts port 8000 only from the internal ALB.
- Web accepts port 80 only from the public ALB.
- Internal ALB accepts traffic only from the web tier.
- Separate web/app IAM roles; only the app role can read the database secret.
- RDS TLS certificate and hostname verification.
- RDS password managed by Secrets Manager.

# What must still be added before a real public production launch

This starter is production-oriented infrastructure, not a finished enterprise product. Before handling real users or sensitive data, add:

- Authentication and authorization for the sample application.
- AWS WAF and rate limiting.
- Centralized ALB, Nginx, application, and operating-system logs.
- CI/CD with reviewed plans and security scans.
- Patch-management and vulnerability-management procedures.
- Customer-managed KMS keys for artifact storage and Terraform state when required by policy; RDS and the backup vaults already use customer-managed keys.
- Budget alarms and cost ownership.
- Tested incident, rollback, backup-restore, and regional-DR runbooks.
- A warm-standby Region when the approved RTO/RPO cannot tolerate backup restoration.

# Destroying development

```bash
cd terraform/environments/dev
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

Deletion protection must be disabled before destroying protected ALB or RDS resources. Do not destroy the state bucket with the application environment.

# Reference application

AWS maintains a separate three-tier workshop with React, Node.js, an internal ALB, Auto Scaling, and Aurora MySQL:

https://github.com/aws-samples/aws-three-tier-web-architecture-workshop

That repository is useful for comparison. The TaskFlow application in this repository is already wired to the module-based Terraform stack and is simpler to deploy as one project.
