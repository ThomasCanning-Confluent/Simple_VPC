<h1>VPC with a bucket in AWS</h1>

<h1>VPC with a Bucket in AWS</h1>

This is a VPC with 1 public and private subnet, an internet gateway, and a bucket. 
The bucket is used to store and retrieve data from the VPC. 
The bucket is within the public subnet and can be accessed from the internet.
S3 (Simple Storage Service) is an object storage service. This bucket can be used to store and retrieve any amount of data, at any time, from anywhere on the web.
You can access the bucket using the AWS CLI, e.g. aws s3 cp file1.txt s3://bucket-tcanning/file1.txt.
The bucket can also be accessed from the AWS Management Console.
It can also be accessed with SSH, e.g. sh -i ~/.ssh/tcanning-keypair.pem ec2-user@x.x.x.x
The VPC also includes an encrypted EBS volume that is attached to the EC2 instance in the private subnet.
An ebs volume is a block storage device that can be attached to an EC2 instance.