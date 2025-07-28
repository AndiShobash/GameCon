
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}


variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "admin_users" {
  description = "List of IAM user ARNs to grant cluster admin access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}