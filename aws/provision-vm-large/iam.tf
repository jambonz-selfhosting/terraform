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
        # DescribeAutoScalingInstances + DescribeLifecycleHooks: the scale-in drain finds its ASG and hook at startup
        Effect = "Allow"
        Action = [
          "autoscaling:RecordLifecycleActionHeartbeat",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLifecycleHooks",
          "autoscaling:SetInstanceHealth"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:CompleteLifecycleAction"]
        Resource = "arn:aws:autoscaling:${var.region}:*:autoScalingGroup:*:autoScalingGroupName/${local.fs_asg_name}"
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
