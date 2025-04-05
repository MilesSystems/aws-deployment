output "s3_bucket" {
  description = "Bucket Created using this template."
  value = aws_s3_bucket.s3_bucket.id
}

