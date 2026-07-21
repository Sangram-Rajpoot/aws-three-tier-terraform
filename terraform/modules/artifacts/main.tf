resource "random_id" "suffix" {
  byte_length = 4
}

data "archive_file" "frontend" {
  type        = "zip"
  source_dir  = var.frontend_source_dir
  output_path = "${path.root}/frontend-artifact.zip"
  excludes    = ["Dockerfile", "nginx.local.conf", ".dockerignore"]
}

data "archive_file" "backend" {
  type        = "zip"
  source_dir  = var.backend_source_dir
  output_path = "${path.root}/backend-artifact.zip"
  excludes    = ["Dockerfile", ".dockerignore", "__pycache__"]
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.name}-artifacts-${random_id.suffix.hex}"
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Name = "${var.name}-artifacts" })
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

resource "aws_s3_object" "frontend" {
  bucket       = aws_s3_bucket.artifacts.id
  key          = "releases/frontend.zip"
  source       = data.archive_file.frontend.output_path
  source_hash  = data.archive_file.frontend.output_base64sha256
  content_type = "application/zip"

  depends_on = [aws_s3_bucket_versioning.artifacts, aws_s3_bucket_server_side_encryption_configuration.artifacts]
}

resource "aws_s3_object" "backend" {
  bucket       = aws_s3_bucket.artifacts.id
  key          = "releases/backend.zip"
  source       = data.archive_file.backend.output_path
  source_hash  = data.archive_file.backend.output_base64sha256
  content_type = "application/zip"

  depends_on = [aws_s3_bucket_versioning.artifacts, aws_s3_bucket_server_side_encryption_configuration.artifacts]
}
