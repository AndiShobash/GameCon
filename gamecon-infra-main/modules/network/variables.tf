variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_newbits" {
  description = "Bits to add when carving subnets out of the VPC CIDR"
  type        = number
  default     = 8  # /24 subnets from a /16 VPC
}

variable "availability_zone_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}