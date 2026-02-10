variable "region" {
  type    = string
  default = "us-west-2"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "project" {
  type = string
}

variable "services" {
  type    = list(string)
  default = ["api", "web", "worker"]
}
