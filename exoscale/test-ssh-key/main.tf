locals {
  # Read SSH public key from local file
  ssh_public_key = file("~/.ssh/id_rsa.pub")
}

resource "exoscale_security_group" "test_ssh" {
  name = "test-ssh"
}

resource "exoscale_security_group_rule" "test_ssh" {
  security_group_id = exoscale_security_group.test_ssh.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 22
  end_port          = 22
  cidr              = "0.0.0.0/0"
}

resource "exoscale_compute_instance" "test" {
  zone        = "ch-gva-2"
  name        = "ssh-test"
  type        = "standard.micro"
  disk_size   = 10
  template_id        = "ca545369-0707-4a5f-b0a7-0dd8a2147f2b" # Debian 12 official template
  ssh_keys           = ["daveh-ssh-key"]                       # This adds key to debian user
  security_group_ids = [exoscale_security_group.test_ssh.id]

  user_data = templatefile("${path.module}/cloud-init-test.yaml", {
    ssh_public_key = local.ssh_public_key
  })

  labels = {
    purpose = "ssh-test"
  }
}

output "instance_ip" {
  value = exoscale_compute_instance.test.public_ip_address
}

output "ssh_command" {
  value = "ssh jambonz@${exoscale_compute_instance.test.public_ip_address}"
}
