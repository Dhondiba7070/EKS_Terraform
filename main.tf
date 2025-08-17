provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "dhondiba_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dhondiba-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "dhondiba_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.dhondiba_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.dhondiba_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "dhondiba-subnet-${count.index}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "dhondiba_igw" {
  vpc_id = aws_vpc.dhondiba_vpc.id

  tags = {
    Name = "dhondiba-igw"
  }
}

# Route Table
resource "aws_route_table" "dhondiba_route_table" {
  vpc_id = aws_vpc.dhondiba_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dhondiba_igw.id
  }

  tags = {
    Name = "dhondiba-route-table"
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "dhondiba_assoc" {
  count          = 2
  subnet_id      = aws_subnet.dhondiba_subnet[count.index].id
  route_table_id = aws_route_table.dhondiba_route_table.id
}

# Security Group for EKS Cluster
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

# Security Group for Worker Nodes
resource "aws_security_group" "dhondiba_node_sg" {
  vpc_id = aws_vpc.dhondiba_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

# IAM Role for EKS Cluster
resource "aws_iam_role" "dhondiba_cluster_role" {
  name = "dhondiba-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach Cluster Policy
resource "aws_iam_role_policy_attachment" "dhondiba_cluster_role_policy" {
  role       = aws_iam_role.dhondiba_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM Role for Worker Nodes
resource "aws_iam_role" "dhondiba_node_group_role" {
  name = "dhondiba-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach Worker Node Policies
resource "aws_iam_role_policy_attachment" "dhondiba_node_group_role_policy" {
  role       = aws_iam_role.dhondiba_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "dhondiba_node_group_cni_policy" {
  role       = aws_iam_role.dhondiba_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "dhondiba_node_group_registry_policy" {
  role       = aws_iam_role.dhondiba_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# EKS Cluster
resource "aws_eks_cluster" "dhondiba" {
  name     = "dhondiba-cluster"
  role_arn = aws_iam_role.dhondiba_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.dhondiba_subnet[*].id
    security_group_ids = [aws_security_group.dhondiba_cluster_sg.id]
  }
}

# Node Group
resource "aws_eks_node_group" "dhondiba" {
  cluster_name    = aws_eks_cluster.dhondiba.name
  node_group_name = "dhondiba-node-group"
  node_role_arn   = aws_iam_role.dhondiba_node_group_role.arn
  subnet_ids      = aws_subnet.dhondiba_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.dhondiba_node_sg.id]
  }
}
