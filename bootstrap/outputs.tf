output "bucket_name" {
  description = "Bucket de state, a reporter dans les blocs backend"
  value       = aws_s3_bucket.tfstate.id
}

output "kms_key_arn" {
  description = "ARN de la cle de chiffrement des states"
  value       = aws_kms_key.tfstate.arn
}

output "region" {
  value = var.aws_region
}
