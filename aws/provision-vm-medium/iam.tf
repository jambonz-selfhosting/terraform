# IAM roles and policies for jambonz medium deployment on AWS

# ------------------------------------------------------------------------------
# EC2 IAM ROLE (shared by all jambonz instances)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "jambonz_ec2" {
  name = "${var.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
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
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAddresses",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
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
          "sns:Publish",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ConfirmSubscription"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
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
# LIFECYCLE HOOK IAM ROLE (for ASG -> SNS notifications)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "lifecycle_hook" {
  name = "${var.name_prefix}-lifecycle-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "autoscaling.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lifecycle_hook_sns" {
  name = "${var.name_prefix}-lifecycle-sns"
  role = aws_iam_role.lifecycle_hook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = [aws_sns_topic.sbc_lifecycle.arn, aws_sns_topic.fs_lifecycle.arn]
    }]
  })
}
