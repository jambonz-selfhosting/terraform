# AMI management for jambonz mini deployment on AWS
# Source AMIs are published by jambonz; aws_ami_copy creates a private copy
# in the user's account so deployments are independent of the source AMIs.

locals {
  source_amis = {
    "us-east-1"      = "ami-082ce3e6383c774ec"
    "us-east-2"      = "ami-0f761364873aa32c6"
    "us-west-1"      = "ami-009899a2fd2589a68"
    "us-west-2"      = "ami-05324c54318244399"
    "ca-central-1"   = "ami-05119df780258ab09"
    "ca-west-1"      = "ami-056085f7b85928f2f"
    "sa-east-1"      = "ami-000b25f6f15306234"
    "mx-central-1"   = "ami-01871799c24ba6f81"
    "eu-central-1"   = "ami-0ffbbf262a2875ae0"
    "eu-central-2"   = "ami-0478a108ffb6883bc"
    "eu-west-1"      = "ami-03183991ec614123a"
    "eu-west-2"      = "ami-04e7f8c8e6d422913"
    "eu-west-3"      = "ami-091bf85d0b5ceddde"
    "eu-north-1"     = "ami-08a0975cdcfff07df"
    "eu-south-1"     = "ami-07c5fd205eaea1fda"
    "eu-south-2"     = "ami-0630c1668f80fe8dd"
    "ap-south-1"     = "ami-060d3e7777286dda1"
    "ap-south-2"     = "ami-0e27c57db4b758ea9"
    "ap-east-1"      = "ami-051cdb7a2b24bd2a8"
    "ap-east-2"      = "ami-0cb6e7ee6daa23226"
    "ap-southeast-1" = "ami-09d907e1e225d7a49"
    "ap-southeast-2" = "ami-01364e21ba696b75e"
    "ap-southeast-3" = "ami-0cf9ba9793fab3c82"
    "ap-southeast-4" = "ami-0464d4d7d12b7a5eb"
    "ap-southeast-5" = "ami-0289cff603df0cae6"
    "ap-southeast-6" = "ami-010fae831eb26995c"
    "ap-southeast-7" = "ami-0e97dd0a14b90c8bd"
    "ap-northeast-1" = "ami-0468eaf03fcbf8970"
    "ap-northeast-2" = "ami-0e44b4c132d1ffaab"
    "ap-northeast-3" = "ami-0160fc4d8df458e90"
    "me-central-1"   = "ami-0820d46f71bc0f68e"
    "me-south-1"     = "ami-0248c5f5349b00336"
    "il-central-1"   = "ami-00ed4a9c0e8bdb8bc"
    "af-south-1"     = "ami-0a45824360824e722"
  }
}

resource "aws_ami_copy" "mini" {
  name              = "${var.name_prefix}-mini-ami"
  description       = "Local copy of jambonz mini AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-mini-ami"
    Role = "mini"
  }
}
