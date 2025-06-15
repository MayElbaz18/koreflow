provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

# Data source to retrieve an existing Security Group by its ID
data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-id"
    values = [var.security_group_id]
  }
}

resource "aws_instance" "demo_environment" {
  count         = var.demo_environment_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.demo_environment_type
  key_name      = var.key_name
  vpc_security_group_ids = [data.aws_security_group.existing_sg.id]

  tags = {
    Name  = "${var.cluster_name}-demo-environment-${count.index}"
    Role  = "demo-environment"
    group = "postomatic"
  }

  root_block_device {
    volume_size = 10
  }
}