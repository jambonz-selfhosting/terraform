# Compute resources for jambonz mini (single VM) on AWS
# All-in-one deployment with local MySQL, Redis, and monitoring

# ------------------------------------------------------------------------------
# MINI SERVER (ALL-IN-ONE)
# ------------------------------------------------------------------------------

resource "aws_instance" "mini" {
  ami                    = aws_ami_copy.mini.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.jambonz.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.mini.id]
  iam_instance_profile   = aws_iam_instance_profile.mini.name

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/cloud-init-mini.sh", {
    db_password          = random_password.db_password.result
    jwt_secret           = random_password.jwt_secret.result
    url_portal           = var.url_portal
    apiban_key           = var.apiban_key
    apiban_client_id     = var.apiban_client_id
    apiban_client_secret = var.apiban_client_secret
  })

  tags = {
    Name = "${var.name_prefix}-mini"
    Role = "mini"
  }

  depends_on = [aws_ami_copy.mini]
}

# ------------------------------------------------------------------------------
# EIP ASSOCIATION
# ------------------------------------------------------------------------------

resource "aws_eip_association" "mini" {
  instance_id   = aws_instance.mini.id
  allocation_id = aws_eip.mini.id
}
