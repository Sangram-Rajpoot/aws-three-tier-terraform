output "bucket_name" { value = aws_s3_bucket.artifacts.id }
output "bucket_arn" { value = aws_s3_bucket.artifacts.arn }
output "frontend_key" { value = aws_s3_object.frontend.key }
output "frontend_version" { value = coalesce(aws_s3_object.frontend.version_id, data.archive_file.frontend.output_base64sha256) }
output "backend_key" { value = aws_s3_object.backend.key }
output "backend_version" { value = coalesce(aws_s3_object.backend.version_id, data.archive_file.backend.output_base64sha256) }
