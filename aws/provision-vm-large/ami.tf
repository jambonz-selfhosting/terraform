# AMI management for jambonz large deployment on AWS
# Source AMIs are published by jambonz; aws_ami_copy creates private copies
# in the user's account so deployments are independent of the source AMIs.

locals {
  source_amis = {
    "us-east-1" = {
      sbc_sip    = "ami-0930531edc61b0b40"
      sbc_rtp    = "ami-02f3277e0d083bbb2"
      feature_server = "ami-026bbb6093f4a350c"
      web        = "ami-02b34cf3bd4060278"
      monitoring = "ami-0dc803e8854450793"
      recording  = "ami-0ac4c06c1b7ec71d3"
    }
    "us-east-2" = {
      sbc_sip    = "ami-085450a072b0f7f00"
      sbc_rtp    = "ami-0e8c0acb386488b30"
      feature_server = "ami-0b49572437dabb0da"
      web        = "ami-0fcd6264c08fc020b"
      monitoring = "ami-06cfce7e740b492ee"
      recording  = "ami-0560fcacf310c9a94"
    }
    "us-west-1" = {
      sbc_sip    = "ami-0bd42e728d024f939"
      sbc_rtp    = "ami-0654e9a8b330a39b7"
      feature_server = "ami-0d978fbd0a569eb85"
      web        = "ami-03f1a84084f76becd"
      monitoring = "ami-0d76319ffaec95fb1"
      recording  = "ami-0f009a1d6d709beb7"
    }
    "us-west-2" = {
      sbc_sip    = "ami-04c008ff9b921d644"
      sbc_rtp    = "ami-01c61619c14de2246"
      feature_server = "ami-0f911ac488f163b45"
      web        = "ami-0d2c62f835cb9c73c"
      monitoring = "ami-08e8a9f49ca6e0110"
      recording  = "ami-0427b24c893f4e662"
    }
    "ca-central-1" = {
      sbc_sip    = "ami-06096a1d1500132d4"
      sbc_rtp    = "ami-0a9386e3c9eea1093"
      feature_server = "ami-0b166d374fc437a2a"
      web        = "ami-08b5f56a6decd6f85"
      monitoring = "ami-09daf5e3e7001f1e6"
      recording  = "ami-04c985dc0df40f6e4"
    }
    "ca-west-1" = {
      sbc_sip    = "ami-0e63fd5978326bf56"
      sbc_rtp    = "ami-0208fb504717aae30"
      feature_server = "ami-0bc8cb70594296cf9"
      web        = "ami-025853e1b0f3f28af"
      monitoring = "ami-05d56ee5b7d638fc0"
      recording  = "ami-088d77e4df72c73fb"
    }
    "sa-east-1" = {
      sbc_sip    = "ami-0650c3ef18be211f4"
      sbc_rtp    = "ami-012f7067bf45f9f14"
      feature_server = "ami-054a63b92a5f140a0"
      web        = "ami-09dc8fa385e5e49a7"
      monitoring = "ami-01bf013f7a37a0613"
      recording  = "ami-0d930e19edc3fa007"
    }
    "mx-central-1" = {
      sbc_sip    = "ami-0be5aa0e9c7df0f28"
      sbc_rtp    = "ami-013a2c491db7123be"
      feature_server = "ami-02678d8098245292c"
      web        = "ami-0f3924ff22626da52"
      monitoring = "ami-04479942a99c1aa40"
      recording  = "ami-0f2f68c1a3dbb8a81"
    }
    "eu-central-1" = {
      sbc_sip    = "ami-06dc88d4c809221e2"
      sbc_rtp    = "ami-027547196a81eae82"
      feature_server = "ami-0e7f310a11787abe9"
      web        = "ami-069aa26950218c299"
      monitoring = "ami-0ddd1468547f84e93"
      recording  = "ami-037f0d9b5581e2d6c"
    }
    "eu-central-2" = {
      sbc_sip    = "ami-0ee69097da7d61bcd"
      sbc_rtp    = "ami-068e615835eb12b97"
      feature_server = "ami-08888dce74b7135e1"
      web        = "ami-065657e1f78c58743"
      monitoring = "ami-0db489f03d7dff4bb"
      recording  = "ami-09a1b356e1f2ffedd"
    }
    "eu-west-1" = {
      sbc_sip    = "ami-061fe966e90f9135b"
      sbc_rtp    = "ami-044a1c77294074262"
      feature_server = "ami-052819231253b4f9c"
      web        = "ami-04cdc380fff0c7623"
      monitoring = "ami-05418a4a369e869c3"
      recording  = "ami-0f0b0bfb0e04ea6a1"
    }
    "eu-west-2" = {
      sbc_sip    = "ami-011e6f53c2750ac8b"
      sbc_rtp    = "ami-0dd20dbef12985b20"
      feature_server = "ami-0c58218c4b8a41156"
      web        = "ami-015752d3448b48fa8"
      monitoring = "ami-01957a6cf33e3864e"
      recording  = "ami-0f5de315fc0ef3d2d"
    }
    "eu-west-3" = {
      sbc_sip    = "ami-00a461be1b8315cbe"
      sbc_rtp    = "ami-028d063e33826ecaa"
      feature_server = "ami-01c8ae17897a1da97"
      web        = "ami-07fb743b756462f8f"
      monitoring = "ami-0ecf4ba13ec5f4b51"
      recording  = "ami-0d01403ea64a486d2"
    }
    "eu-north-1" = {
      sbc_sip    = "ami-0a4847f5e49141c74"
      sbc_rtp    = "ami-01ddc90dbced32e3b"
      feature_server = "ami-02f28d116d8c786ce"
      web        = "ami-0336d695933d92141"
      monitoring = "ami-0be2255e53ccc6a36"
      recording  = "ami-0d8827db5aef11f55"
    }
    "eu-south-1" = {
      sbc_sip    = "ami-0690a0ab031952b49"
      sbc_rtp    = "ami-09f44cc409da180a4"
      feature_server = "ami-00ad9649406404798"
      web        = "ami-0a581f05f6e9f4337"
      monitoring = "ami-0a6f43ffaf35dcfba"
      recording  = "ami-0b111ee9d4a0acf72"
    }
    "eu-south-2" = {
      sbc_sip    = "ami-0f2b025fcc03f126c"
      sbc_rtp    = "ami-03655a182dc20f085"
      feature_server = "ami-09b232b0c6a60bb57"
      web        = "ami-0f074de003effc412"
      monitoring = "ami-030a93f84b7f31db6"
      recording  = "ami-0550788fbb103d743"
    }
    "ap-south-1" = {
      sbc_sip    = "ami-05993337fe099a713"
      sbc_rtp    = "ami-08074e8838bf8e53d"
      feature_server = "ami-009cccfa84a747a4b"
      web        = "ami-0265001e9e552cd5c"
      monitoring = "ami-0986fc083e200b8ef"
      recording  = "ami-09d68ab8118d431c7"
    }
    "ap-south-2" = {
      sbc_sip    = "ami-054891552dd051bb6"
      sbc_rtp    = "ami-085ed378c7d5957d9"
      feature_server = "ami-03bc2f5cb3e499059"
      web        = "ami-028184a3c4df6708f"
      monitoring = "ami-088adb687ce204f68"
      recording  = "ami-053b580170e9db752"
    }
    "ap-east-1" = {
      sbc_sip    = "ami-04db740b3970c00e4"
      sbc_rtp    = "ami-086ff2bc3980a2974"
      feature_server = "ami-055c640510b95fcb6"
      web        = "ami-020ca98b5f0aef1b7"
      monitoring = "ami-020079aa40e889413"
      recording  = "ami-09825475f269e8295"
    }
    "ap-east-2" = {
      sbc_sip    = "ami-03620a8d7ae4b9174"
      sbc_rtp    = "ami-05277d6f0592c9a30"
      feature_server = "ami-0a972a754bb4b0728"
      web        = "ami-02e6f6b2cf07d05ad"
      monitoring = "ami-07a67cd5eddd3bdce"
      recording  = "ami-0e43992a13bbb3511"
    }
    "ap-southeast-1" = {
      sbc_sip    = "ami-06cc991bf84dddc9f"
      sbc_rtp    = "ami-0e3efa949ecef15db"
      feature_server = "ami-0a472575e080ec062"
      web        = "ami-00d396cc6690c9411"
      monitoring = "ami-0ca56bb002ea4ea52"
      recording  = "ami-00ef8c9eb42639794"
    }
    "ap-southeast-2" = {
      sbc_sip    = "ami-010a5f7d134f73cf4"
      sbc_rtp    = "ami-0d7bd4a21994e60ed"
      feature_server = "ami-039de1906f8db0b93"
      web        = "ami-0430d3cb67b60ea83"
      monitoring = "ami-06c4956c5f5449d74"
      recording  = "ami-0600daaa0e9c9a949"
    }
    "ap-southeast-3" = {
      sbc_sip    = "ami-04edbc02977ba2cc5"
      sbc_rtp    = "ami-0a908bd37f4b62692"
      feature_server = "ami-00ad65ec833edfec5"
      web        = "ami-0f3395304d36c5a0c"
      monitoring = "ami-0e1d1d56ba114b028"
      recording  = "ami-0c06f453e65303250"
    }
    "ap-southeast-4" = {
      sbc_sip    = "ami-0bb49915cbd1365b5"
      sbc_rtp    = "ami-02dea2df43fdfb4e6"
      feature_server = "ami-0ec703b25da31d16c"
      web        = "ami-0859b1c7efb311e19"
      monitoring = "ami-0685c6b572c9405b8"
      recording  = "ami-0cc4f017e600f49a9"
    }
    "ap-southeast-5" = {
      sbc_sip    = "ami-0fa1f4e31079eb4d7"
      sbc_rtp    = "ami-00ff54e4f7701143c"
      feature_server = "ami-0b335477505b37daa"
      web        = "ami-00844606bec5e1510"
      monitoring = "ami-09f13944e17e2b86b"
      recording  = "ami-00bca08d8297f82e6"
    }
    "ap-southeast-6" = {
      sbc_sip    = "ami-0b8b2de23f089113d"
      sbc_rtp    = "ami-0f072f5160dc12dc1"
      feature_server = "ami-0034577a7be1d0b32"
      web        = "ami-08c9a55ddf85f40ff"
      monitoring = "ami-0d4877f8d82e632ff"
      recording  = "ami-009397839795fafee"
    }
    "ap-southeast-7" = {
      sbc_sip    = "ami-0738ae1ee50680cfa"
      sbc_rtp    = "ami-059d2b7b59ef6ed64"
      feature_server = "ami-091df392fe6377715"
      web        = "ami-035c2e0547c3602f7"
      monitoring = "ami-00515de0633c8746f"
      recording  = "ami-0b0d75904ea0c867e"
    }
    "ap-northeast-1" = {
      sbc_sip    = "ami-000856c6b911ea868"
      sbc_rtp    = "ami-0529d623e5a340370"
      feature_server = "ami-0f71b406fd577293f"
      web        = "ami-051b08a4635465110"
      monitoring = "ami-0da6d9a71d02d85f6"
      recording  = "ami-05ecd1b589d09f6ff"
    }
    "ap-northeast-2" = {
      sbc_sip    = "ami-080ca3ee4271f7f29"
      sbc_rtp    = "ami-0e8408115b7d3acde"
      feature_server = "ami-07a8156695afd5ac0"
      web        = "ami-085c6197946a45e19"
      monitoring = "ami-025f5166b64b30d1a"
      recording  = "ami-0a8361f7b732a43a3"
    }
    "ap-northeast-3" = {
      sbc_sip    = "ami-0ec741cfd979843d0"
      sbc_rtp    = "ami-00c2ac0e1e6f8b0f2"
      feature_server = "ami-0db5fc2dddef92f6f"
      web        = "ami-01c2cb02be0b45436"
      monitoring = "ami-0e1852b5a9d4b533c"
      recording  = "ami-0d23fb419c26947b1"
    }
    "me-central-1" = {
      sbc_sip    = "ami-09c1311afd0653d7b"
      sbc_rtp    = "ami-0399f99220dffa62e"
      feature_server = "ami-0ab0c5fe7cc4e3061"
      web        = "ami-09cd1780fca5de5c0"
      monitoring = "ami-0632d7feb8010b94d"
      recording  = "ami-0351716afb254bd18"
    }
    "me-south-1" = {
      sbc_sip    = "ami-0e337245e340037df"
      sbc_rtp    = "ami-010bf80184af6e884"
      feature_server = "ami-081ce49f89ac18554"
      web        = "ami-0886a7b4e46f8ff8a"
      monitoring = "ami-041f1a0f0ffa55484"
      recording  = "ami-0c4a113f28ff5adfe"
    }
    "il-central-1" = {
      sbc_sip    = "ami-0565a001e1a04d7df"
      sbc_rtp    = "ami-0a016bb00ef4687e4"
      feature_server = "ami-0ef52aa2cc9b1927e"
      web        = "ami-074e13f5166a45d7a"
      monitoring = "ami-0734d1e98899b2071"
      recording  = "ami-0c2887d5980509a06"
    }
    "af-south-1" = {
      sbc_sip    = "ami-0609b228d53c2972f"
      sbc_rtp    = "ami-0a055a71a91ae778c"
      feature_server = "ami-0ad6b374ded5b4127"
      web        = "ami-0c77e84040452a27d"
      monitoring = "ami-0e59cbc05d7bc5094"
      recording  = "ami-0921284d229929f7d"
    }
  }
}

resource "aws_ami_copy" "sbc_sip" {
  name              = "${var.name_prefix}-sbc-sip-ami"
  description       = "Local copy of jambonz SBC SIP AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]["sbc_sip"]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-sbc-sip-ami"
    Role = "sbc-sip"
  }
}

resource "aws_ami_copy" "sbc_rtp" {
  name              = "${var.name_prefix}-sbc-rtp-ami"
  description       = "Local copy of jambonz SBC RTP AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]["sbc_rtp"]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-sbc-rtp-ami"
    Role = "sbc-rtp"
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

resource "aws_ami_copy" "web" {
  name              = "${var.name_prefix}-web-ami"
  description       = "Local copy of jambonz Web AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]["web"]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-web-ami"
    Role = "web"
  }
}

resource "aws_ami_copy" "monitoring" {
  name              = "${var.name_prefix}-monitoring-ami"
  description       = "Local copy of jambonz Monitoring AMI for ${var.name_prefix}"
  source_ami_id     = local.source_amis[var.region]["monitoring"]
  source_ami_region = var.region

  tags = {
    Name = "${var.name_prefix}-monitoring-ami"
    Role = "monitoring"
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
