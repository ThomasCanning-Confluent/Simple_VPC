provider "aws" {
  region = "eu-west-2"
}

variable "owner" {
  type    = string
  default = "Thomas Canning"
}

variable "name" {
  description = "The name of the resources"
  type        = string
  default     = "Simple VPC"
}

#A VPC module is used to create a VPC with public and private subnets
#You pass in the name of the VPC, the CIDR block, the availability zones, the private and public subnets, and the tags
#The module then creates other resources such as the route tables
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name = var.name
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
  single_nat_gateway = true

  tags = {
    Owner = var.owner
    Name  = var.name
  }
}

#This module creates a security group for the public instances
#You pass in pararmeters such as the ingress and egress rules
module "public_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  name        = "${var.name}-public-sg"
  description = "Security group for public instances"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["66.159.216.54/32", "2001:4860:7:633::fe/128"]
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = {
    Owner = var.owner
    Name  = "${var.name}-public-sg"
  }
}

#This module creates the public instances (ec2 instances accessible from the internet)
#Pass in parameters such as AMI and instance type
module "public_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.4.0"

  name           = "${var.name}-public-instance"
  instance_count = 3

  ami           = "ami-0c36451c41e1eefd2"
  instance_type = "t2.micro"
  subnet_id     = element(module.vpc.public_subnets, count.index)
  vpc_security_group_ids = [module.public_security_group.security_group_id]

  tags = {
    Owner = var.owner
    Name  = "${var.name}-public-instance-${count.index + 1}"
  }
}
