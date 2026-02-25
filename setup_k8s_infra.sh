#!/bin/bash

# ==============================================================================
# Kubernetes AWS Infrastructure Bootstrap Script
# ==============================================================================
# This script generates Terraform modules and files for a 1-Master, 1-Worker
# Self-Managed Kubernetes Cluster.
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  K8s AWS Infra Generator${NC}"
echo -e "${GREEN}========================================${NC}"

# ------------------------------------------------------------------------------
# 1. Interactive Input
# ------------------------------------------------------------------------------
read -p "$(echo -e "${YELLOW}Enter your AWS EC2 Key Pair Name (e.g., ecommerce-key): ${NC}")" KEY_NAME
if [ -z "$KEY_NAME" ]; then
    KEY_NAME="ecommerce-key"
    echo -e "${YELLOW}No input provided. Defaulting to: ${KEY_NAME}${NC}"
fi

REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
    echo -e "${YELLOW}Region not found in aws config. Defaulting to: ${REGION}${NC}"
fi

PROJECT_DIR="terraform-k8s-practice"

echo -e "${GREEN}Creating directory structure in ./${PROJECT_DIR}...${NC}"
rm -rf $PROJECT_DIR
mkdir -p $PROJECT_DIR
mkdir -p $PROJECT_DIR/modules/vpc
mkdir -p $PROJECT_DIR/modules/security
mkdir -p $PROJECT_DIR/modules/ec2

# ------------------------------------------------------------------------------
# 2. Generate Terraform Files
# ------------------------------------------------------------------------------

# --- ROOT VARIABLES ---
cat << EOF > $PROJECT_DIR/variables.tf
variable "region" {
  description = "AWS Region"
  type        = string
  default     = "$REGION"
}

variable "key_name" {
  description = "AWS EC2 Key Pair Name"
  type        = string
  default     = "$KEY_NAME"
}

variable "master_instance_type" {
  description = "Instance type for Master Node"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "Instance type for Worker Node"
  type        = string
  default     = "t3.medium"
}
EOF

# --- ROOT PROVIDER ---
cat << EOF > $PROJECT_DIR/provider.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
EOF

# --- ROOT MAIN ---
cat << EOF > $PROJECT_DIR/main.tf
# VPC Module
module "vpc" {
  source = "./modules/vpc"
}

# Security Group Module
module "security" {
  source      = "./modules/security"
  vpc_id      = module.vpc.vpc_id
  cidr_block  = module.vpc.vpc_cidr
}

# EC2 Module
module "ec2" {
  source       = "./modules/ec2"
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.public_subnet_id
  sg_id        = module.security.sg_id
  key_name     = var.key_name
  master_type  = var.master_instance_type
  worker_type  = var.worker_instance_type
}
EOF

# --- ROOT OUTPUTS ---
cat << EOF > $PROJECT_DIR/outputs.tf
output "master_public_ip" {
  description = "Public IP of the K8s Master Node"
  value       = module.ec2.master_public_ip
}

output "worker_public_ip" {
  description = "Public IP of the K8s Worker Node"
  value       = module.ec2.worker_public_ip
}

output "next_steps" {
  description = "Instructions to join the cluster"
  value       = <<-EOT
    1. SSH into Master: ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@\${module.ec2.master_public_ip}
    2. Run this command on Master to get join token:
       sudo kubeadm token create --print-join-command
    3. SSH into Worker: ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@\${module.ec2.worker_public_ip}
    4. Paste the join command (with sudo) on the Worker node.
    5. Back on Master, run: kubectl get nodes
    EOT
}
EOF

# --- MODULE: VPC ---
cat << EOF > $PROJECT_DIR/modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "k8s-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "k8s-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "\${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = true
  tags = {
    Name = "k8s-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "k8s-rt"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}
EOF

# --- MODULE: SECURITY ---
cat << EOF > $PROJECT_DIR/modules/security/main.tf
variable "vpc_id" {
  type = string
}

variable "cidr_block" {
  type = string
}

resource "aws_security_group" "k8s_sg" {
  name        = "k8s-cluster-sg"
  description = "Security group for K8s Cluster"
  vpc_id      = var.vpc_id

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K8s API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # etcd
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }

  # Node Port Range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All traffic from within VPC (Node to Node)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-sg"
  }
}

output "sg_id" {
  value = aws_security_group.k8s_sg.id
}
EOF

# --- MODULE: EC2 (With User Data) ---
# Note: We use 'EOF_UDE' to avoid conflict with inner scripts
cat << 'EOF_UDE' > $PROJECT_DIR/modules/ec2/main.tf
variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "sg_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "master_type" {
  type = string
}

variable "worker_type" {
  type = string
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# --- MASTER NODE USER DATA ---
locals {
  master_user_data = <<-USERDATA
    #!/bin/bash
    set -e
    
    # Disable Swap
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Load Kernel Modules
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    modprobe overlay
    modprobe br_netfilter

    # Sysctl params
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF
    sysctl --system

    # Install Containerd
    apt-get update
    apt-get install -y containerd
    mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    systemctl restart containerd

    # Install K8s Binaries
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    # Initialize Cluster (Wait for network)
    sleep 10
    kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU
    
    # Setup Kubeconfig
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Install Calico Network Plugin
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
    
    # Allow Master to schedule pods (optional for single node, but good for practice)
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
  USERDATA
}

# --- WORKER NODE USER DATA ---
locals {
  worker_user_data = <<-USERDATA
    #!/bin/bash
    set -e
    
    # Disable Swap
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Load Kernel Modules
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    modprobe overlay
    modprobe br_netfilter

    # Sysctl params
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF
    sysctl --system

    # Install Containerd
    apt-get update
    apt-get install -y containerd
    mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    systemctl restart containerd

    # Install K8s Binaries
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
  USERDATA
}

# --- MASTER INSTANCE ---
resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name
  user_data              = base64encode(local.master_user_data)

  tags = {
    Name = "k8s-master"
  }
}

# --- WORKER INSTANCE ---
resource "aws_instance" "worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name
  user_data              = base64encode(local.worker_user_data)

  tags = {
    Name = "k8s-worker"
  }
}

output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ip" {
  value = aws_instance.worker.public_ip
}
EOF_UDE

# ------------------------------------------------------------------------------
# 3. Initialize Terraform
# ------------------------------------------------------------------------------
echo -e "${GREEN}Initializing Terraform...${NC}"
cd $PROJECT_DIR
terraform init

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Review the plan: terraform plan"
echo "2. Create Infra: terraform apply -auto-approve"
echo "3. Wait 3-5 minutes for EC2 User Data to finish installing K8s."
echo "4. Check outputs: terraform output"
