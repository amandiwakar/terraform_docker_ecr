provider "aws" {
  version = "~> 2.0"
  region  = "us-west-2"
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
  }

  resource "aws_instance" "web" {
    ami           = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"
    count = 1
    key_name = "docker-ec2"
    tags = {
      Name = "HappyDay-${count.index+1}"
    }
  }

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}


  resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = "sg-2c47847f"
  network_interface_id = aws_instance.web[0].primary_network_interface_id
  }


  resource "aws_security_group_rule" "allow_tls" {
      description = "Permit ALL from home"
      type = "ingress"
      from_port   = 0
      to_port     = 0
      protocol    = -1
      cidr_blocks = ["67.161.66.130/32"]
      security_group_id = "sg-2c47847f"
  }

  module "dev_ssh_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["67.161.66.130/32"]
  ingress_rules       = ["ssh-tcp"]
}

  resource "aws_ecr_repository" "ecr-repo" {
    name                 = "ecr-repo"
    image_tag_mutability = "MUTABLE"

    tags = {
      project = "ecr-repo"
    }
  }

  resource "aws_iam_role" "ec2_role_ecr_repo" {
    name = "ec2_role_ecr_repo"

    assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  }
  EOF

    tags = {
      project = "ecr_repo"
    }
  }

  resource "aws_iam_instance_profile" "ec2_profile_ecr_repo" {
    name = "ec2_profile_ecr_repo"
    role = aws_iam_role.ec2_role_ecr_repo.name
  }

  resource "aws_iam_role_policy" "ec2_policy" {
    name = "ec2_policy"
    role = aws_iam_role.ec2_role_ecr_repo.id

    policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
  }
