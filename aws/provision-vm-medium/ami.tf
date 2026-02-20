# AMI management for jambonz medium deployment on AWS
# Source AMIs are published by jambonz; aws_ami_copy creates private copies
# in the user's account so deployments are independent of the source AMIs.

locals {
  source_amis = {
    "us-east-1" = {
      sbc            = "ami-00895c98421dd03a6"
      feature_server = "ami-026bbb6093f4a350c"
      web_monitoring = "ami-0cde62122fb186d40"
      recording      = "ami-0ac4c06c1b7ec71d3"
    }
    "us-east-2" = {
      sbc            = "ami-04d0fe6eb848b7e17"
      feature_server = "ami-0b49572437dabb0da"
      web_monitoring = "ami-0c63c5bbed5079af2"
      recording      = "ami-0560fcacf310c9a94"
    }
    "us-west-1" = {
      sbc            = "ami-05440cf7cb55367e4"
      feature_server = "ami-0d978fbd0a569eb85"
      web_monitoring = "ami-0b6bc617bba56e22f"
      recording      = "ami-0f009a1d6d709beb7"
    }
    "us-west-2" = {
      sbc            = "ami-08d75c62c852bbe9f"
      feature_server = "ami-0f911ac488f163b45"
      web_monitoring = "ami-04915e08b30710865"
      recording      = "ami-0427b24c893f4e662"
    }
    "ca-central-1" = {
      sbc            = "ami-087195bd7775575ed"
      feature_server = "ami-0b166d374fc437a2a"
      web_monitoring = "ami-07c0adfa6cf3f82a5"
      recording      = "ami-04c985dc0df40f6e4"
    }
    "ca-west-1" = {
      sbc            = "ami-0b833e6104af0b0d1"
      feature_server = "ami-0bc8cb70594296cf9"
      web_monitoring = "ami-07ca0e6bca78e1252"
      recording      = "ami-088d77e4df72c73fb"
    }
    "sa-east-1" = {
      sbc            = "ami-09426cec03e07fe55"
      feature_server = "ami-054a63b92a5f140a0"
      web_monitoring = "ami-08740f864cb6545f4"
      recording      = "ami-0d930e19edc3fa007"
    }
    "mx-central-1" = {
      sbc            = "ami-0ce3ab93c7b15ce10"
      feature_server = "ami-02678d8098245292c"
      web_monitoring = "ami-08f166d2f9c4f7728"
      recording      = "ami-0f2f68c1a3dbb8a81"
    }
    "eu-central-1" = {
      sbc            = "ami-0c909b771f5e17f44"
      feature_server = "ami-0e7f310a11787abe9"
      web_monitoring = "ami-06b001e70bc145632"
      recording      = "ami-037f0d9b5581e2d6c"
    }
    "eu-central-2" = {
      sbc            = "ami-032d0de6e8705f480"
      feature_server = "ami-08888dce74b7135e1"
      web_monitoring = "ami-0db4d7ef6bce84069"
      recording      = "ami-09a1b356e1f2ffedd"
    }
    "eu-west-1" = {
      sbc            = "ami-05811ba62df7a6ede"
      feature_server = "ami-052819231253b4f9c"
      web_monitoring = "ami-0ce1c2ec290896431"
      recording      = "ami-0f0b0bfb0e04ea6a1"
    }
    "eu-west-2" = {
      sbc            = "ami-02fd921f2a4bfe636"
      feature_server = "ami-0c58218c4b8a41156"
      web_monitoring = "ami-0c2e4acd8aabf53c6"
      recording      = "ami-0f5de315fc0ef3d2d"
    }
    "eu-west-3" = {
      sbc            = "ami-0ce892150dadbc910"
      feature_server = "ami-01c8ae17897a1da97"
      web_monitoring = "ami-079ccc0b542e61023"
      recording      = "ami-0d01403ea64a486d2"
    }
    "eu-north-1" = {
      sbc            = "ami-0505b9626fbd65860"
      feature_server = "ami-02f28d116d8c786ce"
      web_monitoring = "ami-019344d70db55290e"
      recording      = "ami-0d8827db5aef11f55"
    }
    "eu-south-1" = {
      sbc            = "ami-040388ec9d2fab0f7"
      feature_server = "ami-00ad9649406404798"
      web_monitoring = "ami-0f90e9b728c8d82ea"
      recording      = "ami-0b111ee9d4a0acf72"
    }
    "eu-south-2" = {
      sbc            = "ami-0399cd02cb42b6486"
      feature_server = "ami-09b232b0c6a60bb57"
      web_monitoring = "ami-0bc9f25b96a1bfcd0"
      recording      = "ami-0550788fbb103d743"
    }
    "ap-south-1" = {
      sbc            = "ami-080ec2c6fda6a3542"
      feature_server = "ami-009cccfa84a747a4b"
      web_monitoring = "ami-0ea38a1907ad1b1eb"
      recording      = "ami-09d68ab8118d431c7"
    }
    "ap-south-2" = {
      sbc            = "ami-0c936ef3d10a6f7d5"
      feature_server = "ami-03bc2f5cb3e499059"
      web_monitoring = "ami-0c42be36a0af3ca87"
      recording      = "ami-053b580170e9db752"
    }
    "ap-east-1" = {
      sbc            = "ami-09fb7ef1048fe1550"
      feature_server = "ami-055c640510b95fcb6"
      web_monitoring = "ami-036f0ff7299ce985c"
      recording      = "ami-09825475f269e8295"
    }
    "ap-east-2" = {
      sbc            = "ami-079d9a3c9ca9ba3a5"
      feature_server = "ami-0a972a754bb4b0728"
      web_monitoring = "ami-068adc1027b27a9ed"
      recording      = "ami-0e43992a13bbb3511"
    }
    "ap-southeast-1" = {
      sbc            = "ami-0d6dd3d27cce10692"
      feature_server = "ami-0a472575e080ec062"
      web_monitoring = "ami-04ee57afa0a55d47e"
      recording      = "ami-00ef8c9eb42639794"
    }
    "ap-southeast-2" = {
      sbc            = "ami-07a2172e18b8e3739"
      feature_server = "ami-039de1906f8db0b93"
      web_monitoring = "ami-0f170b00e1b21fa68"
      recording      = "ami-0600daaa0e9c9a949"
    }
    "ap-southeast-3" = {
      sbc            = "ami-0d058b27b9561cb27"
      feature_server = "ami-00ad65ec833edfec5"
      web_monitoring = "ami-0c6e61b268d9fbb49"
      recording      = "ami-0c06f453e65303250"
    }
    "ap-southeast-4" = {
      sbc            = "ami-04e962adda9567db5"
      feature_server = "ami-0ec703b25da31d16c"
      web_monitoring = "ami-0a850260cf9b1ae8b"
      recording      = "ami-0cc4f017e600f49a9"
    }
    "ap-southeast-5" = {
      sbc            = "ami-0f936c7cf1e5ced71"
      feature_server = "ami-0b335477505b37daa"
      web_monitoring = "ami-08f11de17f2874f3b"
      recording      = "ami-00bca08d8297f82e6"
    }
    "ap-southeast-6" = {
      sbc            = "ami-028dfcf48ce17571b"
      feature_server = "ami-0034577a7be1d0b32"
      web_monitoring = "ami-0b0341862b089065d"
      recording      = "ami-009397839795fafee"
    }
    "ap-southeast-7" = {
      sbc            = "ami-0e7df3a29d6a1b922"
      feature_server = "ami-091df392fe6377715"
      web_monitoring = "ami-010619ca2ea8bdfb7"
      recording      = "ami-0b0d75904ea0c867e"
    }
    "ap-northeast-1" = {
      sbc            = "ami-075792c747066b8b1"
      feature_server = "ami-0f71b406fd577293f"
      web_monitoring = "ami-0de67012e24a70254"
      recording      = "ami-05ecd1b589d09f6ff"
    }
    "ap-northeast-2" = {
      sbc            = "ami-06d6737741be7c312"
      feature_server = "ami-07a8156695afd5ac0"
      web_monitoring = "ami-08ffe43bc58005d15"
      recording      = "ami-0a8361f7b732a43a3"
    }
    "ap-northeast-3" = {
      sbc            = "ami-0599e03ca81e18881"
      feature_server = "ami-0db5fc2dddef92f6f"
      web_monitoring = "ami-0f4c4fb8316b11ee8"
      recording      = "ami-0d23fb419c26947b1"
    }
    "me-central-1" = {
      sbc            = "ami-03623f1e0e3e7e065"
      feature_server = "ami-0ab0c5fe7cc4e3061"
      web_monitoring = "ami-0d0cf67f31e6b5980"
      recording      = "ami-0351716afb254bd18"
    }
    "me-south-1" = {
      sbc            = "ami-0449c1b62721d1ff8"
      feature_server = "ami-081ce49f89ac18554"
      web_monitoring = "ami-0a846c5e22124eef4"
      recording      = "ami-0c4a113f28ff5adfe"
    }
    "il-central-1" = {
      sbc            = "ami-03b1dfbed37897b52"
      feature_server = "ami-0ef52aa2cc9b1927e"
      web_monitoring = "ami-0323bbeac3632cf0b"
      recording      = "ami-0c2887d5980509a06"
    }
    "af-south-1" = {
      sbc            = "ami-0887ee14a083817d0"
      feature_server = "ami-0ad6b374ded5b4127"
      web_monitoring = "ami-03186c423b54f0e55"
      recording      = "ami-0921284d229929f7d"
    }
  }
}

resource "aws_ami_copy" "sbc" {
  name              = "${var.name_prefix}-sbc-ami"
  description       = "Local copy of jambonz SBC AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]["sbc"]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-sbc-ami"
    Role = "sbc"
  }
}

resource "aws_ami_copy" "feature_server" {
  name              = "${var.name_prefix}-feature-server-ami"
  description       = "Local copy of jambonz Feature Server AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]["feature_server"]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-feature-server-ami"
    Role = "feature-server"
  }
}

resource "aws_ami_copy" "web_monitoring" {
  name              = "${var.name_prefix}-web-monitoring-ami"
  description       = "Local copy of jambonz Web/Monitoring AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]["web_monitoring"]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-web-monitoring-ami"
    Role = "web-monitoring"
  }
}

resource "aws_ami_copy" "recording" {
  count             = var.deploy_recording_cluster ? 1 : 0
  name              = "${var.name_prefix}-recording-ami"
  description       = "Local copy of jambonz Recording AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]["recording"]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-recording-ami"
    Role = "recording"
  }
}
