variable "region" {
  description = "AWS region"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "demo_environment_count" {
  description = "Number of demo environment instances"
  type        = number
}

variable "demo_environment_type" {
  description = "Instance type for demo environment"
  type        = string
}

variable "key_name" {
  description = "Key name for SSH access"
  type        = string
}

variable "cluster_name" {
  description = "Cluster name for tagging"
  type        = string
}