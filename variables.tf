variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "availability_zones_count" {
  description = "AZ Count to create subnets in"
  type        = number
}

variable "purpose_tag" {
  description = "Purpose Tag Name"
  type        = string
}
