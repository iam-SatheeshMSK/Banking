variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "AWS EC2 Key Pair Name"
  type        = string
  default     = "ecommerce-key"
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
