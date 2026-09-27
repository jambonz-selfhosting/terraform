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
        Effect = "Allow"
        Action = ["autoscaling:CompleteLifecycleAction"]
        Resource = [
          "arn:aws:autoscaling:${var.region}:*:autoScalingGroup:*:autoScalingGroupName/${local.sbc_asg_name}",
          "arn:aws:autoscaling:${var.region}:*:autoScalingGroup:*:autoScalingGroupName/${local.fs_asg_name}"
        ]
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
