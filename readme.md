<h1>Simple VPC in AWS</h1>

<h2> Overview of the VPC</h2>

![Image of VPC diagram](vpc_diagram.png)

<p>This is a simple VPC (Virtual private cloud) in AWS. It has the following components:
<ul>
<li>3 public subnets that each contain a NAT (Network Address Translation service for internet access). Public subnets enable internet access for components hosted within.</li>
<li>3 private subnets which are not directly accessible from the internet, don't have public IP addresses, and can only access the internet via a NAT. </li>
<li>An internet gateway that allows instances in the public subnets to connect to the internet. Only 1 internet gateway can be associated with each VPC.</li>
<li>A public route table that routes traffic destined for the internet through the internet gateway.</li>
<li>A private route table that routes traffic destined for the internet through the NAT.</li>
</ul>

<h2>VPC Talking points</h2>
To run, you run terraform init then terraform apply to make the changes to AWS. Terraform destory deletes everything in config file (opposite of apply)
.A linux based EC2 instance has been deployed to each private subnet (AMI ID=ami-0c36451c41e1eefd2). The region has been set to us-west-2. The instance type is t2.micro. §
<ul>
<li>A VPC is a private network that has subnets within it. VPC is placed in a region and each subnet is placed in an availability zone. Resoures within the VPC can communicate with eachother. Other services withing a vpc such as an internet gateway allow connections over the public internet, and can then keep other subnets private, adding a layer of security./<li>
<li>CIDR block (Classless Inter-Domain Routing) = collection of IP addresses, defines the number of internal network addresses that may be used internally</li>
<li>EC2 instances are what run the web application in the cloud</li>
<li>Subnets are used for internally segregating resources contained in the VPC.</li>
<li>VPCs span all the availability zones in a region (this case us-west)</li>
<li>Each AWS region has multiple, isolated locations known as availability zones (AZ). AWS cloud spans 105 AZs</li>
<li>Route tables define a default route that let components in the VPC communicate with eachother internally</li>
<li>Terraform, an infrastructure as code tool that can provision resources in the cloud from declarative code, is used to make the VPC. Has the benefits of being able to manage infrastructure across different cloud platforms using a single tool, can be reused easily, is safer and predictable, and CI can be automated easier. </li>
<li>The code has been stored on github in a private git repository. Git is a version control system that makes keeping history of changes, collaborating with other developers, and continuous integration easy. Git repositories can be hosted on platforms such as github which provides an interface and collaborative environment for managing repositories.</li>
<li>Terraform state is stored locally by default. Other options are remote state storage options offered by AWS, or terraform provides Terraform cloud as a hosted solution meaning you don't have to manage state youself</li>
<li>In this network, nodes in the same subnet can talk to eachother. The nodes in the public subnet can talk to the internet, the private subnet nodes can't directly, but can through the public subnet.</li>
<li>The AWS credentials are stored in the config file</li>
<li>A 2nd VPC was then created, and the two were peered together, meaning the nodes in the 1st can connect to nodes in the 2nd using private IP addresses, i.e. allowing communication as if they were on the same network. </li>
<li>Terraform has modules, which let you implement a repeatable pattern with parameters. You can pass parameters to modules to customise the resources they create, which makes it easy to implement repeatable patterns.</li>
<li>Deleting the destination of a route table entry means no traffic that was previously routed based on that entry will have a defined anymore so will be dropped causing network communication issues. Deleting just the destination will make the route table entry become invalid. 'terraform apply' will attempt to correct or remove the invalid entry.</li>
<li>Firewall uses ssh security group rules</li>
<li>Drift detection is identifying changes in the infrastructure that were made outside terraform, which works by comparing the current state of your infrastructure with the actual live state.</li>
<li>I added the files to the bucket 1st using the AWS GUI, and then using the AWS CLI command aws s3 cp file2.txt s3://bucket-tcanning/file2.txt
<li>I was able to ssh into the VPC with the command ssh -i ~/.ssh/tcanning-keypair.pem ec2-user@52.27.198.210 and then upload files to the buckets with ssh</li>
</li>
</ul>
3 versions have been made on different branches. main has 2 VPCs peered, task2 explores buckets and an EBS volume, and nodesInPrivateSubnet is the original VPC but with nodes in the private subnet instead of public.
This website has been used as a reference: https://spacelift.io/blog/terraform-aws-vpc