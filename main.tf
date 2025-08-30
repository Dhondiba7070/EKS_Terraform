provider "aws" {
  region = var.region
}

# -------------------------------
# VPC
# -------------------------------
resource "aws_vpc" "dhondiba_vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "dhondiba-vpc"
  }
}

# -------------------------------
# Public Subnets
# -------------------------------
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

# -------------------------------
# Internet Gateway
# -------------------------------
resource "aws_internet_gateway" "dhondiba_igw" {
  vpc_id = aws_vpc.dhondiba_vpc.id
  
  tags = {
    Name = "dhondiba-igw"
  }

  depends_on = [aws_vpc.dhondiba_vpc]
}

# -------------------------------
# Route Table
# -------------------------------
resource "aws_route_table" "dhondiba_route_table" {
  vpc_id = aws_vpc.dhondiba_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dhondiba_igw.id
  }

  tags = {
    Name = "dhondiba-route-table"
  }

  depends_on = [aws_internet_gateway.dhondiba_igw]
}

# -------------------------------
# Route Table Associations
# -------------------------------
resource "aws_route_table_association" "dhondiba_assoc" {
  count          = 2
  subnet_id      = aws_subnet.dhondiba_subnet[count.index].id
  route_table_id = aws_route_table.dhondiba_route_table.id

  depends_on = [aws_subnet.dhondiba_subnet, aws_route_table.dhondiba_route_table]
}

# -------------------------------
# Security Groups
# -------------------------------
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

# -------------------------------
# IAM Roles
# -------------------------------
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

resource "aws_iam_role_policy_attachment" "dhondiba_cluster_role_policy" {
  role       = aws_iam_role.dhondiba_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

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

# -------------------------------
# EKS Cluster
# -------------------------------
resource "aws_eks_cluster" "dhondiba" {
  name     = "dhondiba-cluster"
  role_arn = aws_iam_role.dhondiba_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.dhondiba_subnet[*].id
    security_group_ids = [aws_security_group.dhondiba_cluster_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.dhondiba_cluster_role_policy]
}

# -------------------------------
# Node Group
# -------------------------------
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

  depends_on = [
    aws_iam_role_policy_attachment.dhondiba_node_group_role_policy,
    aws_iam_role_policy_attachment.dhondiba_node_group_cni_policy,
    aws_iam_role_policy_attachment.dhondiba_node_group_registry_policy
  ]
}
