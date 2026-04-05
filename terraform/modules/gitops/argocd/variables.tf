variable "environment" { type = string }
variable "chart_version" { type = string; default = "6.7.0" }
variable "repo_url" { type = string; default = "https://github.com/saurabh111121/platform-core" }
variable "target_revision" { type = string; default = "main" }
