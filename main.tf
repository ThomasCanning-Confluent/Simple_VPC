provider "aws" {
  region = "eu-west-2"
}

variable "owner" {
  type        = string
  default     = "Thomas Canning"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "Bucket VPC"
    Owner = var.owner
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
    tags = {
        Name = "Bucket IGW"
        Owner = var.owner
    }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name  = "Bucket Public Subnet ${count.index}"
    Owner = var.owner
  }
}

resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
    tags = {
        Name  = "Bucket Private Subnet ${count.index}"
        Owner = var.owner
    }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

    tags = {
        Name  = "Bucket Public Route Table"
        Owner = var.owner
    }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id

    tags = {
        Name  = "Bucket Public Route Table Association ${count.index}"
        Owner = var.owner
    }
}

resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22 #This specifies SSH as part of the security group
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

    tags = {
        Name  = "Bucket Public Security Group"
        Owner = var.owner
    }
}

resource "aws_instance" "public_instances" {
  count         = 1
  ami           = "ami-0c36451c41e1eefd2"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  #key_name relates to the key pair that was created in the AWS console
  #It is needed for SSH access to the instance
  key_name      = "tcanning-keypair"

  #This adds an EBS volume to the instance
  #An EBS volume is a network drive that can be attached to an instance
  #Data persists after the instance is terminated
  #Useful for workloads that require a database, file system, or raw block storage
  root_block_device {
    #gp2 is a general purpose SSD
    #Alternatives include io1, st1 and sc1
    volume_type           = "gp2"
    #Vol size is in gb
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

    tags = {
        Name  = "Bucket Public Instance ${count.index}"
        Owner = var.owner
    }
}

#This creates an S3 bucket
#A bucket is a container for objects stored in S3
#Useful for storing and retrieving large amounts of data
resource "aws_s3_bucket" "my_bucket" {
  bucket = "bucket-tcanning"
}