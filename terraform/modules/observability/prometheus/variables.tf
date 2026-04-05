variable "chart_version" { type = string; default = "58.0.0" }
variable "grafana_admin_password" { type = string; sensitive = true; default = "changeme" }
variable "prometheus_retention" { type = string; default = "15d" }
