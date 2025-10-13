# ============================================================================
# IAM Module
# Creates: IAM role and instance profile for SSM access
# ============================================================================

# IAM Role for Windows instances
resource "aws_iam_role" "windows_ssm_role" {
  name_prefix = "${var.project_name}-windows-ssm-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-windows-ssm-role"
    }
  )
}

# Attach AWS managed SSM policy
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.windows_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "windows_ssm_profile" {
  name_prefix = "${var.project_name}-windows-ssm-"
  role        = aws_iam_role.windows_ssm_role.name

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-windows-ssm-profile"
    }
  )
}
