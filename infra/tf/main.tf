provider "aws" {
  region = var.aws_region
}

###############################
# IAM Resources for EKS and Nodes
###############################

# IAM Role for the EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM Role for the EKS Worker Nodes
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "fsx_csi_policy" {
  name        = "FSxCSIAccessPolicy"
  description = "Allows EKS nodes to use FSx CSI"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "fsx:*",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fsx_csi_policy_attach" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.fsx_csi_policy.arn
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

###############################
# Security Groups
###############################

# Security Group for the EKS Cluster (used by the control plane)
resource "aws_security_group" "eks_cluster_sg" {
  name        = "eks-cluster-sg"
  description = "Security group for the EKS cluster"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for FSx Lustre
resource "aws_security_group" "fsx_sg" {
  name        = "boomi-fsx-sg"
  description = "Security group for FSx Lustre file system"
  vpc_id      = module.vpc.vpc_id

  # Allow Lustre traffic from EKS control plane
  ingress {
    description     = "Allow Lustre traffic from EKS control plane"
    from_port       = 988
    to_port         = 988
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }
  
  # Allow Lustre traffic from EKS node groups
  ingress {
    description = "Allow Lustre traffic from all nodes in VPC"
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Allow from any instance in the VPC
  }

  # Allow self-referencing for Lustre traffic
  ingress {
    description = "Allow Lustre LNET self traffic"
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "Allow Lustre traffic from EKS nodes"
    from_port       = 1021
    to_port         = 1023
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }
  
  ingress {
    description = "Allow Lustre traffic 1021-1023 from all nodes in VPC"
    from_port   = 1021
    to_port     = 1023
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################
# SSH Key Pair (Auto-Generated)
###############################

# Generate an RSA private key
resource "tls_private_key" "eks_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Register the public key with AWS as a Key Pair
resource "aws_key_pair" "eks_key_pair" {
  key_name   = "boomi-eks-key"
  public_key = tls_private_key.eks_key.public_key_openssh
}

###############################
# Passing Resources into Modules
###############################

module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr            = var.vpc_cidr
  vpc_name            = var.vpc_name
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  public_azs          = var.public_azs
  private_azs         = var.private_azs
}

module "eks" {
  source                      = "./modules/eks"
  cluster_name                = var.cluster_name
  cluster_role_arn            = aws_iam_role.eks_cluster_role.arn
  cluster_security_group_id   = aws_security_group.eks_cluster_sg.id
  subnet_ids                  = module.vpc.private_subnet_ids
  node_group_name             = var.node_group_name
  node_role_arn               = aws_iam_role.eks_node_role.arn
  node_desired_size           = var.node_desired_size
  node_min_size               = var.node_min_size
  node_max_size               = var.node_max_size
  node_instance_types         = var.node_instance_types
  node_ami_type               = var.node_ami_type
  ssh_key_name                = aws_key_pair.eks_key_pair.key_name
}


module "fsx" {
  source             = "./modules/fsx"
  fsx_name           = var.fsx_name
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.fsx_sg.id]
  storage_capacity   = 1200  # Minimum for PERSISTENT_1
}

