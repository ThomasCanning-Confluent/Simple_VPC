provider "aws" {
  region = "us-west-2"
}

#Resources take a type as the 1st argument (corresponding to an AWS service) and a name to identify it as 2nd argument
resource "aws_vpc" "main" {
  #Customise the settings of a resource within the block
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "VPC-tcanning"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
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
}

resource "aws_instance" "public_instances" {
  count         = 1
  ami           = "ami-0c36451c41e1eefd2"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]  # Use security group ID(s) here
  key_name      = "tcanning-keypair"  // Add this line

  //This adds an encrypted EBS volume to the instance (gp2 is general purpose SSD, 4GB in size)
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true  # Ensures the root EBS volume is encrypted
  }

  tags = {
    Name = "tcanninginstance-${count.index}"
  }
}

//Adds a bucket to the AWS account
resource "aws_s3_bucket" "my_bucket" {
  bucket = "bucket-tcanning"
}