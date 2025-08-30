provider "aws" {
  region = var.region
}

resource "aws_vpc" "dhondiba_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dhondiba-vpc"
  }
}

resource "aws_subnet" "dhondiba_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.dhondiba_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.dhondiba_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "dhondiba-subnet-${count.index}"
  }

  depends_on = [aws_vpc.dhondiba_vpc]
}

resource "aws_security_group" "dhondiba_cluster_sg" {
  vpc_id = aws_vpc.dhondiba_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dhondiba-cluster-sg"
  }
}

resource "aws_security_group" "dhondiba_node_sg" {
  vpc_id = aws_vpc.dhondiba_vpc.id

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

  tags = {
    Name = "dhondiba-node-sg"
  }
}

resource "aws_eks_cluster" "dhondiba" {
  name     = "dhondiba-cluster"
  role_arn = aws_iam_role.dhondiba_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.dhondiba_subnet[*].id
    security_group_ids = [aws_security_group.dhondiba_cluster_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.dhondiba_cluster_role_policy]
}

resource "aws_eks_node_group" "dhondiba" {
  cluster_name    = aws_eks_cluster.dhondiba.name
  node_group_name = "dhondiba-node-group"
  node_role_arn   = aws_iam_role.dhondiba_node_group_role.arn
  subnet_ids      = aws_subnet.dhondiba_subnet[*].id

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  instance_types = [var.instance_type]

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.dhondiba_node_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.dhondiba_node_group_role_policy,
    aws_iam_role_policy_attachment.dhondiba_node_group_cni_policy,
    aws_iam_role_policy_attachment.dhondiba_node_group_registry_policy
  ]
}
