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
