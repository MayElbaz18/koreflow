variable "region" {
  description = "AWS region where resources will be deployed."
  type        = string
  default     = "il-central-1"
}

variable "cluster_name" {
  description = "Name of the demo environment cluster."
  type        = string
  default     = "demo-environment"
}

variable "demo_environment_type" {
  description = "Instance type for demo environment nodes."
  type        = string
  default     = "t3.micro"
}

variable "demo_environment_count" {
  description = "Number of demo environment nodes."
  type        = number
  default     = 1
}

variable "key_name" {
  description = "Name of the SSH key pair to use for instance access."
  type        = string
  default     = "bar"
}

variable "security_group_id" {
  description = "ID of the existing Security Group to attach to the instances."
  type        = string
  default     = "sg-0f1a822015f1bc400"
}