project_name = "taskflow"
environment  = "dev"

aws_region = "ap-south-1"
dr_region  = "ap-southeast-1"
vpc_cidr   = "10.20.0.0/16"

# Development uses one NAT Gateway to reduce cost.
single_nat_gateway = true

# DNS and HTTPS will be added after the ALB works.
certificate_arn = ""
hosted_zone_id  = ""
domain_name     = ""

# Keep this disabled for the first deployment.
# We will enable it after testing the public ALB.
enable_global_accelerator = false

enable_deletion_protection = false

web_instance_type    = "t3.micro"
web_min_size         = 1
web_desired_capacity = 1
web_max_size         = 3

app_instance_type    = "t3.micro"
app_min_size         = 1
app_desired_capacity = 1
app_max_size         = 3

database_instance_class        = "db.t4g.micro"
database_multi_az              = false
database_deletion_protection   = false
database_skip_final_snapshot   = true
database_backup_retention_days = 1
dr_backup_retention_days       = 1

artifact_bucket_force_destroy = true

alarm_email = ""

default_tags = {
  Owner       = "sangram"
  Environment = "dev"
  Project     = "taskflow"
  ManagedBy   = "Terraform"
}
