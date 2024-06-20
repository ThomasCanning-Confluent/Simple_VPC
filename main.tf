provider "aws" {
  region = "us-west-2"
}

#Resources take a type as the 1st argument (corresponding to an AWS service) and a name to identify it as 2nd argument
resource "aws_vpc" "main" {
  #Customise the settings of a resurce within the block
  cidr_block = "10.0.0.0/16"

  tags = {
    Name="Simple VPC" #Tags can be used for different things, such as a name tag for identification
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id #This associates the internet gateway with the simple VPC
  tags={
    Name="Simple VPC Internet Gateway"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"#Count index gives each of the (3) VPCs a different name
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)#This places each VPC in a different availability zone
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id #This is what makes the public subnets public, by making use of the internet gateway we enable traffic from the internet to access the subnets
  }
}

#This associates the public subnets with the route table which enables internet access
resource "aws_route_table_association" "public_assoc" {
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

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

resource "aws_instance" "public_instances" {
  count         = 3
  ami           = "ami-0c36451c41e1eefd2"  # Replace with your AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]  # Use security group ID(s) here

  tags = {
    Name = "PublicInstance-${count.index}"
  }
}

#Adding a 2nd VPC with same layout
resource "aws_vpc" "second" {
  cidr_block = "10.1.0.0/16"
}

resource "aws_internet_gateway" "igw2" {
  vpc_id = aws_vpc.second.id
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
  ami           = "ami-0c36451c41e1eefd2"  # Replace with your AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.second_public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.second_public_sg.id]

  tags = {
    Name = "SecondPublicInstance-${count.index}"
  }
}

// VPC Peering Connection to peer second VPC with first
resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = aws_vpc.second.id
  peer_region   = "us-west-2"
}

// Accept Peering Connection
resource "aws_vpc_peering_connection_accepter" "peer_accepter" {
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
  depends_on                = [aws_vpc_peering_connection.peer]
}

// Update route tables to enable communication between VPCs
//The route table of first vpc is updated to route traffic to the 2nd vpc
resource "aws_route" "main_to_second" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = aws_vpc.second.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

//The route table of 2nd vpc is updated to route traffic to the 1st vpc
resource "aws_route" "second_to_main" {
  route_table_id         = aws_route_table.second_public_rt.id
  destination_cidr_block = aws_vpc.main.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}