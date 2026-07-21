# Deployment and Failure Test Matrix

This matrix prevents configuration combinations from being mixed blindly. Run the smallest case first, then add DNS and HTTPS.

## Configuration combinations

| Case | Global Accelerator | Domain/Route 53 | Certificate | Expected entry point |
|---|---:|---:|---:|---|
| 1. First deployment | On | No | No | Global Accelerator DNS over HTTP |
| 2. Lowest complexity | Off | No | No | Public ALB DNS over HTTP |
| 3. Full requested path | On | Yes | Auto-created by Terraform | Custom domain over HTTPS |
| 4. Existing certificate | On | Yes | Existing ACM ARN | Custom domain over HTTPS |
| 5. No accelerator | Off | Yes | Auto-created or existing | Route 53 alias to public ALB over HTTPS |

Important: when HTTPS is enabled, use the custom domain. The generated Global Accelerator or ALB hostname will not match the custom ACM certificate.

## Availability combinations

| Setting | Development | Production expectation |
|---|---:|---:|
| Availability Zones | 2 | 2 or 3 after design review |
| NAT Gateways | 1 to reduce cost | 1 per AZ |
| Web desired capacity | 1 for initial test | At least 2 |
| App desired capacity | 1 for initial test | At least 2 |
| RDS Multi-AZ | Enabled in example | Enabled |
| ALB/RDS deletion protection | Off for disposable dev | On |
| Backup copy | Primary to DR Region | Enabled and restore-tested |

## Validation sequence

1. Run `./scripts/validate.sh`.
2. Run `terraform plan` and review all replacements, public exposure, and costs.
3. Apply Case 1 or Case 2 first.
4. Verify `/health.html`, `/api/health`, CRUD operations, target health, alarms, and backups.
5. Add Route 53 and HTTPS only after the base path is healthy.
6. Run one failure test at a time.

## Failure tests

| Test | Action | Expected result |
|---|---|---|
| Web instance failure | Terminate one web EC2 instance | ALB keeps using a healthy target; ASG replaces the instance |
| App instance failure | Terminate one app EC2 instance | Internal ALB keeps using a healthy target; ASG replaces it |
| AZ tolerance | Stop/terminate the test instances in one AZ | Traffic continues through the other AZ when capacity exists there |
| RDS failover | Reboot with failover in an approved window | Endpoint stays the same; short connection interruption is possible |
| Scale out | Generate controlled CPU load | Target-tracking policy adds capacity after thresholds and cooldowns |
| Backup restore | Restore the copied recovery point in DR Region | Restored DB is reachable from a temporary private test host and data checks pass |

## What this does not prove

Static validation does not prove that your account quotas, IAM permissions, domain delegation, regional service availability, or organization policies will permit the apply. A reviewed `terraform plan`, an AWS apply in a non-production account, and the failure tests above are mandatory before production use.
