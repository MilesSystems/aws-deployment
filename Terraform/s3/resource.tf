resource "aws_s3_bucket" "s3_bucket" {
  bucket = {
    ServerSideEncryptionConfiguration = [
      {
        ServerSideEncryptionByDefault = {
          SSEAlgorithm = "AES256"
        }
      }
    ]
  }
  versioning {
    // CF Property(Status) = "Enabled"
  }
  // CF Property(PublicAccessBlockConfiguration) = {
  //   BlockPublicAcls = true
  //   BlockPublicPolicy = true
  //   IgnorePublicAcls = true
  //   RestrictPublicBuckets = true
  // }
  acl = "private"
}

