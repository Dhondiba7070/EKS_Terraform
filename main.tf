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
  vpc_id = aws_vpc.dhon
