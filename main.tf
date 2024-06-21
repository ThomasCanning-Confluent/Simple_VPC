#Terraform providers are the plugins that allow terraform to interact with different services, such as cloud providers like AWS.
#There are ore than 3000 different providers.
provider "aws" {
  #All the following resources will be created in this region.
  #There are currently 33 regions.
  #Its best to choose the region closest to the end users to reduce latency, or use multiple regions if global user base
  #Another factor is some regions are cheaper than others
  region = "eu-west-2" #This is the London region
}

#Defining a owner variable that is used throughout the file in the tags
variable "owner" {
  type        = string
  default     = "Thomas Canning"
}

variable "name"{
    type        = string
    default     = "Simple VPC"

}

#Resources take a type as the 1st argument (corresponding to an AWS service) and a name to identify it as 2nd argument
#You then customise the settings of the resource within the block
#Every resource in this file is associated with a VPC
resource "aws_vpc" "main" {

  #A CIDR block (Classless Inter-Domain Routing) specifies the range of internal IP addresses that can be used in the VPC
  #The value includes an IP address and a prefix size
  #IP address is of format x.x.x.x and represents the start of the ip address range
  #There are specific ranges of IP addresses that can be used for private networks, e.g. 10.0.0.0
  #The prefix size, in this case 24, specifies how many bits are used for the network portion of the address (subnet mask)
  #This means 24 bits are used to identify the network
  #The remaining bits (32-n) are used for the host address
  #So increasing prefix size decreases the number of available IP addresses
  #10.0.0.0/24 allows for 256 IP addresses
  #The range starts at 10.0.0.0 and ends at 10.0.0.255
  #The first and last IP addresses are reserved for the network address and broadcast address, giving 254 usable IP addresses
  #Use a smaller prefix size for bigger VPCs

  cidr_block = "10.0.0.0/24"
  #Tags can be used for different things, such as:
  #Name tag for identification in the AWS console
  #Owner tag
  #Cost centre tag
  #Project tag
  #Environment tag, e.g. dev, test, prod
  tags = {
    Name  = var.name
    Owner=var.owner
  }
}

#Internet gateway allows instances in the public subnet to connect to the internet.
#Only 1 internet gateway can be attached to a VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id #This associates the internet gateway with the VPC
  tags = {
    Name = var.name + " internet gateway"
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
  #Creates multiple instances of a resource. In this case, it's creating 3 subnets.
  count = 3

  #Associates the subnet with a specific VPC. Here, it's associated with the VPC created earlier.
  vpc_id = aws_vpc.main.id

  #CIDR block specifies the range of internal IP addresses that can be used in the subnet.
  #Uses the count.index to create a unique CIDR block for each subnet.
  cidr_block = "10.0.${count.index}.0/24"

  #Determines whether instances that are launched in this subnet receive a public IP address
  #If true, enables communication with the internet
  #This is what makes the subnet a public subnet
  map_public_ip_on_launch = true

  #Specifies which availability zone the subnet is created in
  #Element function is used to loop through the list of availability zones and assign a different one to each subnet
  #If there are more subnets than availability zones, it will loop back to the start of the list
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = var.name + " public subnet ${count.index + 1}"
    Owner=var.owner
  }
}

#Creates more subnets, this time map_public_ip_on_launch is omitted (default is false) to make the subnets private
resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = var.name+ " private subnet ${count.index + 1}"
    Owner=var.owner
  }
}

#Route tables determine where network traffic is directed
#Public route table is associated with the internet gateway
#This allows instances in the public subnet to connect to the internet
resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main.id

  route {
    #CIDR block of 0.0.0.0/0 means all IP addresses are allowed (default gateway)
    cidr_blocks = ["66.159.216.54/32", "2001:4860:7:633::fe/128"]
    #Connects the route table to the internet gateway
    gateway_id = aws_internet_gateway.igw.id
  }

    tags = {
        Name = var.name+ " public route table"
        Owner=var.owner
    }
}

#This associates the public subnets with the route table which enables internet access
resource "aws_route_table_association" "public_assoc" {
  #Count creates a separate route table association for each public subnet
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id

    tags = {
        Name = var.name +" public route table association ${count.index + 1}"
        Owner=var.owner
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

    #TCP is a connection-oriented protocol (meaning requires a connection to be established before data is sent)
    #TCP ensures all data is received and in the correct order
    #An alternative is UDP, which is connectionless and doesn't guarantee data delivery
    #But might be more suitable if speed is more important than reliability
    protocol    = "tcp"

    #CIDR block specifies the range of IP addresses that are allowed to access the instance
    #The two IPs provided are the IPv4 and IPv6 addresses of the VPN
    #This means only traffic from the VPN can access the instance
    cidr_blocks = ["66.159.216.54/32", "2001:4860:7:633::fe/128"]
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
    Name  = var.name+" public security group"
    Owner = var.owner
  }
}

#An AWS instance is a virtual server in the cloud
resource "aws_instance" "public_instances" {
  count         = 3

  #AMI (Amazon Machine Image) is a template for the root volume of an instance
  #It contains the operating system, application server, and applications, in this case a Linux image
  #The key comes from the AWS console
  ami           = "ami-0c36451c41e1eefd2"

  #Instance type determines the hardware of the host computer used for the instance
  #T2.micro is a cheap instance type with a small amount of CPU and memory
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.public_sg.id]

  tags = {
    Name = var.name+" public instance ${count.index + 1}"
    Owner=var.owner
  }
}
