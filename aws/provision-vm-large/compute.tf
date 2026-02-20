# Compute resources for jambonz large deployment on AWS
# Fully separated: SIP, RTP as count-based instances; Feature Server ASG; Web + Monitoring as individual EC2s

# ------------------------------------------------------------------------------
# SNS TOPIC (for Feature Server ASG lifecycle events)
# ------------------------------------------------------------------------------

resource "aws_sns_topic" "fs_lifecycle" {
  name = "${var.name_prefix}-fs-lifecycle"
}

# ------------------------------------------------------------------------------
# ELASTIC IPS
# ------------------------------------------------------------------------------

resource "aws_eip" "web" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-web-eip"
  }
}

resource "aws_eip" "monitoring" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-monitoring-eip"
  }
}

resource "aws_eip" "sip" {
  count  = var.sip_count
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-sip-eip-${count.index + 1}"
  }
}

resource "aws_eip" "rtp" {
  count  = var.rtp_count
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-rtp-eip-${count.index + 1}"
  }
}

# ------------------------------------------------------------------------------
# MONITORING SERVER (must be created before Web and SIP so they can reference its IP)
# ------------------------------------------------------------------------------

resource "aws_instance" "monitoring" {
  ami                    = aws_ami_copy.monitoring.id
  instance_type          = var.monitoring_instance_type
  key_name               = aws_key_pair.jambonz.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.jambonz.name

  root_block_device {
    volume_size = var.monitoring_disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/cloud-init-monitoring.sh", {
    url_portal = var.url_portal
    vpc_cidr   = var.vpc_cidr
  })

  tags = {
    Name = "${var.name_prefix}-monitoring"
    Role = "monitoring"
  }
}

resource "aws_eip_association" "monitoring" {
  instance_id   = aws_instance.monitoring.id
  allocation_id = aws_eip.monitoring.id
}

# ------------------------------------------------------------------------------
# WEB SERVER
# ------------------------------------------------------------------------------

resource "aws_instance" "web" {
  ami                    = aws_ami_copy.web.id
  instance_type          = var.web_instance_type
  key_name               = aws_key_pair.jambonz.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.jambonz.name

  root_block_device {
    volume_size = var.web_disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/cloud-init-web.sh", {
    mysql_host               = aws_rds_cluster.jambonz.endpoint
    mysql_user               = var.mysql_username
    mysql_password           = local.db_password
    redis_host               = aws_elasticache_replication_group.jambonz.primary_endpoint_address
    redis_port               = 6379
    jwt_secret               = random_password.jwt_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    monitoring_private_ip    = aws_instance.monitoring.private_ip
    deploy_recording_cluster = var.deploy_recording_cluster
  })

  tags = {
    Name = "${var.name_prefix}-web"
    Role = "web"
  }

  depends_on = [
    aws_rds_cluster_instance.jambonz,
    aws_elasticache_replication_group.jambonz,
    aws_instance.monitoring
  ]
}

resource "aws_eip_association" "web" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web.id
}

# ------------------------------------------------------------------------------
# RTP SERVER INSTANCES (count-based, must be created before SIP)
# ------------------------------------------------------------------------------

resource "aws_instance" "rtp" {
  count                  = var.rtp_count
  ami                    = aws_ami_copy.sbc_rtp.id
  instance_type          = var.rtp_instance_type
  key_name               = aws_key_pair.jambonz.key_name
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.sbc_rtp.id]
  iam_instance_profile   = aws_iam_instance_profile.jambonz.name

  root_block_device {
    volume_size = var.rtp_disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/cloud-init-rtp.sh", {
    monitoring_private_ip = aws_instance.monitoring.private_ip
    vpc_cidr              = var.vpc_cidr
    enable_pcaps          = var.enable_pcaps
    redis_host            = aws_elasticache_replication_group.jambonz.primary_endpoint_address
    redis_port            = 6379
  })

  tags = {
    Name = "${var.name_prefix}-rtp-${count.index + 1}"
    Role = "rtp"
  }

  depends_on = [aws_instance.monitoring]
}

resource "aws_eip_association" "rtp" {
  count         = var.rtp_count
  instance_id   = aws_instance.rtp[count.index].id
  allocation_id = aws_eip.rtp[count.index].id
}

# ------------------------------------------------------------------------------
# SIP SERVER INSTANCES (count-based, receives RTP private IPs)
# ------------------------------------------------------------------------------

resource "aws_instance" "sip" {
  count                  = var.sip_count
  ami                    = aws_ami_copy.sbc_sip.id
  instance_type          = var.sip_instance_type
  key_name               = aws_key_pair.jambonz.key_name
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.sbc_sip.id]
  iam_instance_profile   = aws_iam_instance_profile.jambonz.name

  root_block_device {
    volume_size = var.sip_disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/cloud-init-sip.sh", {
    mysql_host            = aws_rds_cluster.jambonz.endpoint
    mysql_write_host      = aws_rds_cluster.jambonz.endpoint
    mysql_read_host       = aws_rds_cluster.jambonz.reader_endpoint
    mysql_user            = var.mysql_username
    mysql_password        = local.db_password
    redis_host            = aws_elasticache_replication_group.jambonz.primary_endpoint_address
    redis_port            = 6379
    jwt_secret            = random_password.jwt_secret.result
    monitoring_private_ip = aws_instance.monitoring.private_ip
    vpc_cidr              = var.vpc_cidr
    enable_pcaps          = var.enable_pcaps
    apiban_key            = var.apiban_key
    apiban_client_id      = var.apiban_client_id
    apiban_client_secret  = var.apiban_client_secret
    rtp_private_ips       = join(",", aws_instance.rtp[*].private_ip)
  })

  tags = {
    Name = "${var.name_prefix}-sip-${count.index + 1}"
    Role = "sip"
  }

  depends_on = [
    aws_instance.monitoring,
    aws_instance.rtp
  ]
}

resource "aws_eip_association" "sip" {
  count         = var.sip_count
  instance_id   = aws_instance.sip[count.index].id
  allocation_id = aws_eip.sip[count.index].id
}

# ------------------------------------------------------------------------------
# FEATURE SERVER AUTO SCALING GROUP
# ------------------------------------------------------------------------------

resource "aws_launch_template" "feature_server" {
  name_prefix   = "${var.name_prefix}-fs-"
  image_id      = aws_ami_copy.feature_server.id
  instance_type = var.feature_server_instance_type
  key_name      = aws_key_pair.jambonz.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.jambonz.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ssh.id, aws_security_group.feature_server.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.feature_server_disk_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/cloud-init-feature-server.sh", {
    mysql_host            = aws_rds_cluster.jambonz.endpoint
    mysql_user            = var.mysql_username
    mysql_password        = local.db_password
    redis_host            = aws_elasticache_replication_group.jambonz.primary_endpoint_address
    redis_port            = 6379
    jwt_secret            = random_password.jwt_secret.result
    monitoring_private_ip = aws_instance.monitoring.private_ip
    web_private_ip        = aws_instance.web.private_ip
    vpc_cidr              = var.vpc_cidr
    url_portal            = var.url_portal
    recording_ws_base_url = var.deploy_recording_cluster ? "ws://${aws_lb.recording[0].dns_name}:80" : "ws://${aws_instance.web.private_ip}:3017"
    sns_topic_arn         = aws_sns_topic.fs_lifecycle.arn
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name_prefix}-feature-server"
      Role = "feature-server"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "feature_server" {
  name                = "${var.name_prefix}-fs-asg"
  min_size            = var.feature_server_min_size
  max_size            = var.feature_server_max_size
  desired_capacity    = var.feature_server_desired_capacity
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.feature_server.id
    version = "$Latest"
  }

  termination_policies = ["OldestInstance"]

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-feature-server"
    propagate_at_launch = true
  }

  depends_on = [aws_instance.web, aws_instance.monitoring]
}

resource "aws_autoscaling_lifecycle_hook" "fs_terminating" {
  name                    = "${var.name_prefix}-fs-terminating"
  autoscaling_group_name  = aws_autoscaling_group.feature_server.name
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout       = 900
  default_result          = "CONTINUE"
  notification_target_arn = aws_sns_topic.fs_lifecycle.arn
  role_arn                = aws_iam_role.lifecycle_hook.arn
}

# ------------------------------------------------------------------------------
# RECORDING CLUSTER (conditional)
# ------------------------------------------------------------------------------

# Application Load Balancer
resource "aws_lb" "recording" {
  count              = var.deploy_recording_cluster ? 1 : 0
  name               = "${var.name_prefix}-recording-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.recording_alb[0].id]
  subnets            = aws_subnet.public[*].id

  idle_timeout = 4000

  tags = {
    Name = "${var.name_prefix}-recording-alb"
  }
}

resource "aws_lb_target_group" "recording" {
  count    = var.deploy_recording_cluster ? 1 : 0
  name     = "${var.name_prefix}-recording-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.jambonz.id

  health_check {
    protocol = "HTTP"
    port     = "3000"
    path     = "/health"
  }

  tags = {
    Name = "${var.name_prefix}-recording-tg"
  }
}

resource "aws_lb_listener" "recording" {
  count             = var.deploy_recording_cluster ? 1 : 0
  load_balancer_arn = aws_lb.recording[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.recording[0].arn
  }
}

# Recording Launch Template
resource "aws_launch_template" "recording" {
  count         = var.deploy_recording_cluster ? 1 : 0
  name_prefix   = "${var.name_prefix}-recording-"
  image_id      = aws_ami_copy.recording[0].id
  instance_type = var.recording_instance_type
  key_name      = aws_key_pair.jambonz.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.jambonz.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ssh.id, aws_security_group.recording[0].id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.recording_disk_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/cloud-init-recording.sh", {
    mysql_host            = aws_rds_cluster.jambonz.endpoint
    mysql_user            = var.mysql_username
    mysql_password        = local.db_password
    jwt_secret            = random_password.jwt_secret.result
    monitoring_private_ip = aws_instance.monitoring.private_ip
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name_prefix}-recording"
      Role = "recording"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Recording ASG
resource "aws_autoscaling_group" "recording" {
  count               = var.deploy_recording_cluster ? 1 : 0
  name                = "${var.name_prefix}-recording-asg"
  min_size            = var.recording_min_size
  max_size            = var.recording_max_size
  desired_capacity    = var.recording_desired_capacity
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.recording[0].arn]

  launch_template {
    id      = aws_launch_template.recording[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-recording"
    propagate_at_launch = true
  }
}
