<h1>Simple VPC in AWS made using the terraform repository</h1>

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
