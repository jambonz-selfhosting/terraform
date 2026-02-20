# IAM roles and policies for jambonz large deployment on AWS

# ------------------------------------------------------------------------------
# EC2 IAM ROLE (shared across all instance types)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "jambonz_ec2" {
  name = "${var.name_prefix}-ec2-role"

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

  tags = {
    Name = "${var.name_prefix}-ec2-role"
  }
}

resource "aws_iam_role_policy" "jambonz_ec2" {
  name = "${var.name_prefix}-ec2-policy"
  role = aws_iam_role.jambonz_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeAddresses",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ConfirmSubscription"
        ]
        Resource = "arn:aws:sns:${var.region}:*:${var.name_prefix}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:RecordLifecycleActionHeartbeat",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:SetInstanceHealth"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.jwt.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jambonz" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.jambonz_ec2.name
}

# ------------------------------------------------------------------------------
# LIFECYCLE HOOK IAM ROLE (for ASG -> SNS)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "lifecycle_hook" {
  name = "${var.name_prefix}-lifecycle-hook-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-lifecycle-hook-role"
  }
}

resource "aws_iam_role_policy" "lifecycle_hook" {
  name = "${var.name_prefix}-lifecycle-hook-policy"
  role = aws_iam_role.lifecycle_hook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:aws:sns:${var.region}:*:${var.name_prefix}-*"
      }
    ]
  })
}
