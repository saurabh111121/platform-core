variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "github_org" {
  type    = string
  default = "saurabh111121"
}

variable "github_repo" {
  type    = string
  default = "platform-core"
}

variable "state_bucket" {
  type    = string
  default = "platform-core-tfstate-730667140374"
}
