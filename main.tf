resource "aws_iam_role" "role" {
  name = "mati-sagemaker-notebook-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "sagemaker_logs" {
  name              = "/aws/sagemaker/NotebookInstances/mati-playground"
  retention_in_days = 14
}

# Output the bucket name for reference
output "s3_bucket_name" {
  value       = aws_s3_bucket.model_bucket.bucket
  description = "Name of the S3 bucket for storing InfiniteTalk models"
}

# CloudWatch Logs permissions
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "sagemaker-cloudwatch-logs"
  role = aws_iam_role.role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.sagemaker_logs.arn}:*"
      }
    ]
  })
}

# Basic SageMaker execution policy (required)
resource "aws_iam_role_policy_attachment" "sagemaker_execution" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Specific S3 bucket access (more secure)
resource "aws_iam_role_policy" "s3_bucket_access" {
  name = "sagemaker-s3-access"
  role = aws_iam_role.role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.model_bucket.arn}/*",
          aws_s3_bucket.model_bucket.arn
        ]
      }
    ]
  })
}

# ECR access for custom containers (optional)
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# S3 bucket for model storage
resource "aws_s3_bucket" "model_bucket" {
  bucket = "mati-infinitetalk-models-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "InfiniteTalk Models"
    Environment = "playground"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "model_bucket_versioning" {
  bucket = aws_s3_bucket.model_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "model_bucket_encryption" {
  bucket = aws_s3_bucket.model_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "model_bucket_pab" {
  bucket = aws_s3_bucket.model_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Your notebook instance
resource "aws_sagemaker_notebook_instance" "ni" {
  name          = "mati-playground"
  role_arn      = aws_iam_role.role.arn
  instance_type = "ml.g4dn.xlarge"

  volume_size = var.notebook_volume_size

  tags = {
    Name = "mati-playground"
  }
}

# Minimal custom policy if you want more restricted access
resource "aws_iam_role_policy" "sagemaker_custom" {
  name = "sagemaker-custom-policy"
  role = aws_iam_role.role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::your-model-bucket/*",
          "arn:aws:s3:::your-model-bucket"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:CreateModel",
          "sagemaker:CreateEndpoint",
          "sagemaker:CreateEndpointConfig",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:DescribeModel",
          "sagemaker:DescribeEndpoint",
          "sagemaker:InvokeEndpoint"
        ]
        Resource = "*"
      }
    ]
  })
}
