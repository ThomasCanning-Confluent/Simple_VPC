#Terraform providers are the plugins that allow terraform to interact with different services, such as cloud providers like AWS.
#There are ore than 3000 different providers.
provider "aws" {
  #All the following resources will be created in this region.
  #There are currently 33 regions.
  #Its best to choose the region closest to the end users to reduce latency, or use multiple regions if global user base
  #Another factor is some regions are cheaper than others
  region = "eu-west-2" #This is the London region
  profile = "cc-devel-1/nonprod-administrator" #This is the profile name in the AWS credentials file
}

#Defining a owner variable that is used throughout the file in the tags
variable "owner" {
  type        = string
  default     = "tcanning"
}

variable "name"{
    type        = string
    default     = "simple-vpc-eks"

}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

#Resources take a type as the 1st argument (corresponding to an AWS service) and a name to identify it as 2nd argument
#You then customise the settings of the resource within the block
#Every resource in this file is associated with a VPC
resource "aws_vpc" "main" {

  #A CIDR block (Classless Inter-Domain Routing) specifies the range of internal IP addresses that can be used in the VPC
  #The value includes an IP address and a prefix size
  #IP address is of format x.x.x.x and represents the start of the ip address range
  #There are specific ranges of IP addresses that can be used for private networks, e.g. 10.0.0.0
  #The prefix size, in this case 16, specifies how many bits are used for the network portion of the address (subnet mask)
  #This means 16 bits are used to identify the network
  #The remaining bits (32-n) are used for the host address
  #So increasing prefix size decreases the number of available IP addresses
  #10.0.0.0/16 allows for 65,536 IP addresses
  #The range starts at 10.0.0.0 and ends at 10.0.255.255
  #The first and last IP addresses are reserved for the network address and broadcast address, giving 254 usable IP addresses
  #Use a smaller prefix size for bigger VPCs
  #The other resources must use a CIDR block within the VPC's CIDR block range
  cidr_block = var.vpc_cidr

  #Tags can be used for different things, such as:
  #Name tag for identification in the AWS console
  #Owner tag
  #Cost centre tag
  #Project tag
  #Environment tag, e.g. dev, test, prod
  tags = {
    Name  = var.name
    Owner= var.owner
  }
}

#Internet gateway allows instances in the public subnet to connect to the internet.
#Only 1 internet gateway can be attached to a VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id #This associates the internet gateway with the VPC
  tags = {
    Name  = "${var.name}-internet-gateway" //The ${} syntax is used to interpolate variables
    Owner=var.owner
  }
}

#Fetches the availability zones for the region which is used to assign an availability zone to each subnet
data "aws_availability_zones" "available" {}

#Subnets allow you to subdivide your VPC into multiple networks.
#Useful for routing and managing traffic within your network, such as in this case public and private subnet
#Different subnets can have different security settings, e.g. public subnets can have internet access
#Subnets have:
#An associated route table that determines where network traffic is directed
#An associated security group that acts as a firewall
#An associated CIDR block that specifies the range of IP addresses in the subnet
#An associated availability zone
#An associated VPC
#Public subnets have a route to the internet gateway
resource "aws_subnet" "public_subnets" {

  #Creates 2 subnets
  count = 2

  # Associates the subnet with a specific VPC. Here, it's associated with the VPC created earlier.
  vpc_id = aws_vpc.main.id

  # CIDR block specifies the range of internal IP addresses that can be used in the subnet.
  # In this case 10.0.i.0 to 10.0.i.255
  cidr_block = "10.0.${count.index}.0/24"

  # Determines whether instances that are launched in this subnet receive a public IP address.
  # If true, enables communication with the internet.
  # This is what makes the subnet a public subnet.
  map_public_ip_on_launch = true

  # Specifies which availability zone the subnet is created in.
  # Since only one subnet is created, we use the first availability zone from the list.
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name  = "${var.name}-public-subnet-1-${count.index + 1}"
    Owner = var.owner
  }
}

resource "aws_subnet" "private_subnets" {
  count=2
  # Associates the subnet with a specific VPC. Here, it's associated with the VPC created earlier.
  vpc_id = aws_vpc.main.id

  cidr_block= "10.0.${count.index+3}.0/24"

  # Specifies which availability zone the subnet is created in.
  # Since only one subnet is created, we use the first availability zone from the list.
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name  = "${var.name}-private-subnet-${count.index + 1}"
    Owner = var.owner
  }
}

resource "aws_route" "public_route" {
  count = 2
  route_table_id = aws_vpc.main.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main[count.index].id
}

#Route tables determine where network traffic is directed
#Public route table is associated with the internet gateway
#This allows instances in the public subnet to connect to the internet
resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main.id

  route {
    # Only allows routes from the VPN
    cidr_block= "66.159.216.54/32"
    #Connects the route table to the internet gateway
    gateway_id = aws_internet_gateway.igw.id
  }

    tags = {
        Name = "${var.name}-public-route-table"
        Owner=var.owner
    }
}

#This associates the public subnets with the route table which enables internet access
resource "aws_route_table_association" "public_assoc" {
  count          = 2

  #Count creates a separate route table association for each public subnet
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id

  # Route table association doesn't support tagging
}

# Create Elastic IP
# An EIP is a static, public IP address that can be allocated and associated with AWS resources such as NAT gateways
resource "aws_eip" "main" {
}

# Create NAT Gateway
resource "aws_nat_gateway" "main" {
  count=2
  allocation_id = aws_eip.main.id
  subnet_id     = aws_subnet.public_subnets[count.index].id
  tags = {
    Name = "${var.name}-nat-gateway"
  }
}

#Security groups act as a firewall
#Controls inbound and outbound traffic to instances
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    #Allows inbound traffic on port 22 (SSH)
    from_port   = 22
    to_port     = 22

    # TCP is a connection-oriented protocol (meaning requires a connection to be established before data is sent)
    # TCP ensures all data is received and in the correct order
    # An alternative is UDP, which is connectionless and doesn't guarantee data delivery
    # But might be more suitable if speed is more important than reliability
    protocol    = "tcp"

    # CIDR block specifies the range of IP addresses that are allowed to access the instance
    # The IP is the IP of the VPN
    # This means only traffic from the VPN can access the instance
    cidr_blocks = ["66.159.216.54/32"]
  }

  ingress{
    # port 443 is HHTPS
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks = ["66.159.216.54/32"]
  }

  ingress{
    # port 80 is HTTP
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["66.159.216.54/32"]
  }

  egress {
    #Port 0 to 0 means all ports are allowed, so all outbound traffic is allowed
    from_port   = 0
    to_port     = 0
    #-1 means all protocols are allowed
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "${var.name}-public-security-group"
    Owner = var.owner
  }
}

# Security group for data plane
#Data plane is for communicaation between nodes
resource "aws_security_group" "data_plane_sg" {
  name   = "k8s-data-plane-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-data-plane-sg"
  }

  #Port 0 to 65535 means all ports are allowed
  ingress {
    description     = "Allow nodes to communicate with each other"
    from_port       = 0
    to_port         = 65535
    protocol        = "-1"
    cidr_blocks = concat(
      aws_subnet.private_subnets[*].cidr_block,
      aws_subnet.public_subnets[*].cidr_block
    )
  }
}

## Egress rule
resource "aws_security_group_rule" "node_outbound" {
  security_group_id = aws_security_group.data_plane_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security group for control plane
resource "aws_security_group" "control_plane_sg" {
  name   = "${var.name}-control-plane-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-control-plane-sg"
  }
}

# Security group traffic rules
## Ingress rule
resource "aws_security_group_rule" "control_plane_inbound" {
  security_group_id = aws_security_group.control_plane_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

## Egress rule
resource "aws_security_group_rule" "control_plane_outbound" {
  security_group_id = aws_security_group.control_plane_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
