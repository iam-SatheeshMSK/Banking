🚀 Self-Managed Kubernetes Cluster on AWS
A complete, production-ready Kubernetes cluster setup using Terraform and kubeadm for learning and practice.
📋 Table of Contents
Overview
Architecture
Prerequisites
Quick Start
Detailed Setup Guide
Post-Provisioning Setup
Validation & Testing
Practice Exercises
Troubleshooting
Cleanup
Project Structure
📖 Overview
This project provisions a 2-node Kubernetes cluster (1 master + 1 worker) on AWS using:
Terraform - Infrastructure as Code
kubeadm - Kubernetes cluster bootstrap tool
Containerd - Container runtime
Calico - CNI networking plugin
Ubuntu 22.04 - Base OS
Perfect for:
✅ Learning Kubernetes internals
✅ Practicing cluster administration
✅ Testing deployments and configurations
✅ Understanding self-managed clusters
🏗️ Architecture
12345678910111213141516171819202122232425
┌─────────────────────────────────────────────────────────┐
│                         VPC                              │
│  CIDR: 10.0.0.0/16                                      │
│                                                          │
│  ┌────────────────────────────────────────────┐        │
│  │         Public Subnet (10.0.1.0/24)        │        │
│  │                                             │        │
│  │  ┌──────────────────┐  ┌────────────────┐ │        │
│  │  │   Master Node 
📦 Prerequisites
Before you begin, ensure you have:
Required Tools
AWS CLI configured (aws configure)
Terraform >= 1.0 installed
SSH key pair in AWS (e.g., ecommerce-key)
Local .pem file with correct permissions (chmod 400 ~/.ssh/ecommerce-key.pem)
AWS Account
Active AWS account with permissions to create:
EC2 instances
VPC, Subnets, Internet Gateway
Security Groups
Route Tables
Verify Prerequisites
bash
123456789
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check Terraform
terraform --version

# Check SSH key
ls -la ~/.ssh/ecommerce-key.pem
⚡ Quick Start
bash
123456789101112131415161718192021
# 1. Initialize Terraform
cd terraform-k8s-practice
terraform init

# 2. Create infrastructure
terraform apply -auto-approve

# 3. Wait 3-5 minutes for user_data to complete

# 4. SSH to master and run setup script

📚 Detailed Setup Guide
Step 1: Clone or Create Project
bash
123456
# If using the setup script
./setup_k8s_infra.sh

# Or manually create directory structure
mkdir -p terraform-k8s-practice/{modules/{vpc,security,ec2}}
cd terraform-k8s-practice
Step 2: Configure Variables (Optional)
Edit variables.tf to customize:
hcl
1234567891011
variable "master_instance_type" {
  default = "t3.medium"  # Change to t3.large for more resources
}

variable "worker_instance_type" {
  default = "t3.medium"
}

variable "region" {
  default = "us-east-1"  # Change to your preferred region

Step 3: Initialize Terraform
bash
1234
terraform init

# Expected output:
# Terraform has been successfully initialized!
Step 4: Review Plan (Optional but Recommended)
bash
123456789
terraform plan

# Review resources to be created:
# - 1 VPC
# - 1 Internet Gateway
# - 1 Public Subnet
# - 1 Route Table
# - 2 Security Groups
# - 2 EC2 Instances
Step 5: Apply Infrastructure
bash
123456
terraform apply -auto-approve

# Or interactive mode (recommended for first time):
terraform apply

# Enter "yes" when prompted
⏱️ Wait Time: 2-3 minutes for Terraform to complete + 3-5 minutes for Kubernetes installation
Step 6: Save Important Information
bash
1234567
# Save outputs to file
terraform output > cluster-info.txt
cat cluster-info.txt

# Example output:
# master_public_ip = "54.12.34.56"
# worker_public_ip = "34.56.78.90"
🔧 Post-Provisioning Setup
Option A: Automated Script (Recommended)
Upload the setup script to master:
bash
123
# From your local machine
scp -i ~/.ssh/ecommerce-key.pem k8s-cluster-setup.sh \
    ubuntu@$(terraform output -raw master_public_ip):~/
SSH to master node:
bash
12
Run the setup script:
bash
12
The script will:
✅ Fix kubeconfig permissions
✅ Verify cluster API access
✅ Wait for nodes to be Ready
✅ Check system pods (CoreDNS, Calico, etc.)
✅ Generate worker join command
✅ Show cluster summary
✅ Run troubleshooting checks
Option B: Manual Setup
If you prefer manual steps:
bash
123456789101112
# 1. Fix kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
chmod 600 $HOME/.kube/config

# 2. Verify cluster
kubectl cluster-info
kubectl get nodes


👥 Joining Worker Nodes
On Master Node:
bash
123456
# Generate join command
sudo kubeadm token create --print-join-command

# Example output:
# sudo kubeadm join 10.0.1.214:6443 --token abc123.xyz \
#   --discovery-token-ca-cert-hash sha256:abc123...
On Worker Node:
bash
12345678
# 1. SSH to worker (from local machine)
ssh -i ~/.ssh/ecommerce-key.pem \
    ubuntu@$(terraform output -raw worker_public_ip)

# 2. Paste the join command WITH sudo
# (Copy the entire command from master)

# 3. Wait 30-60 seconds for node to register
Verify Worker Joined:
bash
1234567
# Back on master node
kubectl get nodes

# Expected output:
# NAME            STATUS   ROLES           AGE   VERSION
# ip-10-0-1-214   Ready    control-plane   10m   v1.29.15
# ip-10-0-1-166   Ready    <none>          1m    v1.29.15
✅ Validation & Testing
1. Check Cluster Health
bash
123456789
# Nodes
kubectl get nodes -o wide

# All pods
kubectl get pods -A

# Core components
kubectl get pods -n kube-system
kubectl get pods -n calico-system
2. Deploy Test Application
bash
12345678910
# Create nginx deployment
kubectl create deployment web-server --image=nginx:latest --replicas=3

# Expose as NodePort service
kubectl expose deployment web-server --type=NodePort --port=80

# Get service details
kubectl get svc web-server

# Note the NODE-PORT (e.g., 30080)
3. Access Application
bash
12345678
# From your local browser:
# http://<WORKER_PUBLIC_IP>:<NODE_PORT>

# Example:
# http://34.56.78.90:30080

# Or using curl:
curl http://$(terraform output -raw worker_public_ip):<NODE_PORT>
Expected: "Welcome to nginx!" page
4. Test Scaling
bash
1234567
# Scale to 5 replicas
kubectl scale deployment web-server --replicas=5

# Watch pods being created
kubectl get pods -w

# Press Ctrl+C to stop watching
5. Verify Pod Distribution
bash
1234
# Check which nodes pods are running on
kubectl get pods -o wide

# Should show pods distributed across master and worker
🎓 Practice Exercises
Exercise 1: Deploy a Multi-Tier App
bash
12345678910
# Deploy Redis
kubectl create deployment redis --image=redis:alpine
kubectl expose deployment redis --port=6379 --name redis

# Deploy a web app that uses Redis
kubectl create deployment web --image=redis:alpine \
  --command -- redis-cli -h redis MONITOR

# Check logs
kubectl logs -f deployment/web
Exercise 2: ConfigMaps and Secrets
bash
12345678910111213
# Create a ConfigMap
kubectl create configmap app-config \
  --from-literal=APP_COLOR=blue \
  --from-literal=APP_MODE=dev

# Create a Secret
kubectl create secret generic app-secret \
  --from-literal=password='MySecretPassword123'

# View them

Exercise 3: Persistent Volumes
bash
123456789101112131415161718192021222324252627282930313233343536
# Create a PersistentVolumeClaim
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:

Exercise 4: Resource Limits
bash
12345678910111213141516171819202122
# Deploy with resource limits
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: limited-pod
spec:
  containers:
  - name: app
    image: nginx

Exercise 5: Node Affinity
bash
1234567891011121314151617
# Schedule pod on specific node
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: worker-only
spec:
  containers:
  - name: test
    image: busybox

🐛 Troubleshooting
Common Issues & Solutions
Issue: kubectl: connection refused to localhost:8080
Cause: Kubeconfig not set up correctly
Solution:
bash
12345
unset KUBECONFIG
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
chmod 600 $HOME/.kube/config
Issue: Worker node shows NotReady
Cause: CNI not installed or kubelet issues
Solution:
bash
123456789
# On worker node
sudo journalctl -u kubelet -n 50 --no-pager
kubectl describe node <worker-node-name>

# Restart kubelet
sudo systemctl restart kubelet

# Check CNI
kubectl get pods -n calico-system
Issue: Calico pods CrashLooping
Cause: Network configuration issue
Solution:
bash
12345
# Restart Calico daemonset
kubectl rollout restart daemonset calico-node -n calico-system

# Check logs
kubectl logs -n calico-system <calico-pod-name>
Issue: kubeadm join fails
Cause: Token expired or network unreachable
Solution:
bash
1234567
# On master, generate new token
sudo kubeadm token create --ttl 2h --print-join-command

# On worker, reset and rejoin
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d/*
# Paste new join command
Issue: Pods stuck in Pending state
Cause: No available nodes or resource constraints
Solution:
bash
123456789
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check for taints
kubectl get nodes -o jsonpath='{.items[*].spec.taints}'

# Check events
kubectl get events --sort-by='.lastTimestamp'
Diagnostic Commands
bash
123456789101112131415161718192021222324
# Cluster info
kubectl cluster-info
kubectl get componentstatuses  # (deprecated but useful)

# Node details
kubectl describe nodes

# Pod details
kubectl describe pod <pod-name>
kubectl logs <pod-name>

Reset Cluster (Last Resort)
bash
1234567891011
# On master
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d/*
sudo rm -rf $HOME/.kube/config

# On worker
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d/*

# Re-initialize (if needed)

🧹 Cleanup
Destroy Infrastructure
bash
1234567891011121314151617
# 1. Delete test resources (optional)
kubectl delete deployments --all
kubectl delete services --all
kubectl delete pods --all

# 2. Destroy Terraform infrastructure
cd terraform-k8s-practice
terraform destroy -auto-approve

# 3. Verify deletion in AWS Console

⚠️ Important Notes
Always run terraform destroy when done to avoid charges
EC2 instances cost money even when idle (~$0.04/hour for t3.medium)
Check AWS Billing Dashboard to ensure no unexpected charges
Delete unused EBS volumes if any remain
📁 Project Structure
1234567891011121314151617181920
terraform-k8s-practice/
├── main.tf                    # Root module - calls submodules
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── provider.tf                # AWS provider configuration
├── terraform.tfstate          # State file (auto-generated)
├── modules/
│   ├── vpc/
│   │   └── main.tf           # VPC, subnets, IGW, route tables
│   ├── security/

🔐 Security Considerations
Current Setup (For Learning)
✅ SSH access from anywhere (0.0.0.0/0)
✅ API server accessible from anywhere
✅ NodePort services exposed publicly
⚠️ NOT production-ready
For Production (Recommendations)
🔒 Restrict SSH to specific IPs
🔒 Use private subnets for nodes
🔒 Use LoadBalancer or Ingress instead of NodePort
🔒 Enable encryption at rest for etcd
🔒 Implement network policies
🔒 Use IAM roles for service accounts (IRSA)
🔒 Enable audit logging
📊 Cost Estimation
Monthly Costs (Approximate)
Resource
Type
Cost/Month
Master EC2
t3.medium
~$30
Worker EC2
t3.medium
~$30
EBS Volumes (2x 20GB)
gp3
~$4
Data Transfer
Variable
~$1-5
Total
~$65-70/month
Reduce Costs
Use t3.small instances for learning (~$15/month each)
Stop instances when not in use (but keep EBS)
Destroy completely when done (terraform destroy)
Set up AWS Budget alerts
Learning Resources
Kubernetes Documentation
Official Docs
kubeadm Reference
Concepts
Practice Platforms
Kubernetes Playground
Katacoda Scenarios
Recommended Reading
"Kubernetes Up and Running" by O'Reilly
"The Kubernetes Book" by Nigel Poulton
Kubernetes The Hard Way
🤝 Support & Issues
Getting Help
Check the Troubleshooting section
Review Kubernetes official docs
Search Stack Overflow
Join Kubernetes Slack
Reporting Issues
When reporting issues, include:
Terraform version
Kubernetes version (kubectl version)
AWS region
Error messages (full output)
Steps to reproduce
📝 License
This project is for educational purposes. Feel free to use, modify, and share.
🎓 Next Steps
Now that your cluster is running:
✅ Deploy real applications (WordPress, Jenkins, etc.)
✅ Learn Helm (package manager for Kubernetes)
✅ Set up monitoring (Prometheus + Grafana)
✅ Implement CI/CD (GitHub Actions, ArgoCD)
✅ Explore service meshes (Istio, Linkerd)
✅ Practice disaster recovery (backup/restore etcd)
🌟 Quick Command Reference
bash
12345678910111213141516171819202122232425262728293031323334
# === Infrastructure ===
terraform init
terraform apply -auto-approve
terraform destroy -auto-approve

# === Cluster Access ===
ssh -i ~/.ssh/ecommerce-key.pem ubuntu@<MASTER_IP>
bash k8s-cluster-setup.sh

# === Kubernetes Basics ===

Happy Kubernetes Learning! 🚀
Last Updated: February 2026
