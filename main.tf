provider "aws" {
  region = "eu-west-2"
}

variable "owner" {
  description = "The owner of the resources"
  type        = string
  default     = "Thomas Canning"
}

resource "aws_vpc" "main" {

  cidr_block = "10.0.0.0/24"
  tags = {
    Name="Simple VPC"
    Owner=var.owner
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id #This associates the internet gateway with the VPC
  tags = {
    Name        = "Simple VPC internet gateway"
    Owner=var.owner
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public_subnets" {
  count = 3

  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.${count.index}.0/24"

  map_public_ip_on_launch = true

  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "Simple VPC public subnet ${count.index + 1}"
    Owner=var.owner
  }
}

resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "Simple VPC private subnet ${count.index + 1}"
    Owner=var.owner
  }
}

resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

    tags = {
        Name = "Simple VPC public route table"
        Owner=var.owner
    }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id

    tags = {
        Name = "Simple VPC public route table association ${count.index + 1}"
        Owner=var.owner
    }
}

resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["66.159.216.54/32", "2001:4860:7:633::fe/128"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "Simple VPC public security group"
    Owner = var.owner
  }
}

resource "aws_instance" "public_instances" {
  count         = 3
  ami           = "ami-0c36451c41e1eefd2"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]

  tags = {
    Name = "Simple VPC public instance ${count.index + 1}"
    Owner=var.owner
  }
}

resource "aws_vpc" "second" {
  #This VPC uses a different CIDR block
  #This is to ensure that the VPCs do not overlap
  cidr_block = "10.1.0.0/24"
  tags = {
    Name  = "Second VPC"
    Owner=var.owner
  }
}

resource "aws_internet_gateway" "igw2" {
  tags = {
    Name = "Second VPC internet gateway"
    Owner=var.owner
  }
}

resource "aws_subnet" "second_public_subnets" {
  count             = 3
  vpc_id            = aws_vpc.second.id
  cidr_block        = "10.1.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_subnet" "second_private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.second.id
  cidr_block        = "10.1.${count.index + 3}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_route_table" "second_public_rt" {
  vpc_id = aws_vpc.second.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw2.id
  }
}

resource "aws_route_table_association" "second_public_assoc" {
  count          = 3
  subnet_id      = aws_subnet.second_public_subnets[count.index].id
  route_table_id = aws_route_table.second_public_rt.id
}

resource "aws_security_group" "second_public_sg" {
  vpc_id = aws_vpc.second.id

  ingress {
    from_port   = 22
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

resource "aws_instance" "second_public_instances" {
  count         = 3
  ami           = "ami-0c36451c41e1eefd2"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.second_public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.second_public_sg.id]

  tags = {
    Name = "SecondPublicInstance-${count.index}"
  }
}

#A VPC peering connection enables traffic routing between two VPCs using private IP addresses.
#Can be used for sharing resources between VPCs

resource "aws_vpc_peering_connection" "peer" {
  #vpc_id refers to the VPC initiating the peering connection
  vpc_id        = aws_vpc.main.id
  #peer_vpc_id refers to the VPC accepting the peering connection
  peer_vpc_id   = aws_vpc.second.id
  peer_region   = "eu-west-2"
}

#Accepter automatically accepts the peering connection
#This means that the owner of the peer VPC does not have to manually accept the connection
#An alternative is to require manual acceptance
resource "aws_vpc_peering_connection_accepter" "peer_accepter" {
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
  #depends_on ensures accepter is created after the peering connection
  depends_on                = [aws_vpc_peering_connection.peer]
}

#Creates a route in the route table of the 1st VPC that directs traffic to the 2nd VPC via a peering connection
resource "aws_route" "main_to_second" {
  #This specifies routes will be added to the public route table of the 1st VPC
  route_table_id         = aws_route_table.public_rt.id
  #Specifies the destination CIDR block as the CIDR block of the 2nd VPC
  destination_cidr_block = aws_vpc.second.cidr_block
  #Associates this route with the peering connection created earlier
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

#Route table of 2nd VPC is also updated to direct traffic to the 1st VPC via the peering connection
resource "aws_route" "second_to_main" {
  route_table_id            = aws_route_table.second_public_rt.id
  destination_cidr_block    = aws_vpc.main.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}