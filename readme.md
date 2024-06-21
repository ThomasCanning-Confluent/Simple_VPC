<h1>Peered VPC in AWS</h1>

VPC Peering is a networking connection between two VPCs that enables you to route traffic between them using IP addresses 
allowing for efficient and secure communication between two VPCs as if they were on the same network, 
while still maintaining the isolation and security benefits of VPCs. 
Peering can be used for sharing resources between VPCs, or for providing users in one VPC with access to applications in another.

The terraform code in this branch sets up a peered connection between two VPCs in the same region with routes configured to allow traffic to flow between them.