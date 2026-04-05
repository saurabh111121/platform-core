variable "project" {
  type = string
}

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type        = string
  description = "Single public subnet for the Jenkins EC2 instance"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets for the ALB (minimum 2)"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name for SSH access"
  default     = ""
}

variable "jenkins_version" {
  type    = string
  default = "2.452.3"
}

variable "state_bucket" {
  type = string
}
