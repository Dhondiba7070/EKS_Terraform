output "cluster_id" {
  description = "The ID of the EKS Cluster"
  value       = aws_eks_cluster.dhondiba.id
}

output "node_group_id" {
  description = "The ID of the EKS Node Group"
  value       = aws_eks_node_group.dhondiba.id
}

output "vpc_id" {
  description = "The ID of the VPC where EKS is deployed"
  value       = aws_vpc.dhondiba_vpc.id
}

output "subnet_ids" {
  description = "The IDs of the subnets used for the EKS Cluster"
  value       = aws_subnet.dhondiba_subnet[*].id
}
