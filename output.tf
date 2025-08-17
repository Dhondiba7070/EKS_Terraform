output "cluster_id" {
  value = aws_eks_cluster.dhondiba.id
}

output "node_group_id" {
  value = aws_eks_node_group.dhondiba.id
}

output "vpc_id" {
  value = aws_vpc.dhondiba_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.dhondiba_subnet[*].id
}
